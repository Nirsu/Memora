// End-to-end local engine check: dart scripts/smoke.dart <video>.
import 'dart:io';
import 'dart:async';

import 'package:memora/services/local_engine.dart';
import 'package:memora/models/meeting.dart';
import 'package:memora/data/meeting_repository.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    throw ArgumentError('Pass a local test recording.');
  }
  final root = Directory.current;
  // Keep technical checks out of the user's meeting library.
  final library = MeetingRepository(
    Directory('${root.path}/.local/smoke/meetings'),
  );
  final engine = LocalEngine(root, library);
  final existing = args.first == '--existing';
  final m = existing
      ? (await library.load()).firstWhere((m) => m.id == args[1])
      : Meeting(
          '${DateTime.now().microsecondsSinceEpoch}',
          'Essai technique · ${File(args.first).uri.pathSegments.last}',
          DateTime.now(),
        );
  engine.onUpdate = () =>
      stdout.writeln('${m.status.label} | ${engine.detail}');
  final watch = Stopwatch()..start();
  final previousSummary = m.summary;
  try {
    if (!existing) {
      final info = await engine.probe(args.first);
      await engine.importMedia(m, args.first, 0, info);
    }
    await engine.process(m);
    if (existing &&
        previousSummary.isNotEmpty &&
        m.summary != previousSummary) {
      throw StateError('Regeneration overwrote the editable summary');
    }
    if (m.segments.isEmpty || m.summary.isEmpty) {
      throw StateError('Incomplete pipeline output');
    }
    final restored = (await MeetingRepository(
      library.root,
    ).load()).firstWhere((item) => item.id == m.id);
    if (restored.summary != m.summary ||
        restored.segments.length != m.segments.length ||
        restored.captures.length != m.captures.length ||
        restored.status != m.status) {
      throw StateError('Results did not survive reopening the repository');
    }
    for (final link in RegExp(r'memora://seek/(\d+)').allMatches(
      await File('${library.folder(m)}/summary.generated.md').readAsString(),
    )) {
      if (!m.segments.any((s) => s.start == int.parse(link[1]!))) {
        throw StateError('Replay link without a transcript source');
      }
    }
    final exported = await engine.export(
      m,
      '${root.path}/.local/smoke/exports',
    );
    final audio = '$exported/audio.m4a';
    await engine.exportAudio(m, audio);
    final audioInfo = await engine.probe(audio);
    final streams = audioInfo['streams'] as List;
    if (streams.length != 1 ||
        (streams.single as Map)['codec_type'] != 'audio') {
      throw StateError('Audio export must contain exactly one audio stream');
    }
    if (m.hasVideo) {
      final before = m.captures.length;
      await engine.capture(m, m.duration ~/ 2, 'Capture manuelle de contrôle');
      if (m.captures.length != before + 1) {
        throw StateError('Manual capture failed');
      }
    }
    // Cancel a real process without running another inference.
    final stop = Timer(const Duration(milliseconds: 500), engine.cancel);
    var interrupted = false;
    try {
      await engine.run(engine.config['ffmpeg'] as String, [
        '-v',
        'error',
        '-re',
        '-i',
        library.mediaPath(m),
        '-f',
        'null',
        '-',
      ]);
    } catch (_) {
      interrupted = engine.cancelled;
    } finally {
      stop.cancel();
    }
    if (!interrupted) {
      throw StateError('Cancellation did not interrupt the process');
    }
    engine.cancelled = false;
    await engine.probe(library.mediaPath(m));
    stdout.writeln(
      'PASS ${m.segments.length} segments, ${m.captures.length} captures, ${watch.elapsed.inSeconds}s. Export: $exported',
    );
  } finally {
    engine.dispose();
  }
}
