import 'meeting.dart';
import '../utils/timestamps.dart';

enum SummaryKind {
  topic('sujet', 'À retenir'),
  decision('decision', 'Décisions'),
  action('action', 'Actions'),
  question('question', 'Questions ouvertes');

  const SummaryKind(this.code, this.heading);
  final String code;
  final String heading;

  static SummaryKind fromJson(Object? value) {
    for (final kind in values) {
      if (kind.code == value) return kind;
    }
    return .topic;
  }
}

/// Validated model output. Dynamic JSON never escapes the parsing boundary.
class SummaryItem {
  SummaryItem({
    required this.kind,
    required this.title,
    required this.text,
    required Iterable<int> segmentIds,
  }) : segmentIds = List.unmodifiable(segmentIds);
  final SummaryKind kind;
  final String title;
  final String text;
  final List<int> segmentIds;

  Map<String, Object> toJson() => {
    'kind': kind.code,
    'title': title,
    'text': text,
    'segment_ids': segmentIds,
  };
}

List<SummaryItem> validatedItems(Object? data, Set<int> allowed) {
  if (data is! Map || data['items'] is! List) {
    throw const FormatException(
      'Le modèle a renvoyé un résumé invalide. Réessayez.',
    );
  }
  final items = <SummaryItem>[];
  for (final raw in data['items'] as List) {
    if (raw case {'text': final String text, 'segment_ids': final List ids}) {
      final validIds = ids.whereType<int>().where(allowed.contains).toSet();
      if (validIds.isEmpty || text.trim().isEmpty) continue;
      items.add(
        SummaryItem(
          kind: SummaryKind.fromJson(raw['kind']),
          title: raw['title'] is String ? raw['title'] as String : '',
          text: text.trim(),
          segmentIds: validIds,
        ),
      );
    }
  }
  if (items.isEmpty && (data['items'] as List).isNotEmpty) {
    throw const FormatException('Aucun passage source valide dans le résumé.');
  }
  return items;
}

String renderSummary(List<SummaryItem> items, List<Segment> segments) {
  if (items.isEmpty) {
    return 'Aucun élément suffisamment clair à synthétiser dans cette transcription. '
        'La transcription et l’enregistrement restent disponibles pour relecture.\n';
  }
  final byId = {for (final segment in segments) segment.id: segment};
  final out = StringBuffer();
  for (final kind in SummaryKind.values) {
    final group = items.where((item) => item.kind == kind);
    if (group.isEmpty) continue;
    out.writeln('## ${kind.heading}\n');
    for (final item in group) {
      final sources = item.segmentIds.map((id) => byId[id]!).toList()
        ..sort((a, b) => a.start.compareTo(b.start));
      final title = item.title.replaceAll('\n', ' ');
      out.writeln(
        '- ${title.isEmpty ? '' : '**$title** — '}${item.text} '
        '${sources.map((s) => '[${timeLabel(s.start)}](memora://seek/${s.start})').join(' · ')}\n',
      );
    }
  }
  return out.toString();
}
