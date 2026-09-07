import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memora/models/meeting.dart';
import 'package:memora/ui/core/app_theme.dart';
import 'package:memora/ui/meeting/summary_pane.dart';

void main() {
  testWidgets(
    'Summary editor remains available when cleared and preview follows edits',
    (tester) async {
      final meeting = Meeting('summary-test', 'Réunion', DateTime(2026))
        ..summary = 'Résumé initial';
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, refresh) => SummaryPane(
                meeting: meeting,
                folder: '',
                onChanged: (value) => refresh(() => meeting.summary = value),
                onSeek: (_) {},
                onAdopt: () {},
                onEditCaption: (_) {},
                onRemoveCapture: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Modifier'));
      await tester.pumpAndSettle();
      final editor = find.byKey(const ValueKey('summary-editor'));
      await tester.enterText(editor, '');
      await tester.pumpAndSettle();
      expect(editor, findsOneWidget);
      await tester.enterText(editor, 'Résumé corrigé');
      await tester.tap(find.text('Aperçu'));
      await tester.pumpAndSettle();
      expect(meeting.summary, 'Résumé corrigé');
      expect(find.text('Résumé corrigé'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
