import 'package:flutter_test/flutter_test.dart';
import 'package:night_shift_planning/services/positioned_planning_parser.dart';

PlanningOcrWord _word(
  String text,
  double centerX,
  double centerY, {
  double width = 12,
  double height = 12,
}) => PlanningOcrWord(
  text: text,
  left: centerX - width / 2,
  top: centerY - height / 2,
  width: width,
  height: height,
);

List<PlanningOcrWord> _header({int days = 31}) => [
  for (var day = 1; day <= days; day++)
    _word('J${day.toString().padLeft(2, '0')}', 100 + day * 40, 40),
];

void main() {
  group('PositionedPlanningParser', () {
    test('une case manquante ne décale pas les jours suivants', () {
      final words = [
        ..._header(),
        _word('DUPONT', 40, 110),
        _word('N', 140, 110),
        _word('RH', 180, 110),
        // Jour 3 non reconnu.
        _word('N', 260, 110),
        _word('CA', 300, 110),
        _word('MARTIN', 40, 180),
        _word('R', 140, 180),
        _word('N', 180, 180),
        _word('RH', 220, 180),
      ];

      final result = PositionedPlanningParser.parse([words], totalDays: 31)!;
      expect(result.dayCodes['DUPONT'], {1: 'N', 2: 'RH', 4: 'N', 5: 'CA'});
      expect(result.dayCodes['MARTIN'], {1: 'R', 2: 'N', 3: 'RH'});
      expect(result.warnings.any((w) => w.contains('non reconnue')), isTrue);
    });

    test('ignore une colonne du mois suivant', () {
      final words = [
        ..._header(days: 28),
        _word('D01', 100 + 29 * 40, 40),
        _word('DUPONT', 40, 110),
        _word('N', 100 + 28 * 40, 110),
        _word('N', 100 + 29 * 40, 110),
        _word('R', 140, 110),
      ];
      final result = PositionedPlanningParser.parse([words], totalDays: 28)!;
      expect(result.dayCodes['DUPONT'], {1: 'R', 28: 'N'});
    });

    test('une case contradictoire reste inconnue', () {
      final words = [
        ..._header(),
        _word('DUPONT', 40, 110),
        _word('N', 140, 110),
        _word('R', 140, 110),
        _word('N', 180, 110),
        _word('R', 220, 110),
      ];
      final result = PositionedPlanningParser.parse([words], totalDays: 31)!;
      expect(result.dayCodes['DUPONT']!.containsKey(1), isFalse);
      expect(result.dayCodes['DUPONT']![2], 'N');
    });

    test('une contradiction sur une page reste inconnue après fusion', () {
      final firstPage = [
        ..._header(),
        _word('DUPONT', 40, 110),
        _word('N', 140, 110),
        _word('R', 140, 110),
        _word('N', 180, 110),
        _word('R', 220, 110),
      ];
      final secondPage = [
        ..._header(),
        _word('DUPONT', 40, 110),
        _word('N', 140, 110),
        _word('N', 180, 110),
        _word('R', 220, 110),
      ];
      final result = PositionedPlanningParser.parse([
        firstPage,
        secondPage,
      ], totalDays: 31)!;
      expect(result.dayCodes['DUPONT']!.containsKey(1), isFalse);
      expect(result.warnings.any((w) => w.contains('contradictoires')), isTrue);
    });

    test('des noms identiques sur une page restent ambigus', () {
      final duplicate = [
        ..._header(),
        _word('DUPONT', 40, 110),
        _word('N', 140, 110),
        _word('R', 180, 110),
        _word('DUPONT', 40, 180),
        _word('R', 140, 180),
        _word('N', 180, 180),
      ];
      final anotherPage = [
        ..._header(),
        _word('DUPONT', 40, 110),
        _word('N', 140, 110),
        _word('R', 180, 110),
      ];
      final result = PositionedPlanningParser.parse([
        duplicate,
        anotherPage,
      ], totalDays: 31)!;
      expect(result.dayCodes['DUPONT'], isEmpty);
      expect(result.warnings.any((w) => w.contains('contradictoires')), isTrue);
      expect(result.warnings.any((w) => w.contains('même nom')), isTrue);
    });

    test('refuse de deviner les colonnes sans assez de repères', () {
      final words = [
        _word('J01', 140, 40),
        _word('J02', 180, 40),
        _word('DUPONT', 40, 110),
        _word('N', 140, 110),
        _word('R', 180, 110),
      ];
      expect(PositionedPlanningParser.parse([words], totalDays: 31), isNull);
    });

    test('accepte des repères manquants sans inventer de cellules', () {
      final words = [
        for (final day in [2, 5, 10, 16, 22, 30])
          _word('J${day.toString().padLeft(2, '0')}', 100 + day * 40, 40),
        _word('DUPONT', 40, 110),
        _word('N', 140, 110),
        _word('N', 100 + 29 * 40, 110),
      ];
      final result = PositionedPlanningParser.parse([words], totalDays: 31)!;
      expect(result.dayCodes['DUPONT'], {1: 'N', 29: 'N'});
    });
  });
}
