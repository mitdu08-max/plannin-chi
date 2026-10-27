import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:night_shift_planning/screens/ocr_review_dialog.dart';

void main() {
  testWidgets(
    'une ligne OCR doit être complétée et vérifiée avant validation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 480));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OcrReviewDialog(
              agent: 'DUPONT',
              year: 2026,
              month: 2,
              detectedCodes: {1: 'N'},
            ),
          ),
        ),
      );

      final continueButton = find.widgetWithText(ElevatedButton, 'Continuer');
      expect(tester.widget<ElevatedButton>(continueButton).onPressed, isNull);

      final fillUnknowns = find.text('Mettre les 27 « ? » en repos / autre');
      await tester.ensureVisible(fillUnknowns);
      await tester.tap(fillUnknowns);
      await tester.pump();
      // Remplir les cases ne suffit pas : la comparaison doit être confirmée.
      expect(tester.widget<ElevatedButton>(continueButton).onPressed, isNull);

      final verified = find.byType(CheckboxListTile);
      await tester.ensureVisible(verified);
      await tester.tap(verified);
      await tester.pump();
      expect(
        tester.widget<ElevatedButton>(continueButton).onPressed,
        isNotNull,
      );

      final day = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'Jour 2, R',
      );
      await tester.ensureVisible(day);
      await tester.tap(day);
      await tester.pump();
      // Toute modification exige une nouvelle confirmation de la ligne.
      expect(tester.widget<ElevatedButton>(continueButton).onPressed, isNull);
    },
  );
}
