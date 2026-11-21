import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:night_shift_planning/models/models.dart';
import 'package:night_shift_planning/services/pdf_export_service.dart';
import 'package:night_shift_planning/services/statistics_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  final members = [
    TeamMember(
      id: 'ARRAGAIN',
      firstName: 'ARRAGAIN',
      lastName: '',
      trigramme: 'ARRAGAIN',
    ),
    TeamMember(
      id: 'LEROY',
      firstName: 'LEROY',
      lastName: '',
      trigramme: 'LEROY',
    ),
  ];

  NightShift makeShift(
    String agent,
    int year,
    int month,
    int day, {
    bool isWorking = true,
    bool isVacation = false,
    String vacationType = '',
  }) =>
      NightShift(
        id: '${agent}_${year}_${month}_$day',
        date: DateTime(year, month, day),
        agentId: agent,
        agentTrigramme: agent,
        startTime: const TimeOfDay(hour: 19, minute: 0),
        endTime: const TimeOfDay(hour: 7, minute: 0),
        isWorking: isWorking,
        isVacation: isVacation,
        vacationType: vacationType,
      );

  test('generateTeamReportPdf produit un PDF valide avec le tableau équipe et la matrice mensuelle', () {
    final shifts = [
      makeShift('ARRAGAIN', 2026, 10, 31),
      makeShift('ARRAGAIN', 2026, 11, 1),
      makeShift(
        'ARRAGAIN',
        2026,
        11,
        5,
        isWorking: false,
        isVacation: true,
        vacationType: 'CA',
      ),
      makeShift('LEROY', 2026, 11, 2),
      makeShift('LEROY', 2026, 11, 3),
      makeShift('LEROY', 2026, 11, 4),
    ];

    final summary = StatisticsService.getTeamStatistics(
      allShifts: shifts,
      allTeamMembers: members,
      year: 2026,
      shiftDurationHours: 12.0,
    );

    final pdfBytes = PdfExportService.generateTeamReportPdf(
      summary,
      generatedAt: DateTime(2026, 11, 21),
    );

    expect(pdfBytes.length, greaterThan(1000));
    expect(String.fromCharCodes(pdfBytes.take(4)), '%PDF');

    final doc = PdfDocument(inputBytes: pdfBytes);
    final extractedText = PdfTextExtractor(doc).extractText();
    doc.dispose();

    expect(extractedText, contains('PLANNING CHI'));
    expect(extractedText, contains('ARRAGAIN'));
    expect(extractedText, contains('LEROY'));
    expect(extractedText, contains('36h'));
    expect(extractedText, contains('24h'));
    expect(extractedText, contains('60h'));
    expect(
      PdfExportService.buildTeamFileName(summary),
      'Bilan_Equipe_2026.pdf',
    );
  });

  test('generateAgentReportPdf produit une fiche individuelle PDF valide avec le détail des 12 mois', () {
    final shifts = [
      makeShift('ARRAGAIN', 2026, 1, 10),
      makeShift('ARRAGAIN', 2026, 1, 11),
      makeShift('ARRAGAIN', 2026, 4, 15),
    ];

    final summary = StatisticsService.getTeamStatistics(
      allShifts: shifts,
      allTeamMembers: members,
      year: 2026,
      shiftDurationHours: 12.0,
    );

    final arragainStat = summary.agentStats.firstWhere(
      (s) => s.teamMember.id == 'ARRAGAIN',
    );

    final pdfBytes = PdfExportService.generateAgentReportPdf(
      stat: arragainStat,
      year: 2026,
      generatedAt: DateTime(2026, 11, 21),
    );

    expect(pdfBytes.length, greaterThan(1000));
    expect(String.fromCharCodes(pdfBytes.take(4)), '%PDF');

    final doc = PdfDocument(inputBytes: pdfBytes);
    final extractedText = PdfTextExtractor(doc).extractText();
    doc.dispose();

    expect(extractedText, contains('ARRAGAIN'));
    expect(extractedText, contains('36h'));
    expect(extractedText, contains('Janvier'));
    expect(extractedText, contains('Avril'));
    expect(extractedText, contains('TOTAL ANNUEL'));
    expect(
      PdfExportService.buildAgentFileName(arragainStat, 2026),
      'Bilan_ARRAGAIN_2026.pdf',
    );
  });
}
