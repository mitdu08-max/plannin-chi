import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'statistics_service.dart';

/// Service de génération, d'enregistrement et de partage des bilans PDF
/// (Bilan Global Équipe et Fiche Individuelle par Agent).
class PdfExportService {
  static const MethodChannel _channel = MethodChannel(
    'com.planningperso.night_shift_planning/pdf_export',
  );

  static const List<String> _monthNames = [
    '',
    'Janvier',
    'Février',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Août',
    'Septembre',
    'Octobre',
    'Novembre',
    'Décembre',
  ];

  static const List<String> _shortMonths = [
    '',
    'Jan',
    'Fév',
    'Mar',
    'Avr',
    'Mai',
    'Juin',
    'Juil',
    'Août',
    'Sep',
    'Oct',
    'Nov',
    'Déc',
  ];

  /// Nettoie une chaîne pour la police PDF standard (WinAnsi / Latin-1).
  static String _clean(String input) {
    return input
        .replaceAll('•', '-')
        .replaceAll('·', '-')
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('…', '...')
        .replaceAll('’', "'")
        .replaceAll('‘', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('\u202F', ' ')
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'[^\x20-\x7E\xA0-\xFF]'), '');
  }

  static String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}';
  }

  /// Nom de fichier propre pour un bilan d'équipe.
  static String buildTeamFileName(TeamPeriodSummary summary) {
    if (summary.month != null) {
      final m = _clean(_monthNames[summary.month!])
          .replaceAll('é', 'e')
          .replaceAll('û', 'u');
      return 'Bilan_Equipe_${m}_${summary.year}.pdf';
    }
    return 'Bilan_Equipe_${summary.year}.pdf';
  }

  /// Nom de fichier propre pour la fiche d'un agent.
  static String buildAgentFileName(
    AgentPeriodStats stat,
    int year, {
    int? month,
  }) {
    final safeName = _clean(stat.displayName)
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    if (month != null) {
      final m = _clean(_monthNames[month])
          .replaceAll('é', 'e')
          .replaceAll('û', 'u');
      return 'Bilan_${safeName}_${m}_$year.pdf';
    }
    return 'Bilan_${safeName}_$year.pdf';
  }

  /// Génère le PDF du Bilan Global de l'Équipe (mensuel ou annuel).
  static Uint8List generateTeamReportPdf(
    TeamPeriodSummary summary, {
    DateTime? generatedAt,
  }) {
    final now = generatedAt ?? DateTime.now();
    final document = PdfDocument();
    document.pageSettings.size = PdfPageSize.a4;
    document.pageSettings.margins.all = 28;

    final page = document.pages.add();
    final pageWidth = page.getClientSize().width;

    // Polices
    final titleFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      16,
      style: PdfFontStyle.bold,
    );
    final subtitleFont = PdfStandardFont(PdfFontFamily.helvetica, 10);
    final sectionFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      11,
      style: PdfFontStyle.bold,
    );
    final headerCellFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      8.5,
      style: PdfFontStyle.bold,
    );
    final cellFont = PdfStandardFont(PdfFontFamily.helvetica, 8.5);
    final boldCellFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      8.5,
      style: PdfFontStyle.bold,
    );
    final smallGridFont = PdfStandardFont(PdfFontFamily.helvetica, 7.5);
    final smallGridBoldFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      7.5,
      style: PdfFontStyle.bold,
    );

    final periodLabel = summary.month != null
        ? 'Mois de ${_monthNames[summary.month!]} ${summary.year}'
        : 'Année ${summary.year} (${summary.coveredMonths.length}/12 mois renseignés)';

    // 1. Bandeau d'en-tête
    var y = _drawHeaderBanner(
      page: page,
      pageWidth: pageWidth,
      title: "PLANNING CHI - BILAN D'ÉQUIPE DE NUIT",
      subtitle: periodLabel,
      dateText: 'Édité le ${_formatDate(now)}',
      titleFont: titleFont,
      subtitleFont: subtitleFont,
    );

    y += 14;

    // 2. Cartes KPI globales
    y = _drawKpiRow(
      page: page,
      pageWidth: pageWidth,
      top: y,
      items: [
        _KpiBoxItem(
          label: 'TOTAL NUITS ÉQUIPE',
          value: '${summary.totalTeamNights}',
          accent: PdfColor(0, 137, 166),
        ),
        _KpiBoxItem(
          label: 'TOTAL HEURES ÉQUIPE',
          value: StatisticsService.formatHours(summary.totalTeamHours),
          accent: PdfColor(56, 128, 0),
        ),
        _KpiBoxItem(
          label: 'AGENTS ACTIFS',
          value: '${summary.activeAgentsCount}/${summary.agentStats.length}',
          accent: PdfColor(180, 110, 0),
        ),
        _KpiBoxItem(
          label: summary.month != null ? 'CONGÉS POSÉS' : 'MOIS COUVERTS',
          value: summary.month != null
              ? '${summary.totalTeamVacations} j'
              : '${summary.coveredMonths.length} / 12',
          accent: PdfColor(13, 34, 53),
        ),
      ],
    );

    y += 18;

    // 3. Titre Tableau principal
    page.graphics.drawString(
      _clean('1. Récapitulatif général par membre de l\'équipe'),
      sectionFont,
      brush: PdfSolidBrush(PdfColor(13, 34, 53)),
      bounds: Rect.fromLTWH(0, y, pageWidth, 16),
    );
    y += 20;

    // Tableau principal de l'équipe
    final grid = PdfGrid();
    grid.columns.add(count: 8);
    grid.repeatHeader = true;

    final header = grid.headers.add(1)[0];
    final headersText = [
      '#',
      'Agent',
      'Nuits',
      'Heures',
      'WE Travaillés',
      'WE Complets',
      'Demi WE',
      'Congés (CA)',
    ];
    for (var i = 0; i < headersText.length; i++) {
      header.cells[i].value = _clean(headersText[i]);
    }
    _styleGridHeader(header, headerCellFont);

    // Largeurs de colonnes (Total ~ 539pt sur A4 avec marges 28)
    grid.columns[0].width = 26;
    grid.columns[1].width = 135;
    grid.columns[2].width = 55;
    grid.columns[3].width = 65;
    grid.columns[4].width = 68;
    grid.columns[5].width = 65;
    grid.columns[6].width = 58;
    grid.columns[7].width = 65;

    var totalWeWorked = 0;
    var totalFullWe = 0;
    var totalHalfWe = 0;

    for (var i = 0; i < summary.agentStats.length; i++) {
      final stat = summary.agentStats[i];
      totalWeWorked += stat.weekendsWorked;
      totalFullWe += stat.fullWeekendsWorked;
      totalHalfWe += stat.halfWeekendsWorked;

      final row = grid.rows.add();
      row.cells[0].value = '${i + 1}'.padLeft(2, '0');
      row.cells[1].value = _clean(stat.displayName);
      row.cells[2].value = '${stat.totalNights}';
      row.cells[3].value = StatisticsService.formatHours(stat.totalHours);
      row.cells[4].value = '${stat.weekendsWorked}';
      row.cells[5].value = '${stat.fullWeekendsWorked}';
      row.cells[6].value = '${stat.halfWeekendsWorked}';
      row.cells[7].value = '${stat.vacationDays}';

      _styleGridRow(row, cellFont, isEven: i.isEven, leftAlignIndex: 1);
    }

    // Ligne Total Équipe
    final totalRow = grid.rows.add();
    totalRow.cells[0].value = '';
    totalRow.cells[1].value = 'TOTAL ÉQUIPE';
    totalRow.cells[2].value = '${summary.totalTeamNights}';
    totalRow.cells[3].value =
        StatisticsService.formatHours(summary.totalTeamHours);
    totalRow.cells[4].value = '$totalWeWorked';
    totalRow.cells[5].value = '$totalFullWe';
    totalRow.cells[6].value = '$totalHalfWe';
    totalRow.cells[7].value = '${summary.totalTeamVacations}';
    _styleGridTotalRow(totalRow, boldCellFont, leftAlignIndex: 1);

    final layoutResult = grid.draw(
      page: page,
      bounds: Rect.fromLTWH(0, y, pageWidth, 0),
    )!;

    // 4. En mode Année : Matrice mensuelle des nuits (Jan..Déc)
    if (summary.month == null && summary.agentStats.isNotEmpty) {
      var currentPage = layoutResult.page;
      var nextY = layoutResult.bounds.bottom + 22;

      if (nextY + 140 > currentPage.getClientSize().height) {
        currentPage = document.pages.add();
        nextY = 10;
      }

      currentPage.graphics.drawString(
        _clean('2. Détail mensuel des nuits travaillées (${summary.year})'),
        sectionFont,
        brush: PdfSolidBrush(PdfColor(13, 34, 53)),
        bounds: Rect.fromLTWH(0, nextY, pageWidth, 16),
      );
      nextY += 20;

      final monthGrid = PdfGrid();
      monthGrid.columns.add(count: 14);
      monthGrid.repeatHeader = true;

      final mHeader = monthGrid.headers.add(1)[0];
      mHeader.cells[0].value = 'Agent';
      for (var m = 1; m <= 12; m++) {
        mHeader.cells[m].value = _clean(_shortMonths[m]);
      }
      mHeader.cells[13].value = 'Total';
      _styleGridHeader(mHeader, smallGridBoldFont);

      monthGrid.columns[0].width = 110;
      for (var m = 1; m <= 12; m++) {
        monthGrid.columns[m].width = 32;
      }
      monthGrid.columns[13].width = 43;

      final monthlyTotals = <int, int>{for (var m = 1; m <= 12; m++) m: 0};

      for (var i = 0; i < summary.agentStats.length; i++) {
        final stat = summary.agentStats[i];
        final row = monthGrid.rows.add();
        row.cells[0].value = _clean(stat.displayName);
        for (var m = 1; m <= 12; m++) {
          final count = stat.monthlyNights[m] ?? 0;
          monthlyTotals[m] = (monthlyTotals[m] ?? 0) + count;
          row.cells[m].value = count > 0 ? '$count' : '-';
        }
        row.cells[13].value = '${stat.totalNights}';
        _styleGridRow(row, smallGridFont, isEven: i.isEven, leftAlignIndex: 0);
      }

      final mTotalRow = monthGrid.rows.add();
      mTotalRow.cells[0].value = 'TOTAL MOIS';
      for (var m = 1; m <= 12; m++) {
        mTotalRow.cells[m].value = '${monthlyTotals[m] ?? 0}';
      }
      mTotalRow.cells[13].value = '${summary.totalTeamNights}';
      _styleGridTotalRow(mTotalRow, smallGridBoldFont, leftAlignIndex: 0);

      monthGrid.draw(
        page: currentPage,
        bounds: Rect.fromLTWH(0, nextY, pageWidth, 0),
      );
    }

    _drawFooters(document, now);

    final bytes = Uint8List.fromList(document.saveSync());
    document.dispose();
    return bytes;
  }

  /// Génère le PDF de la Fiche Récapitulative Individuelle d'un agent.
  static Uint8List generateAgentReportPdf({
    required AgentPeriodStats stat,
    required int year,
    int? month,
    DateTime? generatedAt,
  }) {
    final now = generatedAt ?? DateTime.now();
    final document = PdfDocument();
    document.pageSettings.size = PdfPageSize.a4;
    document.pageSettings.margins.all = 28;

    final page = document.pages.add();
    final pageWidth = page.getClientSize().width;

    final titleFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      15,
      style: PdfFontStyle.bold,
    );
    final subtitleFont = PdfStandardFont(PdfFontFamily.helvetica, 10);
    final sectionFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      11,
      style: PdfFontStyle.bold,
    );
    final headerCellFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      8.5,
      style: PdfFontStyle.bold,
    );
    final cellFont = PdfStandardFont(PdfFontFamily.helvetica, 8.5);
    final boldCellFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      8.5,
      style: PdfFontStyle.bold,
    );

    final periodLabel = month != null
        ? 'Mois de ${_monthNames[month]} $year'
        : 'Année $year (${stat.coveredMonths.length}/12 mois renseignés)';

    // 1. Bandeau d'en-tête
    var y = _drawHeaderBanner(
      page: page,
      pageWidth: pageWidth,
      title: 'FICHE RÉCAPITULATIVE - ${_clean(stat.displayName)}',
      subtitle: 'Planning CHI • $periodLabel',
      dateText: 'Édité le ${_formatDate(now)}',
      titleFont: titleFont,
      subtitleFont: subtitleFont,
    );

    y += 14;

    // 2. Cartes KPI de l'agent
    y = _drawKpiRow(
      page: page,
      pageWidth: pageWidth,
      top: y,
      items: [
        _KpiBoxItem(
          label: 'NUITS TRAVAILLÉES',
          value: '${stat.totalNights}',
          accent: PdfColor(0, 137, 166),
        ),
        _KpiBoxItem(
          label: 'HEURES TOTALES',
          value: StatisticsService.formatHours(stat.totalHours),
          accent: PdfColor(56, 128, 0),
        ),
        _KpiBoxItem(
          label: 'WEEK-ENDS TRAVAILLÉS',
          value: '${stat.weekendsWorked} (${stat.fullWeekendsWorked}c/${stat.halfWeekendsWorked}d)',
          accent: PdfColor(180, 110, 0),
        ),
        _KpiBoxItem(
          label: 'CONGÉS (CA/CET/CFR)',
          value: '${stat.vacationDays} j',
          accent: PdfColor(13, 34, 53),
        ),
      ],
    );

    y += 18;

    // 3. Analyse des week-ends & répartition hebdomadaire
    page.graphics.drawString(
      _clean('1. Répartition par jour de la semaine & week-ends'),
      sectionFont,
      brush: PdfSolidBrush(PdfColor(13, 34, 53)),
      bounds: Rect.fromLTWH(0, y, pageWidth, 16),
    );
    y += 18;

    final weekGrid = PdfGrid();
    weekGrid.columns.add(count: 8);
    final wHeader = weekGrid.headers.add(1)[0];
    const days = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche',
      'Total',
    ];
    for (var i = 0; i < days.length; i++) {
      wHeader.cells[i].value = days[i];
    }
    _styleGridHeader(wHeader, headerCellFont);

    final wRow = weekGrid.rows.add();
    for (var d = 1; d <= 7; d++) {
      wRow.cells[d - 1].value = '${stat.weekdayCounts[d] ?? 0}';
    }
    wRow.cells[7].value = '${stat.totalNights}';
    _styleGridRow(wRow, boldCellFont, isEven: true);

    final wResult = weekGrid.draw(
      page: page,
      bounds: Rect.fromLTWH(0, y, pageWidth, 0),
    )!;
    y = wResult.bounds.bottom + 10;

    // Encadré résumé des week-ends
    final weText = _clean(
      'Détail des week-ends : ${stat.fullWeekendsWorked} week-end(s) complet(s) travaillé(s)  |  '
      '${stat.halfWeekendsWorked} demi week-end(s)  |  '
      '${stat.weekendAnalysis.fullWeekendsRest} week-end(s) de repos complet  |  '
      'Taux : ${stat.weekendAnalysis.workedPercentage.toStringAsFixed(1)}%',
    );
    page.graphics.drawRectangle(
      brush: PdfSolidBrush(PdfColor(240, 246, 250)),
      pen: PdfPen(PdfColor(200, 216, 228)),
      bounds: Rect.fromLTWH(0, y, pageWidth, 24),
    );
    page.graphics.drawString(
      weText,
      cellFont,
      brush: PdfSolidBrush(PdfColor(13, 34, 53)),
      bounds: Rect.fromLTWH(10, y + 6, pageWidth - 20, 14),
    );
    y += 38;

    // 4. Tableau détaillé mois par mois (en mode Année)
    if (month == null) {
      page.graphics.drawString(
        _clean('2. Récapitulatif mensuel détaillé ($year)'),
        sectionFont,
        brush: PdfSolidBrush(PdfColor(13, 34, 53)),
        bounds: Rect.fromLTWH(0, y, pageWidth, 16),
      );
      y += 20;

      final mGrid = PdfGrid();
      mGrid.columns.add(count: 7);
      mGrid.repeatHeader = true;

      final mh = mGrid.headers.add(1)[0];
      const mCols = [
        'Mois',
        'Nuits',
        'Heures',
        'WE Complets',
        'Demi WE',
        'Congés (CA)',
        'Statut',
      ];
      for (var i = 0; i < mCols.length; i++) {
        mh.cells[i].value = _clean(mCols[i]);
      }
      _styleGridHeader(mh, headerCellFont);

      mGrid.columns[0].width = 95;
      mGrid.columns[1].width = 65;
      mGrid.columns[2].width = 75;
      mGrid.columns[3].width = 75;
      mGrid.columns[4].width = 68;
      mGrid.columns[5].width = 75;
      mGrid.columns[6].width = 84;

      for (var m = 1; m <= 12; m++) {
        final n = stat.monthlyNights[m] ?? 0;
        final h = stat.monthlyHours[m] ?? 0.0;
        final vac = stat.monthlyVacations[m] ?? 0;
        final we = stat.monthlyWeekends[m];
        final covered = stat.coveredMonths.contains(m);

        final row = mGrid.rows.add();
        row.cells[0].value = _clean(_monthNames[m]);
        row.cells[1].value = '$n';
        row.cells[2].value = StatisticsService.formatHours(h);
        row.cells[3].value = '${we?.fullWeekendsWorked ?? 0}';
        row.cells[4].value = '${we?.halfWeekendsWorked ?? 0}';
        row.cells[5].value = '$vac';
        row.cells[6].value = covered ? 'Renseigné' : 'Non renseigné';

        _styleGridRow(row, cellFont, isEven: m.isEven, leftAlignIndex: 0);
      }

      final totalRow = mGrid.rows.add();
      totalRow.cells[0].value = 'TOTAL ANNUEL';
      totalRow.cells[1].value = '${stat.totalNights}';
      totalRow.cells[2].value = StatisticsService.formatHours(stat.totalHours);
      totalRow.cells[3].value = '${stat.fullWeekendsWorked}';
      totalRow.cells[4].value = '${stat.halfWeekendsWorked}';
      totalRow.cells[5].value = '${stat.vacationDays}';
      totalRow.cells[6].value = '${stat.coveredMonths.length}/12 mois';
      _styleGridTotalRow(totalRow, boldCellFont, leftAlignIndex: 0);

      mGrid.draw(
        page: page,
        bounds: Rect.fromLTWH(0, y, pageWidth, 0),
      );
    }

    _drawFooters(document, now);

    final bytes = Uint8List.fromList(document.saveSync());
    document.dispose();
    return bytes;
  }

  /// Enregistre le PDF dans le dossier Téléchargements du téléphone (ou via
  /// sélecteur de fichiers en repli) et renvoie l'emplacement lisible.
  static Future<String?> savePdfToDevice({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (Platform.isAndroid) {
      try {
        final savedPath = await _channel.invokeMethod<String>(
          'savePdfToDownloads',
          {
            'fileName': fileName,
            'bytes': bytes,
          },
        );
        if (savedPath != null && savedPath.isNotEmpty) {
          return savedPath;
        }
      } catch (_) {
        // Repli sur FilePicker ci-dessous si le canal natif échoue
      }
    }

    final outputUri = await FilePicker.saveFile(
      dialogTitle: 'Enregistrer le bilan PDF',
      fileName: fileName,
      bytes: bytes,
    );
    return outputUri?.toString();
  }

  /// Ouvre le menu de partage natif Android (WhatsApp, Mail, Drive, Impression...)
  /// avec le fichier PDF attaché.
  static Future<bool> sharePdf({
    required Uint8List bytes,
    required String fileName,
    required String title,
  }) async {
    if (Platform.isAndroid) {
      final shared = await _channel.invokeMethod<bool>(
        'sharePdf',
        {
          'fileName': fileName,
          'title': title,
          'bytes': bytes,
        },
      );
      return shared ?? false;
    }

    final saved = await savePdfToDevice(bytes: bytes, fileName: fileName);
    return saved != null;
  }

  // ---------------------------------------------------------------------------
  // Helpers graphiques PDF
  // ---------------------------------------------------------------------------

  static double _drawHeaderBanner({
    required PdfPage page,
    required double pageWidth,
    required String title,
    required String subtitle,
    required String dateText,
    required PdfFont titleFont,
    required PdfFont subtitleFont,
  }) {
    const bannerHeight = 58.0;
    page.graphics.drawRectangle(
      brush: PdfSolidBrush(PdfColor(13, 34, 53)),
      bounds: Rect.fromLTWH(0, 0, pageWidth, bannerHeight),
    );
    page.graphics.drawRectangle(
      brush: PdfSolidBrush(PdfColor(0, 185, 216)),
      bounds: Rect.fromLTWH(0, bannerHeight - 4, pageWidth, 4),
    );

    page.graphics.drawString(
      _clean(title),
      titleFont,
      brush: PdfBrushes.white,
      bounds: Rect.fromLTWH(14, 10, pageWidth - 28, 22),
    );

    page.graphics.drawString(
      _clean(subtitle),
      subtitleFont,
      brush: PdfSolidBrush(PdfColor(185, 232, 245)),
      bounds: Rect.fromLTWH(14, 33, pageWidth * 0.68, 16),
    );

    page.graphics.drawString(
      _clean(dateText),
      subtitleFont,
      brush: PdfSolidBrush(PdfColor(185, 232, 245)),
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
      bounds: Rect.fromLTWH(pageWidth * 0.65, 33, pageWidth * 0.35 - 14, 16),
    );

    return bannerHeight;
  }

  static double _drawKpiRow({
    required PdfPage page,
    required double pageWidth,
    required double top,
    required List<_KpiBoxItem> items,
  }) {
    const boxHeight = 46.0;
    const gap = 8.0;
    final boxWidth = (pageWidth - gap * (items.length - 1)) / items.length;
    final labelFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      7.5,
      style: PdfFontStyle.bold,
    );
    final valueFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      14,
      style: PdfFontStyle.bold,
    );

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final x = i * (boxWidth + gap);

      page.graphics.drawRectangle(
        brush: PdfSolidBrush(PdfColor(246, 249, 252)),
        pen: PdfPen(PdfColor(210, 222, 232)),
        bounds: Rect.fromLTWH(x, top, boxWidth, boxHeight),
      );
      page.graphics.drawRectangle(
        brush: PdfSolidBrush(item.accent),
        bounds: Rect.fromLTWH(x, top, 3.5, boxHeight),
      );

      page.graphics.drawString(
        _clean(item.value),
        valueFont,
        brush: PdfSolidBrush(item.accent),
        bounds: Rect.fromLTWH(x + 10, top + 7, boxWidth - 14, 20),
      );

      page.graphics.drawString(
        _clean(item.label),
        labelFont,
        brush: PdfSolidBrush(PdfColor(90, 110, 125)),
        bounds: Rect.fromLTWH(x + 10, top + 29, boxWidth - 14, 12),
      );
    }

    return top + boxHeight;
  }

  static void _styleGridHeader(PdfGridRow header, PdfFont font) {
    header.style = PdfGridRowStyle(
      backgroundBrush: PdfSolidBrush(PdfColor(13, 34, 53)),
      textBrush: PdfBrushes.white,
      font: font,
    );
    for (var i = 0; i < header.cells.count; i++) {
      header.cells[i].style.cellPadding = PdfPaddings(
        left: 4,
        right: 4,
        top: 5,
        bottom: 5,
      );
      header.cells[i].stringFormat = PdfStringFormat(
        alignment: PdfTextAlignment.center,
        lineAlignment: PdfVerticalAlignment.middle,
      );
    }
  }

  static void _styleGridRow(
    PdfGridRow row,
    PdfFont font, {
    required bool isEven,
    int? leftAlignIndex,
  }) {
    final bg = isEven ? PdfColor(248, 251, 253) : PdfColor(255, 255, 255);
    final borderPen = PdfPen(PdfColor(218, 226, 234), width: 0.5);

    for (var i = 0; i < row.cells.count; i++) {
      final cell = row.cells[i];
      cell.style.backgroundBrush = PdfSolidBrush(bg);
      cell.style.textBrush = PdfSolidBrush(PdfColor(18, 32, 44));
      cell.style.font = font;
      cell.style.borders = PdfBorders(
        left: borderPen,
        right: borderPen,
        top: borderPen,
        bottom: borderPen,
      );
      cell.style.cellPadding = PdfPaddings(
        left: i == leftAlignIndex ? 6 : 3,
        right: 3,
        top: 4,
        bottom: 4,
      );
      cell.stringFormat = PdfStringFormat(
        alignment: i == leftAlignIndex
            ? PdfTextAlignment.left
            : PdfTextAlignment.center,
        lineAlignment: PdfVerticalAlignment.middle,
      );
    }
  }

  static void _styleGridTotalRow(
    PdfGridRow row,
    PdfFont boldFont, {
    int? leftAlignIndex,
  }) {
    final bg = PdfColor(225, 242, 247);
    final borderPen = PdfPen(PdfColor(0, 137, 166), width: 0.8);

    for (var i = 0; i < row.cells.count; i++) {
      final cell = row.cells[i];
      cell.style.backgroundBrush = PdfSolidBrush(bg);
      cell.style.textBrush = PdfSolidBrush(PdfColor(10, 28, 42));
      cell.style.font = boldFont;
      cell.style.borders = PdfBorders(
        left: borderPen,
        right: borderPen,
        top: borderPen,
        bottom: borderPen,
      );
      cell.style.cellPadding = PdfPaddings(
        left: i == leftAlignIndex ? 6 : 3,
        right: 3,
        top: 5,
        bottom: 5,
      );
      cell.stringFormat = PdfStringFormat(
        alignment: i == leftAlignIndex
            ? PdfTextAlignment.left
            : PdfTextAlignment.center,
        lineAlignment: PdfVerticalAlignment.middle,
      );
    }
  }

  static void _drawFooters(PdfDocument document, DateTime now) {
    final footerFont = PdfStandardFont(PdfFontFamily.helvetica, 8);
    final brush = PdfSolidBrush(PdfColor(110, 125, 138));

    for (var i = 0; i < document.pages.count; i++) {
      final p = document.pages[i];
      final size = p.getClientSize();
      p.graphics.drawLine(
        PdfPen(PdfColor(218, 226, 234)),
        Offset(0, size.height - 16),
        Offset(size.width, size.height - 16),
      );
      p.graphics.drawString(
        _clean(
          'Application Planning CHI • Document généré hors-ligne le ${_formatDate(now)}',
        ),
        footerFont,
        brush: brush,
        bounds: Rect.fromLTWH(0, size.height - 12, size.width * 0.75, 12),
      );
      p.graphics.drawString(
        'Page ${i + 1} / ${document.pages.count}',
        footerFont,
        brush: brush,
        format: PdfStringFormat(alignment: PdfTextAlignment.right),
        bounds: Rect.fromLTWH(
          size.width * 0.75,
          size.height - 12,
          size.width * 0.25,
          12,
        ),
      );
    }
  }
}

class _KpiBoxItem {
  final String label;
  final String value;
  final PdfColor accent;

  const _KpiBoxItem({
    required this.label,
    required this.value,
    required this.accent,
  });
}
