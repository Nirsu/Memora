import 'meeting.dart';

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
