import 'dart:io';
import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../constants/app_constants.dart';
import 'positioned_planning_parser.dart';

/// Résultat d'un import de planning (PDF ou OCR).
class PlanningParseResult {
  /// agent -> jours travaillés (numéros de jour du mois)
  final Map<String, List<int>> agentShifts;

  /// agent -> { jour: 'CA' | 'CET' | 'CFR' }
  final Map<String, Map<int, String>> agentVacations;

  /// Mois détecté (null si le titre du document est illisible).
  final int? year;
  final int? month;

  final int totalDays;

  /// Avertissements de fiabilité, à afficher dans l'aperçu.
  final List<String> warnings;

  /// Nombre de cellules lues par agent (permet de repérer les lignes tronquées).
  final Map<String, int> tokenCounts;

  final String rawText;

  /// Coordonnées OCR conservées pour réanalyser si l'utilisateur choisit le mois.
  /// Null pour un PDF avec texte ; une liste vide signifie que l'OCR n'a rien lu.
  final List<List<PlanningOcrWord>>? ocrPages;

  /// Cases réellement reconnues par leurs coordonnées (les absentes sont inconnues).
  final Map<String, Map<int, String>> dayCodes;

  PlanningParseResult({
    required this.agentShifts,
    required this.agentVacations,
    required this.year,
    required this.month,
    required this.totalDays,
    required this.warnings,
    required this.tokenCounts,
    required this.rawText,
    this.ocrPages,
    this.dayCodes = const {},
  });

  bool get monthDetected => year != null && month != null;
  bool get isOcr => ocrPages != null;

  /// Vrai si au moins une ligne du planning n'a pas le bon nombre de cellules :
  /// dans ce cas les jours peuvent être décalés, la validation doit être
  /// explicitement confirmée par l'utilisateur.
  bool get hasReliabilityIssue => warnings.isNotEmpty;

  PlanningParseResult copyWith({
    int? year,
    int? month,
    int? totalDays,
    List<String>? warnings,
  }) {
    return PlanningParseResult(
      agentShifts: agentShifts,
      agentVacations: agentVacations,
      year: year ?? this.year,
      month: month ?? this.month,
      totalDays: totalDays ?? this.totalDays,
      warnings: warnings ?? this.warnings,
      tokenCounts: tokenCounts,
      rawText: rawText,
      ocrPages: ocrPages,
      dayCodes: dayCodes,
    );
  }
}

/// Extraction et analyse d'un planning d'équipe (PDF ou texte OCR).
///
/// Le format analysé est une grille : une ligne par agent, une cellule par jour
/// contenant un code (`N`, `RH`, `R`, `CA`, `CET`, `CFR`, `F`, `J`, `F EXT`).
///
/// L'OCR utilise les coordonnées des cases quand les en-têtes sont lisibles.
/// La lecture textuelle séquentielle conserve un contrôle du nombre de cases ;
/// dans les deux cas l'utilisateur doit vérifier l'aperçu avant l'import.
class PdfParserService {
  static const List<String> _validCodes = [
    'F_EXT', 'CET', 'CFR', 'RH', 'CA', 'CS', 'FC', 'N', 'R', 'F', 'J',
  ];

  static const List<String> _vacationCodes = ['CA', 'CET', 'CFR'];

  /// Lignes de pied de page / en-tête à ignorer.
  static const List<String> _stopKeywords = [
    'POUR MR', 'POUR M.', 'NOM / PRÉNOM', 'NOM / PRENOM',
    'ÉQUIPE DE NUIT', 'EQUIPE DE NUIT', 'CALENDRIER', 'VACANCES SCOLAIRES',
  ];

  // ===================================================================
  // EXTRACTION
  // ===================================================================

  /// Lit un fichier PDF puis analyse son contenu.
  static Future<PlanningParseResult> parsePlanningPdfFile(File pdfFile) async {
    try {
      final bytes = await pdfFile.readAsBytes();
      return await parsePlanningPdfBytes(bytes);
    } on Exception catch (e) {
      throw Exception('Erreur lors de la lecture du PDF : $e');
    }
  }

  /// Lit un PDF depuis des octets (compatible web / picker).
  static Future<PlanningParseResult> parsePlanningPdfBytes(Uint8List bytes) async {
    PdfDocument? document;
    try {
      document = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(document);
      final buffer = StringBuffer();

      for (var i = 0; i < document.pages.count; i++) {
        final text = extractor.extractText(startPageIndex: i, endPageIndex: i);
        if (text.isNotEmpty) buffer.writeln(text);
      }

      return parsePlanningText(buffer.toString());
    } on Exception catch (e) {
      throw Exception('Erreur lors de l\'extraction du texte du PDF : $e');
    } finally {
      document?.dispose();
    }
  }

  // ===================================================================
  // PARSING
  // ===================================================================

  /// Analyse un texte (issu d'un PDF ou de l'OCR).
  ///
  /// [forcedYear] / [forcedMonth] permettent de relancer l'analyse après que
  /// l'utilisateur a saisi le mois, quand le titre du document est illisible.
  static PlanningParseResult parsePlanningText(
    String rawText, {
    int? forcedYear,
    int? forcedMonth,
    List<String> knownAgents = AppConstants.knownAgentNames,
    List<List<PlanningOcrWord>>? ocrPages,
  }) {
    // 1. Normalisation (on ne touche PAS aux retours à la ligne : ils
    // délimitent les lignes d'agents)
    var text = rawText.replaceAll('\u00A0', ' ');
    text = text.replaceAll(RegExp(r'F\s+EXT', caseSensitive: false), 'F_EXT');
    text = text.replaceAll(RegExp(r'FEXT', caseSensitive: false), 'F_EXT');

    // 2. Détection du mois / de l'année
    final detected = _detectMonthAndYear(text);
    final year = forcedYear ?? detected.$1;
    final month = forcedMonth ?? detected.$2;
    final totalDays = (year != null && month != null)
        ? DateTime(year, month + 1, 0).day
        : 31;

    final warnings = <String>[];
    if (year == null || month == null) {
      warnings.add(
        'Le mois n\'a pas pu être déterminé automatiquement depuis le document.',
      );
    }

    if (ocrPages != null) {
      final positioned = PositionedPlanningParser.parse(
        ocrPages,
        totalDays: totalDays,
      );
      if (positioned != null) {
        warnings.addAll(positioned.warnings);
        final agentShifts = <String, List<int>>{};
        final agentVacations = <String, Map<int, String>>{};
        final tokenCounts = <String, int>{};
        var hasOtherCodes = false;
        for (final entry in positioned.dayCodes.entries) {
          final days = <int>[];
          final vacations = <int, String>{};
          for (final cell in entry.value.entries) {
            if (cell.value == 'N') days.add(cell.key);
            if (_vacationCodes.contains(cell.value)) {
              vacations[cell.key] = cell.value;
            }
            if (cell.value == 'CS' || cell.value == 'FC') hasOtherCodes = true;
          }
          days.sort();
          agentShifts[entry.key] = days;
          if (vacations.isNotEmpty) agentVacations[entry.key] = vacations;
          tokenCounts[entry.key] = entry.value.length;
        }
        if (hasOtherCodes) {
          warnings.add(
            'Certains codes (CS ou FC) ne sont pas importés comme congés. '
            'Vérifiez-les sur le document.',
          );
        }
        return PlanningParseResult(
          agentShifts: agentShifts,
          agentVacations: agentVacations,
          year: year,
          month: month,
          totalDays: totalDays,
          warnings: warnings,
          tokenCounts: tokenCounts,
          rawText: rawText,
          ocrPages: ocrPages,
          dayCodes: positioned.dayCodes,
        );
      }
      warnings.add(
        'Les colonnes n\'ont pas pu être repérées. Les dates proposées peuvent '
        'être décalées : vérifiez tous les jours avant de les enregistrer.',
      );
      if (ocrPages.length > 1) {
        warnings.add(
          'Plusieurs pages ont été lues. Vérifiez qu’elles concernent toutes '
          'le même mois ; importez les mois séparément.',
        );
      }
    }

    // 3. Analyse ligne par ligne
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final agentRawTokens = <String, List<String>>{};
    String? currentAgent;

    for (final line in lines) {
      final cleanLine = line.replaceAll(RegExp(r'\s+'), ' ').trim();
      final upperLine = cleanLine.toUpperCase();

      if (_isIgnoredLine(upperLine)) {
        currentAgent = null;
        continue;
      }

      // a) ligne commençant par un agent connu
      final knownMatch = _matchKnownAgent(cleanLine, upperLine, knownAgents);
      if (knownMatch != null) {
        currentAgent = knownMatch.key;
        agentRawTokens.putIfAbsent(currentAgent, () => []);
        agentRawTokens[currentAgent]!.addAll(knownMatch.value);
        continue;
      }

      // b) ligne d'en-tête (D01 L02 M03 ..., S45, Nov ...) -> ignorée
      if (_isHeaderLine(upperLine)) continue;

      // c) agent inconnu (équipe différente) : détection générique.
      //    Doit passer AVANT la logique de continuation, sinon la ligne d'un
      //    second agent inconnu serait ajoutée aux jetons du précédent.
      final genericMatch = _matchUnknownAgent(cleanLine);
      if (genericMatch != null) {
        currentAgent = genericMatch.key;
        agentRawTokens
            .putIfAbsent(currentAgent, () => [])
            .addAll(genericMatch.value);
        continue;
      }

      // d) continuation de la ligne de l'agent courant
      if (currentAgent != null) {
        final tokens = _tokenize(cleanLine);
        if (tokens.isNotEmpty) agentRawTokens[currentAgent]!.addAll(tokens);
      }
    }

    if (agentRawTokens.values.any(
      (tokens) => tokens.contains('CS') || tokens.contains('FC'),
    )) {
      warnings.add(
        'Certains codes (CS ou FC) ne sont pas importés comme congés. '
        'Vérifiez-les sur le document.',
      );
    }

    // 4. Conversion jetons -> jours
    final agentShifts = <String, List<int>>{};
    final agentVacations = <String, Map<int, String>>{};
    final tokenCounts = <String, int>{};

    agentRawTokens.forEach((agent, tokens) {
      tokenCounts[agent] = tokens.length;

      if (tokens.isEmpty) return;

      if (tokens.length < totalDays) {
        warnings.add(
          '$agent : seulement ${tokens.length} cellules lues sur $totalDays. '
          'Les jours de cette ligne peuvent être décalés.',
        );
      } else if (tokens.length == totalDays + 1) {
        warnings.add(
          '$agent : ${tokens.length} cellules lues pour $totalDays jours '
          '(une cellule en trop en fin de ligne).',
        );
      } else if (tokens.length > totalDays + 1) {
        warnings.add(
          '$agent : ${tokens.length} cellules lues pour $totalDays jours. '
          'Le document contient peut-être plusieurs mois.',
        );
      }

      final monthTokens = tokens.take(totalDays).toList();
      final workingDays = <int>[];
      final vacationDays = <int, String>{};

      for (var i = 0; i < monthTokens.length; i++) {
        final code = monthTokens[i];
        if (code == 'N') {
          workingDays.add(i + 1);
        } else if (_vacationCodes.contains(code)) {
          vacationDays[i + 1] = code;
        }
      }

      agentShifts[agent] = workingDays;
      if (vacationDays.isNotEmpty) agentVacations[agent] = vacationDays;
    });

    if (agentShifts.isEmpty) {
      warnings.add('Aucun agent n\'a été détecté dans le document.');
    }

    return PlanningParseResult(
      agentShifts: agentShifts,
      agentVacations: agentVacations,
      year: year,
      month: month,
      totalDays: totalDays,
      warnings: warnings,
      tokenCounts: tokenCounts,
      rawText: rawText,
      ocrPages: ocrPages,
    );
  }

  /// Découpe une suite de codes collés (ex: "NRHRHCA") en jetons valides.
  static List<String> _tokenize(String value) {
    final result = <String>[];
    var current = value.trim().toUpperCase();

    while (current.isNotEmpty) {
      current = current.trimLeft();
      if (current.isEmpty) break;

      var matched = false;
      for (final code in _validCodes) {
        if (current.startsWith(code)) {
          result.add(code);
          current = current.substring(code.length);
          matched = true;
          break;
        }
      }
      if (!matched) {
        // - les séparateurs / caractères parasites sont sautés
        // - un chiffre isolé (n° de jour) ou toute autre lettre aussi
        current = current.substring(1);
      }
    }
    return result;
  }

  static bool _isIgnoredLine(String upperLine) {
    for (final keyword in _stopKeywords) {
      if (upperLine.contains(keyword)) return true;
    }
    return false;
  }

  /// En-têtes de colonnes : "D01 L02 M03 ...", "S45", "Nov", "NOVEMBRE 2026"...
  static bool _isHeaderLine(String upperLine) {
    if (RegExp(r'^[DMLJVS]\d{2}\b').hasMatch(upperLine)) return true;
    if (RegExp(r'^S\d{2}$').hasMatch(upperLine)) return true;
    // ligne composée uniquement de mois abrégés / n° de semaine
    if (RegExp(r'^(NOV|OCT|SEP|DEC|JAN|FEV|MAR|AVR|MAI|JUIN|JUIL|AOU|S\d{2})(\s|$)')
        .hasMatch(upperLine)) {
      return true;
    }
    // une année seule
    if (RegExp(r'^20\d{2}$').hasMatch(upperLine)) return true;
    return false;
  }

  static MapEntry<String, List<String>>? _matchKnownAgent(
    String cleanLine,
    String upperLine,
    List<String> knownAgents,
  ) {
    for (final agent in knownAgents) {
      if (upperLine == agent) {
        return MapEntry(agent, const <String>[]);
      }
      if (upperLine.startsWith('$agent ') || upperLine.startsWith('$agent\t')) {
        final remaining = cleanLine.substring(agent.length).trim();
        return MapEntry(agent, _tokenize(remaining));
      }
    }
    return null;
  }

  /// Détection d'un agent absent de la liste connue : la ligne doit commencer
  /// par un nom en majuscules puis contenir au moins 5 codes.
  static MapEntry<String, List<String>>? _matchUnknownAgent(String cleanLine) {
    final parts = cleanLine.split(' ');
    if (parts.length < 3) return null;

    // Nom : 1 à 3 mots majuscules d'au moins 3 lettres, jamais un code de garde
    // (sinon une ligne de continuation "R R RH RH ..." serait prise pour un
    // agent nommé "R R RH").
    final nameWords = <String>[];
    for (final part in parts.take(3)) {
      final isNameWord = RegExp(r"^[A-ZÀ-Ý][A-ZÀ-Ý'\-]{2,}$").hasMatch(part) &&
          !_validCodes.contains(part);
      if (!isNameWord) break;
      nameWords.add(part);
    }
    if (nameWords.isEmpty) return null;

    final parts2 = parts.skip(nameWords.length).toList();
    if (parts2.length < 2) return null;

    final name = nameWords.join(' ');
    final rest = parts2.join(' ');
    final tokens = _tokenize(rest);
    // Une ligne de planning contient au moins 2 codes ; un nom seul ("DUPONT")
    // ou un titre ("NOVEMBRE 2026") n'en produit aucun.
    if (tokens.length < 2) return null;

    final strong = tokens.where((t) => t == 'N' || t == 'RH' || t == 'R').length;
    if (strong < 1) return null;

    return MapEntry(name, tokens);
  }

  /// Détecte le mois et l'année dans le texte. Renvoie `(null, null)` si le
  /// document ne les contient pas : il ne faut **jamais** inventer un mois.
  static (int?, int?) _detectMonthAndYear(String text) {
    final upperText = text.toUpperCase();

    int? year;
    final yearMatch = RegExp(r'\b(20\d{2})\b').firstMatch(upperText);
    if (yearMatch != null) {
      year = int.parse(yearMatch.group(1)!);
    }

    const monthsMap = <String, int>{
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

    int? month;
    for (final entry in monthsMap.entries) {
      if (RegExp('\\b${entry.key}\\b').hasMatch(upperText)) {
        month = entry.value;
        break;
      }
    }

    // Une année sans mois (ou l'inverse) n'est pas exploitable.
    if (year == null || month == null) return (null, null);
    return (year, month);
  }
}
