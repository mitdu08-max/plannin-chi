import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/models.dart';

class PlanningParseResult {
  final Map<String, List<int>> agentShifts;
  final Map<String, Map<int, String>> agentVacations; // agent -> { day: 'CA' / 'CET' / 'CFR' }
  final int year;
  final int month;
  final int totalDays;
  final String rawText;

  PlanningParseResult({
    required this.agentShifts,
    required this.agentVacations,
    required this.year,
    required this.month,
    required this.totalDays,
    required this.rawText,
  });
}

class PdfParserService {
  /// Parse a PDF file to extract the team planning grid
  static Future<Map<String, List<int>>> parsePlanningPdf(File pdfFile) async {
    final result = await parsePlanningPdfFull(pdfFile);
    return result.agentShifts;
  }

  /// Parse PDF with full metadata (year, month, agent shifts)
  static Future<PlanningParseResult> parsePlanningPdfFull(File pdfFile) async {
    try {
      final bytes = await pdfFile.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(document);

      final StringBuffer fullTextBuffer = StringBuffer();

      for (int pageIndex = 0; pageIndex < document.pages.count; pageIndex++) {
        final text = extractor.extractText(startPageIndex: pageIndex, endPageIndex: pageIndex);
        if (text.isNotEmpty) {
          fullTextBuffer.writeln(text);
        }
      }

      document.dispose();
      final fullText = fullTextBuffer.toString();

      // DEBUG: Print raw extracted text
      print('=== TEXTE BRUT DU FICHIER (PDF) ===');
      print(fullText);
      print('=== FIN TEXTE BRUT ===');

      return parsePlanningText(fullText);
    } catch (e) {
      throw Exception('Erreur lors de la lecture du PDF: $e');
    }
  }

  /// Parse PDF from bytes (for web compatibility)
  static Future<Map<String, List<int>>> parsePlanningPdfBytes(Uint8List bytes) async {
    try {
      final document = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(document);
      final StringBuffer fullTextBuffer = StringBuffer();

      for (int pageIndex = 0; pageIndex < document.pages.count; pageIndex++) {
        final text = extractor.extractText(startPageIndex: pageIndex, endPageIndex: pageIndex);
        if (text.isNotEmpty) {
          fullTextBuffer.writeln(text);
        }
      }

      document.dispose();
      final fullText = fullTextBuffer.toString();

      // DEBUG: Print raw extracted text
      print('=== TEXTE BRUT DU FICHIER (PDF BYTES) ===');
      print(fullText);
      print('=== FIN TEXTE BRUT ===');

      final result = parsePlanningText(fullText);
      return result.agentShifts;
    } catch (e) {
      throw Exception('Erreur lors de la lecture du PDF: $e');
    }
  }

  /// Universal text parser for both PDF and OCR extracted text
  /// Handles the specific planning format:
  /// - 13 agents with full names (RINAUDO, TETON, PIAZZA, RENFORT 1, LEROY, MONTEILLET, CAUVIERE, LIBAULT, TOUZET, ABDELALIM, ARRAGAIN, MONTREUIL, WICKER)
  /// - Multi-line vertical layout (PDF extractor) and horizontal layout (OCR/tables)
  /// - 28-31 days with codes: N, RH, R, CA, CET, CFR, F, F_EXT, J
  static PlanningParseResult parsePlanningText(String rawText) {
    final Map<String, List<int>> agentShifts = {};

    print('=== DÉBUT PARSING TEXTE ===');
    print('Longueur texte: ${rawText.length}');

    // 1. Detect Year and Month (default to Nov 2026 if not found)
    final detectedDate = _detectMonthAndYear(rawText);
    final year = detectedDate.$1;
    final month = detectedDate.$2;
    final totalDays = DateTime(year, month + 1, 0).day;

    // 2. Normalize text
    String text = rawText.replaceAll('\u00A0', ' ');
    text = text.replaceAll(RegExp(r'F\s+EXT', caseSensitive: false), 'F_EXT');
    text = text.replaceAll(RegExp(r'FEXT', caseSensitive: false), 'F_EXT');

    final knownAgents = [
      'RINAUDO', 'TETON', 'PIAZZA', 'RENFORT 1', 'RENFORT',
      'LEROY', 'MONTEILLET', 'CAUVIERE', 'LIBAULT', 'TOUZET',
      'ABDELALIM', 'ARRAGAIN', 'MONTREUIL', 'WICKER',
    ];

    final validCodes = ['F_EXT', 'CET', 'CFR', 'RH', 'CA', 'N', 'R', 'F', 'J'];
    final vacationCodes = ['CA', 'CET', 'CFR'];

    List<String> tokenizeCodeString(String s) {
      final List<String> result = [];
      String current = s.trim().toUpperCase();
      while (current.isNotEmpty) {
        current = current.trimLeft();
        if (current.isEmpty) break;

        bool matched = false;
        for (final code in validCodes) {
          if (current.startsWith(code)) {
            result.add(code);
            current = current.substring(code.length);
            matched = true;
            break;
          }
        }
        if (!matched) {
          current = current.substring(1);
        }
      }
      return result;
    }

    final stopKeywords = [
      'POUR MR', 'POUR M.', 'NOM / PRÉNOM', 'NOM / PRENOM',
      'ÉQUIPE DE NUIT', 'EQUIPE DE NUIT', 'NOVEMBRE 2026',
      'DÉCEMBRE 2026', 'DECEMBRE 2026', 'CALENDRIER',
    ];

    bool isStopLine(String lineUpper) {
      for (final kw in stopKeywords) {
        if (lineUpper.contains(kw)) return true;
      }
      return false;
    }

    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    String? currentAgent;
    final Map<String, List<String>> agentRawTokens = {};

    for (final line in lines) {
      final cleanLine = line.replaceAll(RegExp(r'\s+'), ' ').trim();
      final upperLine = cleanLine.toUpperCase();

      if (isStopLine(upperLine)) {
        currentAgent = null;
        continue;
      }

      // Check if line matches or starts with a known agent
      String? matchedAgent;
      String remainingAfterAgent = '';

      for (final ka in knownAgents) {
        if (upperLine == ka) {
          matchedAgent = ka;
          remainingAfterAgent = '';
          break;
        } else if (upperLine.startsWith('$ka ') || upperLine.startsWith('$ka\t')) {
          matchedAgent = ka;
          remainingAfterAgent = cleanLine.substring(ka.length).trim();
          break;
        }
      }

      if (matchedAgent != null) {
        currentAgent = matchedAgent;
        if (!agentRawTokens.containsKey(currentAgent)) {
          agentRawTokens[currentAgent] = [];
        }

        if (remainingAfterAgent.isNotEmpty) {
          final tokens = tokenizeCodeString(remainingAfterAgent);
          agentRawTokens[currentAgent]!.addAll(tokens);
        }
        continue;
      }

      // If we are currently collecting tokens for an agent
      if (currentAgent != null) {
        // Skip header lines like D01, L02, S45, etc.
        if (RegExp(r'^[DMLJVS]\d{2}').hasMatch(upperLine) ||
            upperLine.startsWith('NOV') ||
            RegExp(r'^S\d{2}$').hasMatch(upperLine)) {
          continue;
        }

        final tokens = tokenizeCodeString(cleanLine);
        if (tokens.isNotEmpty) {
          agentRawTokens[currentAgent]!.addAll(tokens);
        }
      }
    }

    // Now convert tokens to night shifts (1..totalDays) and vacations
    final Map<String, Map<int, String>> agentVacations = {};
    agentRawTokens.forEach((agent, tokens) {
      final monthTokens = tokens.take(totalDays).toList();
      final List<int> workingDays = [];
      final Map<int, String> vacationDays = {};
      for (int i = 0; i < monthTokens.length; i++) {
        final code = monthTokens[i];
        if (code == 'N') {
          workingDays.add(i + 1);
        } else if (vacationCodes.contains(code)) {
          vacationDays[i + 1] = code;
        }
      }

      if (workingDays.isNotEmpty || monthTokens.length >= 10) {
        agentShifts[agent] = workingDays;
        print('Agent détecté: $agent -> ${workingDays.length} nuits (jours: $workingDays)');
      }
      if (vacationDays.isNotEmpty) {
        agentVacations[agent] = vacationDays;
        print('Agent $agent vacances: $vacationDays');
      }
    });

    print('=== FIN PARSING - ${agentShifts.length} agents trouvés ===');

    return PlanningParseResult(
      agentShifts: agentShifts,
      agentVacations: agentVacations,
      year: year,
      month: month,
      totalDays: totalDays,
      rawText: rawText,
    );
  }

  /// Detect month and year from text (e.g., "NOVEMBRE 2026")
  /// Defaults to November 2026 for this specific planning
  static (int year, int month) _detectMonthAndYear(String text) {
    int year = 2026;
    int month = 11; // November default

    // Detect Year
    final yearMatch = RegExp(r'\b(20\d{2})\b').firstMatch(text);
    if (yearMatch != null) {
      year = int.parse(yearMatch.group(1)!);
    }

    // Detect Month (French names)
    final upperText = text.toUpperCase();
    final monthsMap = {
      'JANVIER': 1,
      'FÉVRIER': 2,
      'FEVRIER': 2,
      'MARS': 3,
      'AVRIL': 4,
      'MAI': 5,
      'JUIN': 6,
      'JUILLET': 7,
      'AOÛT': 8,
      'AOUT': 8,
      'SEPTEMBRE': 9,
      'OCTOBRE': 10,
      'NOVEMBRE': 11,
      'DÉCEMBRE': 12,
      'DECEMBRE': 12,
    };

    for (final entry in monthsMap.entries) {
      if (upperText.contains(entry.key)) {
        month = entry.value;
        break;
      }
    }

    return (year, month);
  }

  /// Create NightShift objects from parsed data
  static List<NightShift> createNightShiftsFromParsedData({
    required Map<String, List<int>> agentShifts,
    required int year,
    required int month,
    required String currentUserName,
    required List<TeamMember> teamMembers,
    required TimeOfDay shiftStartTime,
    required TimeOfDay shiftEndTime,
  }) {
    final shifts = <NightShift>[];

    // Find current user by name (not trigramme)
    final currentUser = teamMembers.firstWhere(
      (m) => m.firstName == currentUserName || m.trigramme == currentUserName,
      orElse: () => teamMembers.first,
    );

    final currentUserDays = agentShifts[currentUser.firstName] ?? agentShifts[currentUser.trigramme] ?? [];

    // For each day the current user works, find colleagues
    for (final day in currentUserDays) {
      final date = DateTime(year, month, day);
      final coWorkerIds = <String>[];

      // Find all other agents working the same day
      for (final entry in agentShifts.entries) {
        final agentName = entry.key;
        if (agentName != currentUser.firstName && agentName != currentUser.trigramme && entry.value.contains(day)) {
          final colleague = teamMembers.firstWhere(
            (m) => m.firstName == agentName || m.trigramme == agentName,
            orElse: () => TeamMember(
              id: agentName,
              firstName: agentName,
              lastName: '',
              trigramme: agentName,
            ),
          );
          coWorkerIds.add(colleague.id);
        }
      }

      final shift = NightShift(
        id: '${currentUser.id}_${year}_${month}_$day',
        date: date,
        agentId: currentUser.id,
        agentTrigramme: currentUser.trigramme,
        startTime: shiftStartTime,
        endTime: shiftEndTime,
        isWorking: true,
        coWorkerIds: coWorkerIds,
        isManualOverride: false,
      );

      shifts.add(shift);
    }

    return shifts;
  }
}