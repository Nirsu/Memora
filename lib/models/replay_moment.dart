import '../utils/timestamps.dart';
import 'meeting.dart';

typedef ReplayMoment = ({int time, String title, String section});

/// Read the timestamp links already saved by Memora. No new AI claims are made.
List<ReplayMoment> replayMoments(Meeting meeting) {
  final moments = <int, ReplayMoment>{};
  final links = RegExp(r'\[([^\]]+)\]\((memora://seek/[^\s)]+)\)');
  var section = 'Résumé';
  for (final line in meeting.summary.split('\n')) {
    if (line.startsWith('## ')) section = line.substring(3).trim();
    for (final match in links.allMatches(line)) {
      final time = replayTimestamp(match.group(2));
      if (time == null || (meeting.duration > 0 && time > meeting.duration)) {
        continue;
      }
      final title = line
          .replaceAll(links, '')
          .replaceFirst(RegExp(r'^\s*[-*]\s+'), '')
          .replaceAll('**', '')
          .trim();
      moments.putIfAbsent(
        time,
        () => (
          time: time,
          title: title.isEmpty ? 'Passage cité' : title,
          section: section,
        ),
      );
    }
  }
  for (final capture in meeting.captures) {
    if (capture.time < 0 ||
        (meeting.duration > 0 && capture.time > meeting.duration)) {
      continue;
    }
    moments.putIfAbsent(
      capture.time,
      () => (
        time: capture.time,
        title: capture.caption.isEmpty ? 'Repère visuel' : capture.caption,
        section: 'Capture',
      ),
    );
  }
  return moments.values.toList()..sort((a, b) => a.time.compareTo(b.time));
}
