import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/data/meeting_repository.dart';
import 'package:memora/models/meeting.dart';
import 'package:memora/models/speaker_turn.dart';
import 'package:memora/services/local_engine.dart';
import 'package:memora/ui/core/app_theme.dart';
import 'package:memora/ui/dialogs/speaker_dialog.dart';
import 'package:memora/ui/meeting/transcript_pane.dart';
import 'package:memora/ui/workspace_view_model.dart';

void main() {
  test('Voices follow time overlap; ambiguous, silent and corrected passages stay safe', () {
    final meeting = Meeting('test', 'Test', DateTime(2026))
      ..segments = [
        Segment(1, 0, 1000, 'a'),
        Segment(2, 1000, 2000, 'b'),
        Segment(3, 2000, 3000, 'deux voix'),
        Segment(4, 3000, 4000, 'sans voix'),
        Segment(5, 0, 1000, 'corrigé', 'Nom manuel'),
      ];
    final turns = parseSpeakerTurns(
      'Config\r\nStarted\r\n1.000 -- 2.000 speaker_01\r\n0.000 -- 1.000 speaker_00\r\n2.000 -- 3.000 speaker_00\r\n2.000 -- 3.000 speaker_01\r\n',
    );
    assignSpeakerTurns(meeting, turns);
    expect(meeting.segments.map((s) => s.speakerId), [
      'speaker_00',
      'speaker_01',
      '',
      '',
      '',
    ]);
    expect(meeting.segments[2].speakerUncertain, isTrue);
    expect(meeting.segments[3].speakerUncertain, isTrue);
    expect(meeting.speakerLabel(meeting.segments[4]), 'Nom manuel');
    expect(meeting.speakerNames.values, ['Intervenant 1', 'Intervenant 2']);
    expect(
      () => parseSpeakerTurns('Started\nnot a result'),
      throwsFormatException,
    );
  });

  test('Renaming a voice updates all its passages, survives restart and exports names', () async {
    final dir = await Directory.systemTemp.createTemp('memora-speakers-');
    final repository = MeetingRepository(Directory('${dir.path}/meetings'));
    final engine = LocalEngine(dir, repository);
    final model = WorkspaceViewModel(repository: repository, engine: engine);
    final meeting = Meeting('test', 'Test', DateTime(2026))
      ..segments = [
        Segment(0, 0, 1000, 'a'),
        Segment(1, 1000, 2000, 'b'),
        Segment(2, 2000, 3000, 'c'),
      ];
    try {
      assignSpeakerTurns(
        meeting,
        parseSpeakerTurns(
          '0 -- 1 speaker_00\n1 -- 2 speaker_01\n2 -- 3 speaker_00',
        ),
      );
      await model.renameSpeaker(meeting, 'speaker_00', 'Alexandre');
      expect(meeting.segments.map(meeting.speakerLabel), [
        'Alexandre',
        'Intervenant 2',
        'Alexandre',
      ]);
      await model.updateSpeaker(
        meeting,
        meeting.segments[1],
        '',
        speakerId: 'speaker_00',
      );
      await model.renameSpeaker(meeting, 'speaker_00', 'Alex');
      final loaded = (await repository.load()).single;
      expect(loaded.segments.map(loaded.speakerLabel), [
        'Alex',
        'Alex',
        'Alex',
      ]);
      final exported = await engine.export(loaded, '${dir.path}/exports');
      final transcript = jsonDecode(
        await File('$exported/transcription.json').readAsString(),
      ) as List;
      expect(transcript.map((s) => (s as Map)['speaker']), [
        'Alex',
        'Alex',
        'Alex',
      ]);
      // Re-running detection preserves an explicit single-passage correction.
      assignSpeakerTurns(loaded, parseSpeakerTurns('0 -- 3 speaker_02'));
      expect(loaded.speakerLabel(loaded.segments[1]), 'Alex');
      expect(loaded.segments[1].speakerLocked, isTrue);
    } finally {
      model.dispose();
      await dir.delete(recursive: true);
    }
  });

  testWidgets(
    'Detected voices can be renamed once, heard and searched by name',
    (tester) async {
      final meeting = Meeting('test', 'Test', DateTime(2026))
        ..speakersDetected = true
        ..speakerNames = {'speaker_00': 'Alexandre'}
        ..segments = [Segment(0, 2000, 4000, 'Bonjour', '', 'speaker_00')];
      String? renamed;
      int? seek, count;
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: TranscriptPane(
              meeting: meeting,
              onSeek: (value) => seek = value,
              onEditSpeaker: (_) {},
              onEditText: (_) {},
              onRenameSpeaker: (id) => renamed = id,
              onDetectSpeakers: (value) => count = value,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Alexandre · 1'));
      expect(renamed, 'speaker_00');
      await tester.tap(find.byTooltip('Écouter Alexandre'));
      expect(seek, 2000);
      await tester.tap(find.byKey(const ValueKey('detect-speakers')));
      expect(count, 0);
      await tester.enterText(
        find.byKey(const ValueKey('transcript-search')),
        'Alexandre',
      );
      await tester.pump();
      expect(find.text('Bonjour'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('uncertain-speakers')));
      await tester.pump();
      expect(find.text('Bonjour'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('uncertain-speakers')));
      await tester.pump();
      expect(find.text('Bonjour'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Single-passage correction returns the selected stable voice ID',
    (tester) async {
      final meeting = Meeting('test', 'Test', DateTime(2026))
        ..speakerNames = {'speaker_00': 'Alexandre'};
      SpeakerAssignment? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async =>
                    result = await showDialog<SpeakerAssignment>(
                      context: context,
                      builder: (_) => SpeakerDialog(
                        meeting: meeting,
                        segment: Segment(0, 0, 1000, 'Texte'),
                      ),
                    ),
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alexandre').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Appliquer'));
      await tester.pumpAndSettle();
      expect(result, (speakerId: 'speaker_00', name: ''));
    },
  );
}
