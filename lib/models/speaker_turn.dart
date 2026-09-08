import 'dart:math';

import 'meeting.dart';

class SpeakerTurn {
  const SpeakerTurn(this.start, this.end, this.speakerId);
  final int start, end;
  final String speakerId;
}

List<SpeakerTurn> parseSpeakerTurns(String output) {
  final pattern = RegExp(
    r'^\s*(\d+(?:\.\d+)?)\s*--\s*(\d+(?:\.\d+)?)\s+(speaker_\d+)\s*$',
    multiLine: true,
  );
  final turns = <SpeakerTurn>[];
  for (final match in pattern.allMatches(output)) {
    final start = double.parse(match[1]!);
    final end = double.parse(match[2]!);
    if (!start.isFinite || !end.isFinite || end <= start) continue;
    turns.add(
      SpeakerTurn((start * 1000).round(), (end * 1000).round(), match[3]!),
    );
  }
  if (turns.isEmpty) {
    throw const FormatException('Aucune voix détectée dans cette piste audio.');
  }
  turns.sort((a, b) => a.start.compareTo(b.start));
  return turns;
}

void assignSpeakerTurns(Meeting meeting, List<SpeakerTurn> turns) {
  final names = <String, String>{};
  for (final turn in turns) {
    names.putIfAbsent(turn.speakerId, () => 'Intervenant ${names.length + 1}');
  }
  for (final segment in meeting.segments) {
    // Explicit user corrections survive re-detection.
    if (segment.speaker.isNotEmpty || segment.speakerLocked) {
      segment.speaker = meeting.speakerLabel(segment);
      segment.speakerId = '';
      continue;
    }
    final overlap = <String, int>{};
    for (final turn in turns) {
      if (turn.start >= segment.end) break;
      final duration =
          min<int>(segment.end, turn.end) - max<int>(segment.start, turn.start);
      if (duration > 0) {
        overlap.update(
          turn.speakerId,
          (value) => value + duration,
          ifAbsent: () => duration,
        );
      }
    }
    final ranked = overlap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = overlap.values.fold(0, (sum, value) => sum + value);
    // Whisper segments may span a voice change or simultaneous speech. Avoid
    // inventing word-level alignment: leave such passages available for review.
    final clear =
        ranked.isNotEmpty &&
        ranked.first.value >= max(1, segment.end - segment.start) * .5 &&
        ranked.first.value >= total * .7;
    segment.speakerId = clear ? ranked.first.key : '';
    segment.speakerUncertain = !clear;
  }
  meeting.speakerNames = names;
  meeting.speakersDetected = true;
}
