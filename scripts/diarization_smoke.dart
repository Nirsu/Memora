// dart run scripts/diarization_smoke.dart <technical-meeting-folder> [speaker-count]
import 'dart:io';

import 'package:memora/data/meeting_repository.dart';
import 'package:memora/services/local_engine.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    throw ArgumentError('Pass a technical test meeting folder.');
  }
  final folder = Directory(args.first).absolute;
  final repository = MeetingRepository(folder.parent);
  final id = folder.uri.pathSegments.where((s) => s.isNotEmpty).last;
  final meeting = (await repository.load()).firstWhere((m) => m.id == id);
  final count = args.length > 1 ? int.parse(args[1]) : 0;
  final engine = LocalEngine(Directory.current, repository);
  final before = meeting.segments
      .map((s) => '${s.id}:${s.start}:${s.end}:${s.text}')
      .join('\n');
  final summary = meeting.summary;
  engine.onUpdate = () =>
      stdout.writeln('${meeting.status.label} | ${engine.detail}');
  final clock = Stopwatch()..start();
  try {
    await engine.detectSpeakers(meeting, count: count);
    final reloaded = (await MeetingRepository(
      repository.root,
    ).load()).firstWhere((m) => m.id == id);
    if (reloaded.summary != summary ||
        before !=
            reloaded.segments
                .map((s) => '${s.id}:${s.start}:${s.end}:${s.text}')
                .join('\n')) {
      throw StateError('Speaker detection modified the transcript or summary');
    }
    if (!reloaded.speakersDetected ||
        reloaded.speakerNames.isEmpty ||
        (count > 0 && reloaded.speakerNames.length != count)) {
      throw StateError('Unexpected speaker count');
    }
    final assigned = reloaded.segments
        .where((s) => s.speakerId.isNotEmpty)
        .length;
    stdout.writeln(
      'PASS ${reloaded.speakerNames.length} voices, $assigned/${reloaded.segments.length} assigned passages, ${clock.elapsed.inSeconds}s.',
    );
  } finally {
    engine.dispose();
  }
}
