import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:night_shift_planning/services/pdf_parser_service.dart';

void main() {
  test('PdfParserService.parsePlanningPdfFull with real user PDF', () async {
    final pdfPath = r'C:\Users\ATony\.gemini\antigravity-ide\brain\c1247b31-1cc3-4bbf-8a16-e1dc395c9754\.user_uploaded\media_1793023434781.pdf';
    final file = File(pdfPath);
    expect(file.existsSync(), isTrue);

    final result = await PdfParserService.parsePlanningPdfFull(file);
    print('Agents trouvés (${result.agentShifts.length}):');
    result.agentShifts.forEach((agent, shifts) {
      print('  $agent: ${shifts.length} nuits -> $shifts');
    });

    expect(result.year, equals(2026));
    expect(result.month, equals(11));
    expect(result.agentShifts.length, greaterThanOrEqualTo(12));
    expect(result.agentShifts.containsKey('RINAUDO'), isTrue);
    expect(result.agentShifts['RINAUDO'], equals([1, 6, 9, 10, 11, 18, 21, 22, 26, 27, 30]));
  });

  test('PdfParserService.parsePlanningText with October OCR text', () {
    const ocrText = '''
J01 V02 S03 D04 L05 M06 M07 J08 V09 S10 D11 L12 M13 M14 J15 V16 S17 D18 L19 M20 M21 J22 V23 S24 D25 L26 M27 M28 J29 V30 S31
Oct Oct Oct Oct S41 Oct Oct Oct Oct Oct Oct S42 Oct Oct Oct Oct Oct Oct S43 Oct Oct Oct Oct Oct Oct S44 Oct Oct Oct Oct Oct
RINAUDO                                R R RH RH N R R R RH N N RH R R N N RH RH N N R R RH N N RH R N R RH N
TETON R R RH RH N R R R RH N N RH R R N N RH RH R N N R RH N N RH R N R N RH
PIAZZA R R RH RH N R R R RH N N RH R R N N RH RH R N N R N RH RH N R R N RH N
RENFORT 1 R R R R N R R R RH N N RH R R N N RH RH R R R R N RH RH N N R R RH N
LEROY                                          N N RH RH R N N R R RH RH N R R R RH N N RH R R N R RH RH   CA     CA     CA     CA     CA   RH
MONTEILLET                       N N RH RH R N R F F RH RH N R R R RH N N RH R R N RH N N RH R N R R RH
CAUVIERE N N RH RH R N N R R RH RH N R R R RH N N RH R R N N RH RH R N N R RH N
LIBAULT N N RH RH R N N R R RH RH N R R R RH N N RH R R N N RH RH N N R R R RH
TOUZET R F EXT N N RH R R N N RH RH R N N R R RH RH   CA     CA     CA     CA     CA   RH RH N N R N N RH
ABDELALIM R F EXT N N RH R R N N RH RH R N N R R RH RH N R R R RH N N RH R R N N RH
ARRAGAIN R RH N N RH R R N N RH RH R N N R R RH RH N R N R R RH RH   CA     CA     CA     CA     CA   RH
MONTREUIL R R N N R R R N N R R R N N R R RH RH N R R R RH N N RH R R N N RH
WICKER R R RH RH J R R J RH J J RH R R R RH J J RH N N R R RH RH J J R R R J
vacances scolaires
Nom / Prénom
OCTOBRE 2026
ÉQUIPE DE NUIT
''';

    final result = PdfParserService.parsePlanningText(ocrText);
    print('Octobre - Mois: ${result.month}, Année: ${result.year}, Total Jours: ${result.totalDays}');
    print('ARRAGAIN nuits: ${result.agentShifts['ARRAGAIN']}');
    print('ARRAGAIN vacances: ${result.agentVacations['ARRAGAIN']}');

    expect(result.month, equals(10));
    expect(result.year, equals(2026));
    expect(result.totalDays, equals(31));
    expect(result.agentVacations.containsKey('ARRAGAIN'), isTrue);
  });
}
