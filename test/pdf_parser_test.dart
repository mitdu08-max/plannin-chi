import 'package:flutter_test/flutter_test.dart';
import 'package:night_shift_planning/services/pdf_parser_service.dart';
import 'package:night_shift_planning/services/positioned_planning_parser.dart';

/// Jeu de test **synthétique** : aucun nom de soignant réel.
/// Les plannings d'origine ne doivent pas être versionnés (cf. .gitignore).
String _planning({
  String monthTitle = 'NOVEMBRE 2026',
  required List<String> rows,
}) {
  const header =
      'D01 L02 M03 M04 J05 V06 S07 D08 L09 M10 M11 J12 V13 S14 D15 L16 M17 '
      'M18 J19 V20 S21 D22 L23 M24 M25 J26 V27 S28 D29 L30';

  return <String>[
    header,
    'Nov S45 Nov Nov Nov Nov Nov Nov S46 Nov Nov Nov Nov Nov Nov S47 Nov Nov '
        'Nov Nov Nov Nov S48 Nov Nov Nov Nov Nov Nov S49',
    if (monthTitle.isNotEmpty) monthTitle,
    'ÉQUIPE DE NUIT',
    ...rows,
    'vacances scolaires',
    'Nom / Prénom',
  ].join('\n');
}

/// Construit la ligne d'un agent : [days] cellules, `R` par défaut.
String _row(
  String agent, {
  Map<int, String> codes = const {},
  int days = 30,
}) {
  final cells = [
    for (var day = 1; day <= days; day++) codes[day] ?? 'R',
  ];
  return '$agent ${cells.join(' ')}';
}

void main() {
  group('PdfParserService.parsePlanningText', () {
    test('extrait les nuits, les congés et le mois', () {
      final result = PdfParserService.parsePlanningText(
        _planning(
          rows: [
            _row('DUPONT', codes: {1: 'N', 3: 'CA', 4: 'CA', 5: 'N', 9: 'N'}),
            _row('MARTIN', codes: {2: 'N', 6: 'N', 10: 'N'}),
          ],
        ),
      );

      expect(result.year, 2026);
      expect(result.month, 11);
      expect(result.monthDetected, isTrue);
      expect(result.totalDays, 30);

      expect(result.agentShifts['DUPONT'], [1, 5, 9]);
      expect(result.agentVacations['DUPONT'], {3: 'CA', 4: 'CA'});
      expect(result.agentShifts['MARTIN'], [2, 6, 10]);

      expect(result.warnings, isEmpty,
          reason: 'warnings = ${result.warnings}');
    });

    test('détecte les agents inconnus (autre équipe que la liste connue)', () {
      final result = PdfParserService.parsePlanningText(
        _planning(rows: [_row('DUPONT'), _row('MARTIN')]),
      );

      // DUPONT et MARTIN ne font pas partie de AppConstants.knownAgentNames
      expect(result.agentShifts.keys, containsAll(['DUPONT', 'MARTIN']));
      expect(result.agentShifts.length, 2);
    });

    test('signale une ligne incomplète (risque de décalage)', () {
      final result = PdfParserService.parsePlanningText(
        _planning(
          rows: [
            _row('DUPONT', codes: {1: 'N', 5: 'N'}),
            _row('MARTIN', days: 27), // 3 cellules manquantes
          ],
        ),
      );

      expect(result.hasReliabilityIssue, isTrue);
      expect(
        result.warnings.any((w) => w.contains('MARTIN') && w.contains('27')),
        isTrue,
        reason: 'warnings = ${result.warnings}',
      );
      expect(result.tokenCounts['MARTIN'], 27);
    });

    test('signale une cellule en trop en fin de ligne', () {
      final result = PdfParserService.parsePlanningText(
        _planning(
          rows: [
            _row('DUPONT', codes: {1: 'N', 5: 'N'}, days: 31),
            _row('MARTIN'),
          ],
        ),
      );

      expect(
        result.warnings.any((w) => w.contains('DUPONT')),
        isTrue,
        reason: 'warnings = ${result.warnings}',
      );
      // Les 30 premiers jours restent alignés
      expect(result.agentShifts['DUPONT'], [1, 5]);
    });

    test('ne devine jamais le mois quand il est absent', () {
      final result = PdfParserService.parsePlanningText(
        _planning(
          monthTitle: '',
          rows: [_row('DUPONT', codes: {1: 'N', 5: 'N'})],
        ),
      );

      expect(result.monthDetected, isFalse);
      expect(result.warnings, isNotEmpty);
      // Les jours sont tout de même lus (31 par sécurité)
      expect(result.agentShifts['DUPONT'], [1, 5]);
    });

    test('accepte un mois forcé par l\'utilisateur', () {
      final result = PdfParserService.parsePlanningText(
        _planning(monthTitle: '', rows: [_row('DUPONT')]),
        forcedYear: 2026,
        forcedMonth: 10,
      );

      expect(result.monthDetected, isTrue);
      expect(result.month, 10);
      expect(result.totalDays, 31);
    });

    test('ne prend pas une ligne de continuation pour un nouvel agent', () {
      // 2 cellules puis 28 cellules sur la ligne suivante
      final continuation = _row('X', days: 28, codes: {3: 'N', 7: 'N'});
      final cells = continuation.split(' ').skip(1).join(' ');

      final result = PdfParserService.parsePlanningText(
        _planning(
          rows: [
            'DUPONT N R',
            cells,
            _row('MARTIN'),
          ],
        ),
      );

      expect(result.tokenCounts['DUPONT'], 30,
          reason: 'tokens = ${result.tokenCounts}');
      expect(result.agentShifts['DUPONT'], [1, 5, 9]);
      expect(result.agentShifts.length, 2);
    });

    test('lit les codes F EXT collés ou espacés', () {
      final result = PdfParserService.parsePlanningText(
        _planning(
          rows: [
            _row('DUPONT', codes: {1: 'F EXT', 2: 'N', 5: 'N', 8: 'N'}),
            _row('MARTIN', codes: {1: 'FEXT', 2: 'N', 5: 'N', 8: 'N'}),
          ],
        ),
      );

      expect(result.agentShifts['DUPONT'], [2, 5, 8]);
      expect(result.agentShifts['MARTIN'], [2, 5, 8]);
      expect(result.warnings, isEmpty, reason: 'warnings = ${result.warnings}');
    });
  });

  group('OCR positionné', () {
    PlanningOcrWord word(String text, double x, double y) => PlanningOcrWord(
          text: text,
          left: x,
          top: y,
          width: 10,
          height: 10,
        );

    test('conserve les jours manquants sans décaler les nuits suivantes', () {
      final words = <PlanningOcrWord>[
        for (var day = 1; day <= 31; day++)
          word('L${day.toString().padLeft(2, '0')}', 100 + day * 20.0, 10),
        word('DUPONT', 5, 50),
        word('N', 120, 50),
        word('RH', 140, 50),
        // Jour 3 illisible.
        word('N', 180, 50),
      ];
      final result = PdfParserService.parsePlanningText(
        'JANVIER 2026',
        ocrPages: [words],
      );

      expect(result.isOcr, isTrue);
      expect(result.agentShifts['DUPONT'], [1, 4]);
      expect(result.dayCodes['DUPONT']?[3], isNull);
      expect(result.dayCodes['DUPONT']?[4], 'N');
      expect(result.tokenCounts['DUPONT'], 3);
    });

    test('réanalyse les coordonnées si le mois est corrigé', () {
      final words = <PlanningOcrWord>[
        for (var day = 1; day <= 31; day++)
          word('L${day.toString().padLeft(2, '0')}', 100 + day * 20.0, 10),
        word('DUPONT', 5, 50),
        word('N', 120, 50),
        word('RH', 140, 50),
        word('N', 700, 50), // 30 janvier, hors février.
      ];
      final january = PdfParserService.parsePlanningText(
        'JANVIER 2026',
        ocrPages: [words],
      );
      final february = PdfParserService.parsePlanningText(
        january.rawText,
        forcedYear: 2026,
        forcedMonth: 2,
        ocrPages: january.ocrPages,
      );

      expect(january.agentShifts['DUPONT'], [1, 30]);
      expect(february.month, 2);
      expect(february.totalDays, 28);
      expect(february.agentShifts['DUPONT'], [1]);
      expect(february.dayCodes['DUPONT']?[30], isNull);
    });

    test('l’absence de coordonnées ne crée aucune case validée automatiquement', () {
      final result = PdfParserService.parsePlanningText(
        'JANVIER 2026\nDUPONT N RH N',
        ocrPages: const [[]],
      );
      expect(result.isOcr, isTrue);
      expect(result.dayCodes, isEmpty);
      expect(result.hasReliabilityIssue, isTrue);
    });

    test('les codes CS et FC ne deviennent pas des nuits ni des congés', () {
      final result = PdfParserService.parsePlanningText(
        'JANVIER 2026\nDUPONT N CS FC RH',
      );
      expect(result.agentShifts['DUPONT'], [1]);
      expect(result.agentVacations['DUPONT'] ?? {}, isEmpty);
      expect(result.warnings.any((warning) => warning.contains('CS ou FC')), isTrue);
    });
  });

}
