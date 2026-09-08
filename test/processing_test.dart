import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memora/data/meeting_repository.dart';
import 'package:memora/models/meeting.dart';
import 'package:memora/models/summary.dart';
import 'package:memora/services/local_engine.dart';
import 'package:memora/utils/frame_similarity.dart';

class TestEngine extends LocalEngine {
  TestEngine(super.root, super.library);
  int summaryCalls = 0, captureCalls = 0, extractions = 0;
  int? failSummary, failCapture;
  @override
  Future<void> loadConfig() async {
    config = {
      'summaryModel': 'test',
      'ffmpeg': 'ffmpeg',
      'whisper': 'whisper',
      'whisperModel': 'test',
      'useGpu': false,
    };
  }

  @override
  Future<void> startServer() async {}
  @override
  Future<List<SummaryItem>> summarize(String text, Set<int> allowed) async {
    guard();
    summaryCalls++;
    if (summaryCalls == failSummary) throw StateError('Résumé indisponible');
    // Long source must not be replaced by a summary of previously extracted facts.
    expect(text, startsWith('[${allowed.first}]'));
    return [
      for (final id in allowed)
        SummaryItem(
          kind: .topic,
          title: 'Sujet $id',
          text: 'Fait $id.',
          segmentIds: [id],
        ),
    ];
  }

  @override
  Future<Capture?> capture(
    Meeting m,
    int time,
    String caption, {
    bool skipIdentical = false,
  }) async {
    guard();
    captureCalls++;
    if (captureCalls == failCapture) throw StateError('Capture indisponible');
    final shot = Capture('captures/$time.jpg', time, caption);
    m.captures.add(shot);
    await library.save(m);
    return shot;
  }

  @override
  Future<String> run(
    String executable,
    List<String> args, {
    String? logPath,
  }) async {
    guard();
    if (executable == 'ffmpeg') {
      extractions++;
      await File(args.last).writeAsBytes([1, 2, 3]);
    } else {
      final output = args[args.indexOf('-of') + 1];
      await File('$output.json').writeAsString(
        jsonEncode({
          'transcription': [
            {
              'offsets': {'from': 0, 'to': 500},
              'text': 'Bonjour.',
            },
          ],
        }),
      );
    }
    return '';
  }
}

class SpeakerTestEngine extends TestEngine {
  SpeakerTestEngine(super.root, super.library);
  bool failVoices = false, cancelVoices = false;
  @override
  bool get hasDiarization => true;
  @override
  Future<void> loadConfig() async {
    await super.loadConfig();
    config['diarization'] = 'diarizer';
  }

  @override
  Future<String> run(
    String executable,
    List<String> args, {
    String? logPath,
  }) async {
    if (executable != 'diarizer') {
      return super.run(executable, args, logPath: logPath);
    }
    if (cancelVoices) cancel();
    guard();
    if (failVoices) throw StateError('Voices unavailable');
    return '0 -- 1 speaker_00';
  }
}

void main() {
  late Directory dir;
  late MeetingRepository repository;
  late Meeting meeting;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('memora-processing-');
    repository = MeetingRepository(Directory('${dir.path}/meetings'));
    meeting = Meeting('test', 'Test', DateTime(2026))..media = 'recording.mp4';
    await repository.save(meeting);
  });
  tearDown(() async => dir.delete(recursive: true));

  test('Voice detection preserves an unfinished main processing job', () async {
    meeting
      ..status = .error
      ..error = 'Capture indisponible'
      ..summary = 'Résumé déjà généré'
      ..segments = [Segment(0, 0, 500, 'Bonjour')];
    final engine = SpeakerTestEngine(dir, repository);
    addTearDown(engine.dispose);
    await engine.detectSpeakers(meeting);
    final restored = (await repository.load()).single;
    expect(restored.speakersDetected, isTrue);
    expect(restored.status.name, 'error');
    expect(restored.error, 'Capture indisponible');
    expect(restored.canResume, isTrue);
  });

  test(
    'A failed voice model does not block transcription or summary',
    () async {
      final engine = SpeakerTestEngine(dir, repository)..failVoices = true;
      await engine.process(meeting);
      expect(meeting.status.name, 'ready');
      expect(meeting.segments, hasLength(1));
      expect(meeting.summary, isNotEmpty);
      expect(meeting.speakersDetected, isFalse);
      expect(meeting.speakerError, contains('Voices unavailable'));
      engine.dispose();
    },
  );

  test(
    'Cancelled re-detection preserves names and summary; a rerun backs them up',
    () async {
      meeting
        ..status = .ready
        ..summary = 'Résumé personnel'
        ..speakersDetected = true
        ..speakerNames = {'old': 'Alexandre'}
        ..segments = [Segment(0, 0, 500, 'Bonjour', '', 'old')];
      final engine = SpeakerTestEngine(dir, repository)..cancelVoices = true;
      await expectLater(engine.detectSpeakers(meeting), throwsException);
      final restored = (await repository.load()).single;
      expect(restored.status.name, 'ready');
      expect(restored.speakerLabel(restored.segments.single), 'Alexandre');
      expect(restored.summary, 'Résumé personnel');
      engine.cancelVoices = false;
      await engine.detectSpeakers(restored, count: 2);
      final previous = jsonDecode(
        await File('${repository.folder(meeting)}/speakers.previous.json')
            .readAsString(),
      ) as Map;
      expect(previous['speakerNames'], {'old': 'Alexandre'});
      expect(restored.speakerLabel(restored.segments.single), 'Intervenant 1');
      expect(restored.summary, 'Résumé personnel');
      expect(restored.speakerError, contains('1 groupes obtenus pour 2'));
      engine.dispose();
    },
  );

  test('A restart reuses completed source chunks; transcript edits invalidate them', () async {
    meeting.segments = List.generate(
      3,
      (i) => Segment(i, i * 20000, i * 20000 + 1000, 'source ' * 1500),
    );
    final first = TestEngine(dir, repository)..failSummary = 2;
    await expectLater(first.process(meeting), throwsStateError);
    final restored = (await MeetingRepository(repository.root).load()).single;
    expect(restored.segments, hasLength(3));
    expect(restored.canResume, isTrue);
    final resumed = TestEngine(dir, repository);
    await resumed.process(restored);
    expect(resumed.summaryCalls, 2);
    expect(restored.summary, contains('Fait 0.'));
    expect(restored.summary, contains('Fait 2.'));
    restored.summary = 'Correction personnelle';
    restored.segments.first.text = 'Source corrigée';
    final changed = TestEngine(dir, repository);
    await changed.process(restored);
    expect(changed.summaryCalls, greaterThan(0));
    expect(restored.summary, 'Correction personnelle');
    final regenerate = TestEngine(dir, repository);
    await regenerate.process(restored, regenerate: true);
    expect(regenerate.summaryCalls, greaterThan(0));
  });

  test(
    'Failure during captures resumes missing captures without any inference',
    () async {
      meeting.hasVideo = true;
      meeting.segments = List.generate(
        3,
        (i) => Segment(i, i * 20000, i * 20000 + 1000, 'Sujet $i'),
      );
      final first = TestEngine(dir, repository)..failCapture = 2;
      await expectLater(first.process(meeting), throwsStateError);
      final restored = (await MeetingRepository(repository.root).load()).single;
      expect(restored.summary, isNotEmpty);
      expect(restored.captures, hasLength(1));
      final resumed = TestEngine(dir, repository);
      await resumed.process(restored);
      expect(resumed.summaryCalls, 0);
      expect(resumed.captureCalls, 2);
      expect(restored.captures.map((c) => c.time), [0, 20000, 40000]);
      expect(restored.status.name, 'ready');
    },
  );

  test(
    'Cancellation after extraction reuses only the committed audio file',
    () async {
      final first = TestEngine(dir, repository);
      first.onUpdate = () {
        if (meeting.status == .transcribing) first.cancel();
      };
      await expectLater(first.process(meeting), throwsException);
      expect(first.extractions, 1);
      final restored = (await repository.load()).single;
      expect(restored.audioExtracted, isTrue);
      expect(restored.status.name, 'interrupted');
      final resumed = TestEngine(dir, repository);
      await resumed.process(restored);
      expect(resumed.extractions, 0);
      expect(restored.segments, hasLength(1));
      // A leftover partial file from an older run must not be treated as complete.
      restored.audioExtracted = false;
      restored.segments = [];
      final fresh = TestEngine(dir, repository);
      await fresh.process(restored);
      expect(fresh.extractions, 1);
    },
  );

  test('Long meetings keep all extracted facts and malformed caches are disposable', () async {
    meeting.segments = List.generate(
      30,
      (i) => Segment(i, i * 1000, i * 1000 + 900, 'texte ' * 130),
    );
    await File('${repository.folder(meeting)}/summary.checkpoint.json')
        .writeAsString('{broken');
    final engine = TestEngine(dir, repository);
    await engine.process(meeting);
    expect(engine.summaryCalls, 2);
    expect(RegExp(r'Fait \d+\.').allMatches(meeting.summary), hasLength(30));
  });

  test(
    'Empty content adds no invented actions and each cited source is reachable',
    () {
      expect(renderSummary([], []), contains('Aucun élément'));
      final items = validatedItems(
        {
          'items': [
            {
              'kind': 'decision',
              'text': 'Décision explicite.',
              'segment_ids': [2, 1],
            },
          ],
        },
        {1, 2},
      );
      final markdown = renderSummary(items, [
        Segment(1, 1000, 2000, 'a'),
        Segment(2, 4000, 5000, 'b'),
      ]);
      expect(markdown, contains('memora://seek/1000'));
      expect(markdown, contains('memora://seek/4000'));
      expect(markdown, isNot(contains('## Actions')));
    },
  );

  test(
    'Near-identical frames tolerate compression but preserve visible changes',
    () {
      final original = List.filled(2304, 120);
      expect(similarFrames(original, List.filled(2304, 121)), isTrue);
      final changed = List<int>.from(original)..fillRange(0, 30, 170);
      expect(similarFrames(original, changed), isFalse);
      expect(similarFrames([], []), isFalse);
    },
  );
}
