import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memora/data/meeting_repository.dart';
import 'package:memora/models/meeting.dart';
import 'package:memora/models/meeting_status.dart';
import 'package:memora/services/local_engine.dart';
import 'package:memora/ui/workspace_view_model.dart';

void main() {
  test('Status codes round-trip and all original labels remain readable', () {
    for (final status in MeetingStatus.values) {
      expect(MeetingStatus.fromJson(status.label), status);
      final meeting = Meeting('legacy', 'Meeting', DateTime(2026))
        ..status = status;
      expect(Meeting.fromJson(meeting.toJson()).status, status);
    }
    expect(
      MeetingStatus.fromJson('status from a future version'),
      MeetingStatus.interrupted,
    );
    expect(MeetingStatus.fromJson(null), MeetingStatus.notes);
  });

  test('Legacy meetings load without rewriting user data and interrupted stages recover', () async {
    final dir = await Directory.systemTemp.createTemp('memora-legacy-test-');
    try {
      final repository = MeetingRepository(dir);
      final meeting = Meeting('legacy', 'Ancien meeting', DateTime(2026));
      final json = meeting.toJson()
        ..['version'] = 1
        ..['status'] = 'Prêt'
        ..['notes'] = 'Notes existantes';
      await Directory(repository.folder(meeting)).create();
      final file = await File('${repository.folder(meeting)}/meeting.json')
          .writeAsString(jsonEncode(json));
      final before = await file.readAsString();
      final loaded = (await repository.load()).single;
      expect(loaded.status, MeetingStatus.ready);
      expect(loaded.notes, 'Notes existantes');
      expect(await file.readAsString(), before);
      json['status'] = 'Transcription';
      await file.writeAsString(jsonEncode(json));
      expect(
        (await repository.load()).single.status,
        MeetingStatus.interrupted,
      );
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test(
    'View model prevents overlapping jobs and releases the lock after failure',
    () async {
      final dir = await Directory.systemTemp.createTemp('memora-model-test-');
      final repository = MeetingRepository(dir);
      final model = WorkspaceViewModel(
        repository: repository,
        engine: LocalEngine(dir, repository),
      );
      try {
        final release = Completer<void>();
        final running = model.runJob(null, 'Test', () => release.future);
        expect(model.busy, isTrue);
        var secondStarted = false;
        await expectLater(
          model.runJob(null, 'Overlap', () async {
            secondStarted = true;
          }),
          throwsStateError,
        );
        expect(secondStarted, isFalse);
        release.complete();
        await running;
        expect(model.busy, isFalse);
        await expectLater(
          model.runJob<void>(null, 'Failure', () async {
            throw StateError('Expected');
          }),
          throwsStateError,
        );
        expect(model.busy, isFalse);
        final meeting = await model.createMeeting();
        await model.updateNotes(meeting, 'Persisted by the view model');
        expect(
          (await repository.load()).single.notes,
          'Persisted by the view model',
        );
        expect(model.saveState, SaveState.saved);
      } finally {
        model.dispose();
        await dir.delete(recursive: true);
      }
    },
  );
}
