import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/app.dart';
import 'package:memora/data/meeting_repository.dart';

void main() {
  testWidgets('Create a meeting and persist personal notes at desktop width', (
    tester,
  ) async {
    final root = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('memora-ui-test-'),
    ))!;
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    try {
      await tester.runAsync(() async {
        await tester.pumpWidget(MemoraApp(root: root));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      expect(find.text("Vos conversations,\nl'esprit libre."), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('prepare-home')));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.enterText(
          find.byKey(const ValueKey('notes-editor')),
          'Demander la date de livraison.',
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      final entries = await tester.runAsync(
        () =>
            MeetingRepository(Directory('${root.path}/.local/meetings')).load(),
      );
      expect(entries!.single.notes, 'Demander la date de livraison.');
      await tester.tap(find.text('Démarrer le repère temps'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Bibliothèque'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(entries.single.title).last);
      await tester.pumpAndSettle();
      expect(find.text('Démarrer le repère temps'), findsNothing);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('mark-moment')));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      expect(find.textContaining('Moment important : '), findsOneWidget);
      expect(tester.takeException(), isNull);
      // The same screen must remain usable at a smaller desktop window size.
      tester.view.physicalSize = const Size(900, 720);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final delete = find.byKey(ValueKey('delete-${entries.single.id}'));
      await tester.tap(delete);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('notes-editor')), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(delete);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('confirm-delete')));
        await tester.pumpAndSettle();
        await Future<void>.delayed(const Duration(milliseconds: 250));
      });
      await tester.pumpAndSettle();
      expect(
        await tester.runAsync(
          () =>
              MeetingRepository(Directory('${root.path}/.local/meetings'))
                  .load(),
        ),
        isEmpty,
      );
      expect(find.text('Meeting supprimé de la bibliothèque.'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('Annuler'));
        await Future<void>.delayed(const Duration(milliseconds: 250));
      });
      await tester.pumpAndSettle();
      final restored = await tester.runAsync(
        () =>
            MeetingRepository(Directory('${root.path}/.local/meetings')).load(),
      );
      expect(
        restored!.single.notes,
        startsWith('Demander la date de livraison.'),
      );
      expect(restored.single.notes, contains('Moment important : '));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    } finally {
      await tester.runAsync(() => root.delete(recursive: true));
    }
  });
}
