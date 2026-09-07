import 'package:flutter/foundation.dart';

import '../data/meeting_repository.dart';
import '../models/meeting.dart';
import '../services/local_engine.dart';

enum SaveState {
  saved('Enregistré localement'),
  saving('Enregistrement…'),
  failed('Échec de sauvegarde');

  const SaveState(this.label);
  final String label;
}

/// Application state and user actions. Dialogs, navigation and player rendering
/// stay in the UI; persistence and inference are delegated to the data layer.
class WorkspaceViewModel extends ChangeNotifier {
  WorkspaceViewModel({required this.repository, required this.engine}) {
    engine.onUpdate = _changed;
  }

  Meeting? get selected => _selected;
  String get search => _search;
  String? get busyId => _busyId;
  bool get loading => _loading;
  bool get checking => _checking;
  SaveState get saveState => _saveState;
  List<String> get engineIssues => List.unmodifiable(_engineIssues);
  final MeetingRepository repository;
  final LocalEngine engine;
  final List<Meeting> _meetings = [];
  List<Meeting> get meetings => List.unmodifiable(_meetings);
  Meeting? _selected;
  String _search = '';
  String? _busyId;
  bool _loading = true;
  bool _checking = false;
  bool get busy => _busyId != null;
  SaveState _saveState = .saved;
  List<String> _engineIssues = ['Vérification des moteurs…'];
  final _markerStarts = <String, DateTime>{};
  DateTime? markerStart(Meeting meeting) => _markerStarts[meeting.id];
  void Function(String)? onMessage;
  int _saveRevision = 0;
  bool _disposed = false;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    await safely(() async {
      _meetings.addAll(await repository.load());
      if (repository.warnings.isNotEmpty) {
        onMessage?.call(repository.warnings.join('\n'));
      }
    });
    _loading = false;
    _changed();
    if (!_disposed) await checkEngines();
  }

  Future<void> safely(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (!_disposed) onMessage?.call(error.toString());
    }
  }

  void select(Meeting? meeting) {
    _selected = meeting;
    _changed();
  }

  void searchMeetings(String value) {
    _search = value;
    _changed();
  }

  void toggleMarker(Meeting meeting) {
    if (_markerStarts.containsKey(meeting.id)) {
      _markerStarts.remove(meeting.id);
    } else {
      _markerStarts[meeting.id] = DateTime.now();
    }
    _changed();
  }

  Future<void> save(Meeting meeting) async {
    final revision = ++_saveRevision;
    _saveState = .saving;
    _changed();
    try {
      await repository.save(meeting);
      if (revision == _saveRevision) _saveState = .saved;
    } catch (_) {
      _saveState = .failed;
      rethrow;
    } finally {
      _changed();
    }
  }

  Future<Meeting> createMeeting() async {
    final now = DateTime.now();
    final meeting = Meeting(
      '${now.microsecondsSinceEpoch}',
      'Réunion du ${now.day}/${now.month}',
      now,
    );
    await repository.save(meeting);
    _meetings.insert(0, meeting);
    _changed();
    return meeting;
  }

  Future<T> runJob<T>(
    Meeting? meeting,
    String detail,
    Future<T> Function() action,
  ) async {
    if (busy) throw StateError('Une opération est déjà en cours.');
    _busyId = meeting?.id ?? 'import';
    engine.detail = detail;
    _changed();
    try {
      return await action();
    } finally {
      _busyId = null;
      _changed();
    }
  }

  Future<Meeting> importRecording({
    required Meeting? target,
    required String path,
    required String fileName,
    required int track,
    required Map<String, dynamic> info,
  }) async {
    final now = DateTime.now();
    final meeting = target != null && target.media.isEmpty
        ? target
        : Meeting(
            '${now.microsecondsSinceEpoch}',
            fileName.replaceFirst(RegExp(r'\.[^.]+$'), ''),
            now,
          );
    if (!_meetings.contains(meeting)) _meetings.insert(0, meeting);
    _busyId = meeting.id;
    try {
      await engine.importMedia(meeting, path, track, info);
      return meeting;
    } catch (error) {
      meeting.status = .error;
      meeting.error = error.toString();
      await repository.save(meeting);
      rethrow;
    } finally {
      _changed();
    }
  }

  Future<void> analyze(Meeting meeting) =>
      runJob(meeting, 'Préparation du résumé', () async {
        if (meeting.summary.isNotEmpty) {
          onMessage?.call(
            'Le nouveau résumé sera enregistré séparément. Votre version modifiée reste intacte.',
          );
        }
        await engine.process(meeting, summaryOnly: meeting.segments.isNotEmpty);
      });

  void cancel() => engine.cancel();

  Future<void> remove(Meeting meeting) =>
      runJob(meeting, 'Suppression', () async {
        await repository.remove(meeting);
        _meetings.remove(meeting);
        if (_selected == meeting) _selected = null;
      });

  Future<void> restore(Meeting meeting) async {
    await repository.restore(meeting);
    _meetings.add(meeting);
    _meetings.sort((a, b) => b.created.compareTo(a.created));
    _changed();
  }

  Future<void> rename(Meeting meeting, String value) async {
    if (value.trim().isEmpty) return;
    meeting.title = value.trim();
    await save(meeting);
  }

  Future<void> updateNotes(Meeting meeting, String value) async {
    meeting.notes = value;
    await save(meeting);
  }

  Future<void> updateSummary(Meeting meeting, String value) async {
    meeting.summary = value;
    await save(meeting);
  }

  Future<void> updateSpeaker(
    Meeting meeting,
    Segment segment,
    String value,
  ) async {
    segment.speaker = value.trim();
    await save(meeting);
  }

  Future<void> updateTranscript(
    Meeting meeting,
    Segment segment,
    String value,
  ) async {
    segment.text = value;
    await save(meeting);
  }

  Future<void> updateCaption(
    Meeting meeting,
    Capture capture,
    String value,
  ) async {
    capture.caption = value;
    await save(meeting);
  }

  Future<void> removeCapture(Meeting meeting, Capture capture) async {
    meeting.captures.remove(capture);
    await save(meeting);
  }

  Future<void> adoptSummary(Meeting meeting) async {
    if (!await repository.adoptGeneratedSummary(meeting)) {
      onMessage?.call('Aucun nouveau résumé disponible.');
    }
    _changed();
  }

  Future<void> addCapture(Meeting meeting, int position) =>
      runJob(meeting, 'Ajout de la capture', () async {
        engine.cancelled = false;
        await engine.loadConfig();
        await engine.capture(meeting, position, 'Capture ajoutée manuellement');
      });

  Future<String> export(Meeting meeting, String destination) => runJob(
    meeting,
    'Export du meeting',
    () => engine.export(meeting, destination),
  );

  Future<void> exportAudio(Meeting meeting, String destination) => runJob(
    meeting,
    'Export audio',
    () => engine.exportAudio(meeting, destination),
  );

  Future<void> checkEngines({bool start = false}) async {
    if (_checking || busy) return;
    _checking = true;
    _changed();
    try {
      if (start) await engine.startServer();
      _engineIssues = await engine.check();
    } catch (error) {
      _engineIssues = [error.toString()];
    } finally {
      _checking = false;
      _changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    engine.onUpdate = null;
    engine.dispose();
    onMessage = null;
    super.dispose();
  }
}
