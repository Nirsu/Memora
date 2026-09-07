import 'dart:convert';
import 'dart:io';

int? replayTimestamp(String? href) {
  final uri = Uri.tryParse(href ?? '');
  if (uri?.scheme != 'memora' ||
      uri?.host != 'seek' ||
      uri!.pathSegments.length != 1) {
    return null;
  }
  final ms = int.tryParse(uri.pathSegments.single);
  return ms != null && ms >= 0 ? ms : null;
}

String timeLabel(int ms) {
  final seconds = ms ~/ 1000;
  return '${(seconds ~/ 3600).toString().padLeft(2, '0')}:'
      '${(seconds ~/ 60 % 60).toString().padLeft(2, '0')}:'
      '${(seconds % 60).toString().padLeft(2, '0')}';
}

class Segment {
  Segment(this.id, this.start, this.end, this.text, [this.speaker = '']);
  final int id, start, end;
  String text, speaker;
  Map<String, dynamic> toJson() => {
    'id': id,
    'start': start,
    'end': end,
    'text': text,
    'speaker': speaker,
  };
  factory Segment.fromJson(Map<String, dynamic> j) => Segment(
    j['id'] as int,
    j['start'] as int,
    j['end'] as int,
    j['text'] as String,
    j['speaker'] as String? ?? '',
  );
}

class Capture {
  Capture(this.file, this.time, this.caption);
  final String file;
  final int time;
  String caption;
  Map<String, dynamic> toJson() => {
    'file': file,
    'time': time,
    'caption': caption,
  };
  factory Capture.fromJson(Map<String, dynamic> j) =>
      Capture(j['file'] as String, j['time'] as int, j['caption'] as String);
}

class Meeting {
  Meeting(this.id, this.title, this.created);
  final String id;
  final DateTime created;
  String title,
      notes = '',
      summary = '',
      media = '',
      status = 'Notes',
      error = '';
  int duration = 0, audioTrack = 0;
  bool hasVideo = false;
  List<Segment> segments = [];
  List<Capture> captures = [];
  Map<String, dynamic> toJson() => {
    'version': 1,
    'id': id,
    'title': title,
    'created': created.toIso8601String(),
    'notes': notes,
    'summary': summary,
    'media': media,
    'status': status,
    'error': error,
    'duration': duration,
    'audioTrack': audioTrack,
    'hasVideo': hasVideo,
    'segments': segments.map((s) => s.toJson()).toList(),
    'captures': captures.map((s) => s.toJson()).toList(),
  };
  factory Meeting.fromJson(Map<String, dynamic> j) {
    final m = Meeting(
      j['id'] as String,
      j['title'] as String,
      DateTime.parse(j['created'] as String),
    );
    m.notes = j['notes'] as String? ?? '';
    m.summary = j['summary'] as String? ?? '';
    m.media = j['media'] as String? ?? '';
    m.status = j['status'] as String? ?? 'Notes';
    m.error = j['error'] as String? ?? '';
    m.duration = j['duration'] as int? ?? 0;
    m.audioTrack = j['audioTrack'] as int? ?? 0;
    m.hasVideo = j['hasVideo'] as bool? ?? false;
    m.segments = (j['segments'] as List? ?? [])
        .map((s) => Segment.fromJson(Map<String, dynamic>.from(s as Map)))
        .toList();
    m.captures = (j['captures'] as List? ?? [])
        .map((s) => Capture.fromJson(Map<String, dynamic>.from(s as Map)))
        .toList();
    return m;
  }
}

class Library {
  Library(this.root);
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
      if (![
        'Notes',
        'Importé',
        'Prêt',
        'Transcrit',
        'Erreur',
        'Interrompu',
      ].contains(meeting.status)) {
        meeting.status = 'Interrompu';
        meeting.error =
            'Le traitement a été interrompu. Vous pouvez le relancer.';
      }
      result.add(meeting);
    }
    return result..sort((a, b) => b.created.compareTo(a.created));
  }
}

List<Segment> parseWhisper(Map<String, dynamic> json) {
  final result = <Segment>[];
  for (final value in json['transcription'] as List? ?? []) {
    final s = Map<String, dynamic>.from(value as Map);
    final offsets = Map<String, dynamic>.from(s['offsets'] as Map);
    final text = (s['text'] as String).trim();
    final start = (offsets['from'] as num).round();
    final end = (offsets['to'] as num).round();
    if (text.isNotEmpty && start >= 0 && end >= start) {
      result.add(Segment(result.length, start, end, text));
    }
  }
  return result;
}

List<List<Segment>> transcriptChunks(
  List<Segment> segments, {
  int maxChars = 10000,
}) {
  final chunks = <List<Segment>>[];
  var chunk = <Segment>[];
  var length = 0;
  for (final segment in segments) {
    final size = segment.text.length + segment.speaker.length + 50;
    if (length + size > maxChars && chunk.isNotEmpty) {
      chunks.add(chunk);
      chunk = [];
      length = 0;
    }
    chunk.add(segment);
    length += size;
  }
  if (chunk.isNotEmpty) {
    chunks.add(chunk);
  }
  return chunks;
}

List<Map<String, dynamic>> validatedItems(dynamic data, Set<int> allowed) {
  if (data is! Map || data['items'] is! List) {
    throw const FormatException(
      'Le modèle a renvoyé un résumé invalide. Réessayez.',
    );
  }
  final items = <Map<String, dynamic>>[];
  for (final raw in data['items'] as List) {
    if (raw is! Map || raw['text'] is! String || raw['segment_ids'] is! List) {
      continue;
    }
    final ids = (raw['segment_ids'] as List)
        .whereType<int>()
        .where(allowed.contains)
        .toSet()
        .toList();
    final text = (raw['text'] as String).trim();
    if (ids.isEmpty || text.isEmpty) {
      continue;
    }
    items.add({
      'kind': ['sujet', 'decision', 'action', 'question'].contains(raw['kind'])
          ? raw['kind']
          : 'sujet',
      'title': raw['title'] is String ? raw['title'] : '',
      'text': text,
      'segment_ids': ids,
    });
  }
  if (items.isEmpty) {
    throw const FormatException('Aucun passage source valide dans le résumé.');
  }
  return items;
}

String renderSummary(List<Map<String, dynamic>> items, List<Segment> segments) {
  final byId = {for (final s in segments) s.id: s};
  final out = StringBuffer();
  for (final kind in {
    'sujet': 'À retenir',
    'decision': 'Décisions',
    'action': 'Actions',
    'question': 'Questions ouvertes',
  }.entries) {
    final group = items.where((i) => i['kind'] == kind.key);
    if (group.isEmpty) {
      continue;
    }
    out.writeln('## ${kind.value}\n');
    for (final item in group) {
      final s = byId[(item['segment_ids'] as List).first]!;
      final title = (item['title'] as String).replaceAll('\n', ' ');
      out.writeln(
        '- ${title.isEmpty ? '' : '**$title** — '}${item['text']} [${timeLabel(s.start)}](memora://seek/${s.start})\n',
      );
    }
  }
  return out.toString();
}
