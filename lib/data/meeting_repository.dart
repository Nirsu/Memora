import 'dart:convert';
import 'dart:io';

import '../models/meeting.dart';

class MeetingRepository {
  MeetingRepository(this.root);
  final Directory root;
  Future<void> _writes = Future.value();
  final Set<String> _removed = {};
  final List<String> warnings = [];
  String folder(Meeting m) => '${root.path}/${m.id}';
  String mediaPath(Meeting m) => '${folder(m)}/${m.media}';

  Future<void> save(Meeting m) {
    final snapshot = jsonEncode(m.toJson());
    final next = _writes.then((_) async {
      if (_removed.contains(m.id)) return;
      final dir = Directory(folder(m));
      await dir.create(recursive: true);
      final target = File('${dir.path}/meeting.json');
      final tmp = File('${target.path}.tmp');
      await tmp.writeAsString(snapshot, flush: true);
      if (await target.exists()) {
        await target.copy('${target.path}.bak');
      }
      await tmp.rename(target.path);
    });
    _writes = next.catchError((Object _) {});
    return next;
  }

  // Keep removed meetings on the same disk so removal is atomic and reversible.
  Future<void> remove(Meeting m) => _move(m, restore: false);
  Future<void> restore(Meeting m) => _move(m, restore: true);

  Future<bool> adoptGeneratedSummary(Meeting meeting) async {
    final source = File('${folder(meeting)}/summary.generated.md');
    if (!await source.exists()) return false;
    final generated = await source.readAsString();
    await File('${folder(meeting)}/summary.previous.md')
        .writeAsString(meeting.summary, flush: true);
    meeting.summary = generated;
    await save(meeting);
    return true;
  }

  Future<void> _move(Meeting m, {required bool restore}) {
    final next = _writes.then((_) async {
      if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(m.id)) {
        throw const FormatException('Identifiant de meeting invalide.');
      }
      final base = await root.resolveSymbolicLinks();
      final trash = Directory('$base/.trash');
      if (await FileSystemEntity.type(trash.path, followLinks: false) ==
          FileSystemEntityType.link) {
        throw const FileSystemException('Dossier de suppression invalide.');
      }
      await trash.create();
      final source = Directory(
        restore ? '${trash.path}/${m.id}' : '$base/${m.id}',
      );
      final target = restore ? '$base/${m.id}' : '${trash.path}/${m.id}';
      if (await FileSystemEntity.type(source.path, followLinks: false) !=
          FileSystemEntityType.directory) {
        throw const FileSystemException('Dossier du meeting introuvable.');
      }
      // An existing destination must never be overwritten.
      if (await FileSystemEntity.type(target, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw const FileSystemException(
          'Un dossier existe déjà à destination.',
        );
      }
      await source.rename(target);
      restore ? _removed.remove(m.id) : _removed.add(m.id);
    });
    _writes = next.catchError((Object _) {});
    return next;
  }

  Future<List<Meeting>> load() async {
    await root.create(recursive: true);
    final result = <Meeting>[];
    await for (final entry in root.list()) {
      if (entry is! Directory ||
          entry.uri.pathSegments.where((s) => s.isNotEmpty).last == '.trash') {
        continue;
      }
      Meeting? meeting;
      for (final suffix in ['', '.bak']) {
        try {
          final file = File('${entry.path}/meeting.json$suffix');
          if (!await file.exists()) {
            continue;
          }
          meeting = Meeting.fromJson(
            jsonDecode(await file.readAsString()) as Map<String, dynamic>,
          );
          if (suffix.isNotEmpty) {
            warnings.add('Copie de secours restaurée : ${meeting.title}');
          }
          break;
        } catch (_) {
          /* Try the previous durable snapshot. */
        }
      }
      if (meeting == null) {
        warnings.add('Dossier illisible conservé : ${entry.path}');
        continue;
      }
      // A crashed job never resumes by silently running inference at launch.
      if (meeting.status.isProcessing) {
        meeting.status = .interrupted;
        meeting.error =
            'Le traitement a été interrompu. Vous pouvez le relancer.';
      }
      result.add(meeting);
    }
    return result..sort((a, b) => b.created.compareTo(a.created));
  }
}
