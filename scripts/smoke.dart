// End-to-end local engine check: dart scripts/smoke.dart <video>.
import 'dart:io';
import 'dart:async';

import 'package:memora/engine.dart';
import 'package:memora/meeting.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    throw ArgumentError('Pass a local test recording.');
  }
  final root = Directory.current;
  // Keep synthetic checks out of the user's meeting library.
  final library = Library(Directory('${root.path}/.local/smoke/meetings'));
  final engine = LocalEngine(root, library);
  final existing = args.first == '--existing';
  final m = existing
      ? (await library.load()).firstWhere((m) => m.id == args[1])
      : Meeting(
          '${DateTime.now().microsecondsSinceEpoch}',
          'Essai technique · réunion simulée',
          DateTime.now(),
        );
  engine.onUpdate = () => stdout.writeln('${m.status} | ${engine.detail}');
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
    if (m.segments.isEmpty ||
        m.summary.isEmpty ||
        (m.hasVideo && m.captures.isEmpty)) {
      throw StateError('Incomplete pipeline output');
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
