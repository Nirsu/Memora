import 'dart:io';

Future<String> explorerFolderPath(String path) async {
  // Explorer interprets forward slashes as switches, unlike Dart and FFmpeg.
  // Resolving also rejects a missing directory instead of opening Documents.
  final directory = Directory(path);
  if (!await directory.exists()) {
    throw FileSystemException('Dossier introuvable', path);
  }
  final resolved = await directory.resolveSymbolicLinks();
  return resolved.replaceAll('/', r'\');
}

Future<void> openFolder(String path) async {
  await Process.run('explorer.exe', [await explorerFolderPath(path)]);
}

Directory findProjectRoot() {
  final override = Platform.environment['MEMORA_ROOT'];
  if (override != null) {
    return Directory(override);
  }
  for (final start in [
    Directory.current,
    File(Platform.resolvedExecutable).parent,
  ]) {
    var dir = start;
    for (var i = 0; i < 9; i++) {
      if (File('${dir.path}/.runtime/runtime.json').existsSync() ||
          File('${dir.path}/pubspec.yaml').existsSync()) {
        return dir;
      }
      if (dir.parent.path == dir.path) {
        break;
      }
      dir = dir.parent;
    }
  }
  return File(Platform.resolvedExecutable).parent;
}
