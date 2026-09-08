// Headless check using the same native player as the Windows app.
// dart run scripts/replay_smoke.dart <video-or-audio> [...]
import 'dart:io';

import 'package:media_kit/media_kit.dart';

Future<void> waitFor(bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (!ready()) {
    if (DateTime.now().isAfter(deadline)) throw StateError('Player timed out');
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

Future<void> main(List<String> args) async {
  if (args.isEmpty) throw ArgumentError('Pass a local media file.');
  MediaKit.ensureInitialized(
    libmpv: File('build/windows/x64/runner/Release/libmpv-2.dll').absolute.path,
  );
  for (final path in args) {
    // A new player verifies that reopening does not depend on in-memory state.
    final player = Player(
      configuration: const PlayerConfiguration(muted: true),
    );
    final errors = <String>[];
    final subscription = player.stream.error.listen(errors.add);
    try {
      await player.open(Media(File(path).absolute.path));
      await waitFor(
        () =>
            player.state.duration.inSeconds > 0 &&
            player.state.position.inMilliseconds > 300,
      );
      await player.pause();
      final target = Duration(
        milliseconds: player.state.duration.inMilliseconds ~/ 2,
      );
      await player.seek(target);
      await player.play();
      await waitFor(
        () => (player.state.position - target).inMilliseconds.abs() < 1500,
      );
      await player.pause();
      if (errors.isNotEmpty) throw StateError(errors.join('\n'));
      stdout.writeln(
        'PASS replay, pause, seek: $path (${player.state.duration.inSeconds}s)',
      );
    } finally {
      await subscription.cancel();
      await player.dispose();
    }
  }
}
