import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/data/meeting_repository.dart';
import 'package:memora/models/meeting.dart';
import 'package:memora/services/local_engine.dart';
import 'package:memora/ui/core/app_theme.dart';
import 'package:memora/ui/meeting/meeting_view.dart';
import 'package:memora/ui/meeting/meeting_header.dart';
import 'package:memora/ui/meeting/replay_pane.dart';
import 'package:memora/ui/workspace_view_model.dart';

void main() {
  testWidgets(
    'Interrupted meeting offers resume and keeps saved results visible',
    (tester) async {
      final meeting = Meeting('resume', 'Test interrompu', DateTime(2026))
        ..media = 'recording.mp4'
        ..status = .interrupted
        ..summary = 'Résumé sauvegardé'
        ..segments = [Segment(0, 0, 1000, 'Source')]
        ..error = 'Arrêt demandé';
      var resumed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: MeetingHeader(
              meeting: meeting,
              busy: false,
              processing: false,
              detail: '',
              saveState: 'Enregistré',
              onBack: () {},
              onRename: () {},
              onDelete: () {},
              onImport: () {},
              onAnalyze: () => resumed = true,
              onExport: () {},
              onCancel: () {},
            ),
          ),
        ),
      );
      expect(find.text('Reprendre le traitement'), findsOneWidget);
      expect(find.textContaining('Transcription sauvegardée'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('analyze')));
      expect(resumed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Document tab and editor survive reader toggles and resizing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = MeetingRepository(Directory.systemTemp);
    final model = WorkspaceViewModel(
      repository: repository,
      engine: LocalEngine(Directory.systemTemp, repository),
    );
    final meeting = Meeting('ui', 'Meeting test', DateTime(2026))
      ..media = 'recording.mp4'
      ..summary = 'Un résumé.';
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: LayoutBuilder(
            builder: (context, constraints) => MeetingView(
              meeting: meeting,
              model: model,
              wide: constraints.maxWidth >= 1100,
              player: null,
              video: null,
              onBack: () {},
              onRename: () {},
              onDelete: () {},
              onImport: () {},
              onExport: () {},
              onExportAudio: () {},
              onOpenFolder: () {},
              onAdopt: () {},
              onSeek: (_) {},
              onEditSpeaker: (_) {},
              onEditText: (_) {},
              onEditCaption: (_) {},
            ),
          ),
        ),
      ),
    );
    final readerWidth = tester.getSize(find.byType(ReplayPane)).width;
    await tester.drag(
      find.byKey(const ValueKey('reader-divider')),
      const Offset(100, 0),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(ReplayPane)).width,
      lessThan(readerWidth),
    );
    await tester.tap(find.byKey(const ValueKey('tab-notes')));
    await tester.pumpAndSettle();
    final editor = find.byKey(const ValueKey('notes-editor'));
    final controller = tester.widget<TextField>(editor).controller;
    controller!.selection = const TextSelection.collapsed(offset: 0);
    await tester.tap(find.byKey(const ValueKey('toggle-reader')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(editor).controller, same(controller));
    tester.view.physicalSize = const Size(900, 720);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(editor).controller, same(controller));
    await tester.tap(find.byKey(const ValueKey('toggle-reader')));
    await tester.pumpAndSettle();
    expect(editor, findsNothing);
    await tester.tap(find.byKey(const ValueKey('toggle-reader')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(editor).controller, same(controller));
    tester.view.physicalSize = const Size(1200, 850);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(editor).controller, same(controller));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    model.dispose();
  });
}
