import 'meeting_status.dart';

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
  String title, notes = '', summary = '', media = '', error = '';
  MeetingStatus status = .notes;
  int duration = 0, audioTrack = 0;
  bool hasVideo = false;
  List<Segment> segments = [];
  List<Capture> captures = [];
  Map<String, dynamic> toJson() => {
    'version': 2,
    'id': id,
    'title': title,
    'created': created.toIso8601String(),
    'notes': notes,
    'summary': summary,
    'media': media,
    'status': status.name,
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
    m.status = MeetingStatus.fromJson(j['status']);
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
