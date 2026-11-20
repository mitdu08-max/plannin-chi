import 'dart:math' as math;

/// Un mot reconnu par l'OCR, dans les coordonnées de son image d'origine.
/// Cette classe ne dépend pas de ML Kit pour permettre de tester le repérage
/// des colonnes sans appareil Android et sans données nominatives.
class PlanningOcrWord {
  const PlanningOcrWord({
    required this.text,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final String text;
  final double left;
  final double top;
  final double width;
  final double height;

  double get centerX => left + width / 2;
  double get centerY => top + height / 2;
}

class PositionedPlanningResult {
  const PositionedPlanningResult({
    required this.dayCodes,
    required this.warnings,
  });

  /// Les cases absentes de la carte sont inconnues, et non des jours de repos.
  final Map<String, Map<int, String>> dayCodes;
  final List<String> warnings;
}

/// Reconstitue une grille mensuelle à partir des coordonnées des mots OCR.
///
/// Une case illisible ne décale pas les suivantes. Ce repérage est volontairement
/// prudent : si les en-têtes sont insuffisants ou si deux codes se contredisent,
/// les cases concernées restent inconnues et doivent être vérifiées à la main.
class PositionedPlanningParser {
  static const supportedCodes = <String>{
    'N',
    'R',
    'RH',
    'CA',
    'CET',
    'CFR',
    'F',
    'F_EXT',
    'J',
    'CS',
    'FC',
  };

  static PositionedPlanningResult? parse(
    List<List<PlanningOcrWord>> pages, {
    required int totalDays,
  }) {
    final combined = <String, Map<int, String>>{};
    final conflicts = <String, Set<int>>{};
    final duplicateNames = <String>{};
    final warnings = <String>[];
    var unrecognizedPages = 0;

    for (final page in pages) {
      final grid = _parsePage(page, totalDays);
      if (grid == null) {
        unrecognizedPages++;
        continue;
      }
      duplicateNames.addAll(grid.duplicateNames);
      for (final entry in grid.rows.entries) {
        final target = combined.putIfAbsent(entry.key, () => <int, String>{});
        final agentConflicts = conflicts.putIfAbsent(entry.key, () => <int>{});
        for (final day in grid.conflicts[entry.key] ?? const <int>{}) {
          target.remove(day);
          agentConflicts.add(day);
        }
        for (final cell in entry.value.entries) {
          if (agentConflicts.contains(cell.key)) continue;
          final previous = target[cell.key];
          if (previous != null && previous != cell.value) {
            target.remove(cell.key);
            agentConflicts.add(cell.key);
          } else {
            target[cell.key] = cell.value;
          }
        }
      }
    }

    if (combined.isEmpty) return null;
    if (pages.length > 1) {
      warnings.add(
        'Plusieurs pages ont été lues. Vérifiez qu’elles concernent toutes '
        'le même mois ; importez les mois séparément.',
      );
    }
    if (unrecognizedPages > 0 && pages.length > 1) {
      warnings.add(
        '$unrecognizedPages page(s) n’ont pas pu être analysées comme une '
        'grille. Vérifiez que toutes les lignes du planning sont présentes.',
      );
    }
    if (duplicateNames.isNotEmpty) {
      warnings.add(
        'Plusieurs lignes portent le même nom (${duplicateNames.join(', ')}). '
        'Elles ne peuvent pas être distinguées automatiquement : '
        'l’import de l’équipe peut être incomplet.',
      );
    }
    for (final entry in combined.entries) {
      final missing = totalDays - entry.value.length;
      if (missing > 0) {
        warnings.add(
          '${entry.key} : $missing case(s) non reconnue(s) sur $totalDays. '
          'Elles doivent être vérifiées sur le document.',
        );
      }
      if ((conflicts[entry.key] ?? const <int>{}).isNotEmpty) {
        warnings.add('${entry.key} : certains codes lus sont contradictoires.');
      }
    }
    return PositionedPlanningResult(dayCodes: combined, warnings: warnings);
  }

  static _PageResult? _parsePage(List<PlanningOcrWord> words, int totalDays) {
    final columns = _findColumns(words, totalDays);
    if (columns == null) return null;

    // Les noms sont placés avant la première colonne et sous l'en-tête.
    final labelWords = words.where((word) {
      final label = word.text.trim().toUpperCase();
      final isName = RegExp(
        r"^[A-ZÀ-ÖØ-Þ][A-ZÀ-ÖØ-Þ'’\-]{2,}$",
      ).hasMatch(label);
      final isNumber = RegExp(r'^\d{1,3}$').hasMatch(label);
      return (isName || isNumber) &&
          word.centerX < columns.centers.first - columns.step * 0.40 &&
          word.centerY > columns.headerY + columns.step * 0.70;
    }).toList()..sort((a, b) => a.centerY.compareTo(b.centerY));

    final labelRows = <List<PlanningOcrWord>>[];
    for (final word in labelWords) {
      if (labelRows.isNotEmpty &&
          (word.centerY - _averageY(labelRows.last)).abs() <
              columns.step * 0.36) {
        labelRows.last.add(word);
      } else {
        labelRows.add([word]);
      }
    }

    final results = <String, Map<int, String>>{};
    final rowConflicts = <String, Set<int>>{};
    final duplicateNames = <String>{};
    for (var rowIndex = 0; rowIndex < labelRows.length; rowIndex++) {
      final labelRow = labelRows[rowIndex]
        ..sort((a, b) => a.left.compareTo(b.left));
      final nameParts = labelRow
          .map((word) => word.text.trim().toUpperCase())
          .where((part) => part.isNotEmpty)
          .toList();
      if (!nameParts.any((part) => RegExp(r'[A-ZÀ-ÖØ-Þ]{3}').hasMatch(part))) {
        continue;
      }
      final name = nameParts.join(' ');
      if (nameParts.contains('NOM') || nameParts.contains('PRÉNOM')) continue;

      final rowY = _averageY(labelRow);
      final avgRowHeight = math.max(
        labelRow.map((w) => w.height).reduce(math.max),
        columns.step * 0.6,
      );
      var tolerance = avgRowHeight * 0.90;
      if (rowIndex > 0) {
        tolerance = math.min(
          tolerance,
          (rowY - _averageY(labelRows[rowIndex - 1])).abs() * 0.48,
        );
      }
      if (rowIndex + 1 < labelRows.length) {
        tolerance = math.min(
          tolerance,
          (_averageY(labelRows[rowIndex + 1]) - rowY).abs() * 0.48,
        );
      }

      final cells = <int, String>{};
      final conflicts = <int>{};
      for (final word in words) {
        if ((word.centerY - rowY).abs() > tolerance) {
          continue;
        }
        // Doit se situer dans la zone des colonnes du calendrier
        if (word.centerX < columns.centers.first - columns.step * 0.45) {
          continue;
        }

        final tokens = _tokenizeCellText(word.text);
        if (tokens.isEmpty) continue;

        if (tokens.length == 1) {
          final code = tokens.first;
          final day = columns.dayForX(word.centerX);
          if (day == null || conflicts.contains(day)) continue;
          final previous = cells[day];
          if (previous != null && previous != code) {
            cells.remove(day);
            conflicts.add(day);
          } else {
            cells[day] = code;
          }
        } else {
          // Si l'OCR a regroupé plusieurs cellules adjacentes dans un seul mot
          for (var k = 0; k < tokens.length; k++) {
            final code = tokens[k];
            final tokenX = word.left + (k + 0.5) * (word.width / tokens.length);
            final day = columns.dayForX(tokenX);
            if (day == null || conflicts.contains(day)) continue;
            final previous = cells[day];
            if (previous != null && previous != code) {
              cells.remove(day);
              conflicts.add(day);
            } else {
              cells[day] = code;
            }
          }
        }
      }
      // Écarte les légendes et signatures qui ressemblent à un nom d'agent.
      if (cells.isEmpty) continue;
      final previousRow = results[name];
      if (previousRow != null) {
        // Deux lignes du même nom sur une page sont ambiguës : ne pas fusionner
        // silencieusement leurs dates.
        results[name] = <int, String>{};
        duplicateNames.add(name);
        rowConflicts[name] = {for (var day = 1; day <= totalDays; day++) day};
      } else {
        results[name] = cells;
        rowConflicts[name] = conflicts;
      }
    }
    return results.isEmpty
        ? null
        : _PageResult(results, rowConflicts, duplicateNames);
  }

  static List<String> _tokenizeCellText(String raw) {
    var text = raw.trim().toUpperCase().replaceAll('\u00A0', ' ');
    text = text.replaceAll(RegExp(r'F\s+EXT', caseSensitive: false), 'F_EXT');
    text = text.replaceAll(RegExp(r'FEXT', caseSensitive: false), 'F_EXT');
    text = text.replaceAll(RegExp(r'R\s+H', caseSensitive: false), 'RH');
    text = text.replaceAll(RegExp(r'C\s+A', caseSensitive: false), 'CA');
    text = text.replaceAll(RegExp(r'C\s+ET', caseSensitive: false), 'CET');
    text = text.replaceAll(RegExp(r'C\s+FR', caseSensitive: false), 'CFR');

    // Retirer la ponctuation parasite introduite par l'OCR
    text = text.replaceAll(RegExp(r'[.,;:|!_\-]+'), ' ');

    final tokens = <String>[];
    final parts = text.split(RegExp(r'\s+'));

    for (final part in parts) {
      if (part.isEmpty) continue;

      final normalized = _normalizeCode(part);
      if (normalized != null) {
        tokens.add(normalized);
        continue;
      }

      // Mot contenant plusieurs codes collés (ex: "NRHRH" ou "RRRNN")
      var sub = part;
      while (sub.isNotEmpty) {
        var matched = false;
        for (final code in ['F_EXT', 'CET', 'CFR', 'RH', 'CA', 'CS', 'FC', 'N', 'R', 'F', 'J']) {
          if (sub.startsWith(code)) {
            tokens.add(code);
            sub = sub.substring(code.length);
            matched = true;
            break;
          }
        }
        if (!matched) {
          sub = sub.substring(1);
        }
      }
    }
    return tokens;
  }

  static String? _normalizeCode(String code) {
    if (supportedCodes.contains(code)) return code;
    if (const {
      '10H', '12H', '11H', '20H', '19H', '7H',
      'NUIT', 'GARDE', 'SERVICE', 'POSTE', 'NIGHT', 'G'
    }.contains(code)) {
      return 'N';
    }
    if (const {'REPOS', 'OFF', 'LIBRE', 'MALADIE', 'ABS', 'ABSENCE', 'X', 'P', 'B'}.contains(code)) {
      return 'R';
    }
    if (const {'CONGE', 'CONGÉ', 'VAC', 'VACANCES', 'RTT'}.contains(code)) {
      return 'CA';
    }
    return null;
  }

  static _Columns? _findColumns(List<PlanningOcrWord> words, int totalDays) {
    final candidates = <_DayAnchor>[];

    // Motif tolérant : préfixe jour facultatif (1, 2 ou 3 lettres) + numéro de jour (1 ou 2 chiffres).
    // Supporte : J01, V02, M07, Me01, Mer01, Lu02, Ma03, Di05, D5, 01, 1, etc.
    final dayRegex = RegExp(
      r'^(?:LUN|MAR|MER|JEU|VEN|SAM|DIM|LU|MA|ME|JE|VE|SA|DI|[LMDJVS])?([0-3]?[0-9])$',
    );

    const frenchDayPrefixes = {
      'L', 'LU', 'LUN', 'LUNDI',
      'M', 'MA', 'MAR', 'MARDI',
      'ME', 'MER', 'MERCREDI',
      'J', 'JE', 'JEU', 'JEUDI',
      'V', 'VE', 'VEN', 'VENDREDI',
      'S', 'SA', 'SAM', 'SAMEDI',
      'D', 'DI', 'DIM', 'DIMANCHE',
    };

    for (var i = 0; i < words.length; i++) {
      final word = words[i];
      final value = word.text.trim().toUpperCase().replaceAll('O', '0');

      // 1. Mot unique correspondant au motif du jour
      final match = dayRegex.firstMatch(value);
      if (match != null) {
        final day = int.tryParse(match.group(1)!);
        if (day != null && day >= 1 && day <= totalDays) {
          candidates.add(_DayAnchor(day, word.centerX, word.centerY, word.height));
          continue;
        }
      }

      // 2. Deux mots scindés par l'OCR : [Préfixe jour] suivi de [Numéro du jour]
      // Ex: "ME" puis "01", ou "Mer" puis "1"
      if (frenchDayPrefixes.contains(value) && i + 1 < words.length) {
        final nextWord = words[i + 1];
        final nextVal = nextWord.text.trim().toUpperCase().replaceAll('O', '0');
        final nextMatch = RegExp(r'^([0-3]?[0-9])$').firstMatch(nextVal);
        if (nextMatch != null) {
          final day = int.tryParse(nextMatch.group(1)!);
          final sameY = (word.centerY - nextWord.centerY).abs() <=
              math.max(word.height, nextWord.height) * 1.5;
          final closeX = (nextWord.left - (word.left + word.width)).abs() <=
              math.max(word.width, nextWord.width) * 2.5;
          if (day != null && day >= 1 && day <= totalDays && sameY && closeX) {
            final combinedCenterX = (word.centerX + nextWord.centerX) / 2;
            final combinedCenterY = (word.centerY + nextWord.centerY) / 2;
            final combinedHeight = math.max(word.height, nextWord.height);
            candidates.add(
              _DayAnchor(day, combinedCenterX, combinedCenterY, combinedHeight),
            );
          }
        }
      }
    }
    if (candidates.length < 4) return null;

    List<_DayAnchor> best = [];
    for (final reference in candidates) {
      final sameLine = candidates.where((anchor) {
        final maxHeight = math.max(reference.height, anchor.height);
        return (anchor.y - reference.y).abs() <= math.max(4.0, maxHeight * 1.8);
      }).toList()..sort((a, b) => a.x.compareTo(b.x));
      final increasing = _longestIncreasingDays(sameLine);
      if (increasing.length > best.length ||
          (increasing.length == best.length &&
              increasing.isNotEmpty &&
              best.isNotEmpty &&
              increasing.last.day - increasing.first.day >
                  best.last.day - best.first.day)) {
        best = increasing;
      }
    }
    // Trop peu de points ou une petite portion de mois ne permettent pas de
    // déterminer les colonnes de manière fiable.
    if (best.length < 4 || best.last.day - best.first.day < 3) return null;

    final steps = <double>[];
    for (var i = 1; i < best.length; i++) {
      final dayDiff = best[i].day - best[i - 1].day;
      final step = (best[i].x - best[i - 1].x) / dayDiff;
      if (step <= 0) return null;
      steps.add(step);
    }
    steps.sort();
    final step = steps[steps.length ~/ 2];
    if (step <= 1 ||
        steps.any((value) => value < step * 0.45 || value > step * 2)) {
      return null;
    }

    final centers = <double>[];
    for (var day = 1; day <= totalDays; day++) {
      if (day <= best.first.day) {
        centers.add(best.first.x - (best.first.day - day) * step);
      } else if (day >= best.last.day) {
        centers.add(best.last.x + (day - best.last.day) * step);
      } else {
        final rightIndex = best.indexWhere((anchor) => anchor.day >= day);
        final left = best[rightIndex - 1];
        final right = best[rightIndex];
        final fraction = (day - left.day) / (right.day - left.day);
        centers.add(left.x + (right.x - left.x) * fraction);
      }
    }
    final headerY =
        best.map((anchor) => anchor.y).reduce((a, b) => a + b) / best.length;
    return _Columns(centers, step, headerY);
  }

  static List<_DayAnchor> _longestIncreasingDays(List<_DayAnchor> anchors) {
    if (anchors.isEmpty) return [];
    final lengths = List<int>.filled(anchors.length, 1);
    final previous = List<int>.filled(anchors.length, -1);
    var best = 0;
    for (var i = 0; i < anchors.length; i++) {
      for (var j = 0; j < i; j++) {
        if (anchors[j].day < anchors[i].day && lengths[j] + 1 > lengths[i]) {
          lengths[i] = lengths[j] + 1;
          previous[i] = j;
        }
      }
      if (lengths[i] > lengths[best]) best = i;
    }
    final result = <_DayAnchor>[];
    for (var i = best; i >= 0; i = previous[i]) {
      result.add(anchors[i]);
    }
    return result.reversed.toList();
  }

  static double _averageY(List<PlanningOcrWord> words) =>
      words.map((word) => word.centerY).reduce((a, b) => a + b) / words.length;
}

class _PageResult {
  const _PageResult(this.rows, this.conflicts, this.duplicateNames);
  final Map<String, Map<int, String>> rows;
  final Map<String, Set<int>> conflicts;
  final Set<String> duplicateNames;
}

class _DayAnchor {
  const _DayAnchor(this.day, this.x, this.y, this.height);
  final int day;
  final double x;
  final double y;
  final double height;
}

class _Columns {
  const _Columns(this.centers, this.step, this.headerY);
  final List<double> centers;
  final double step;
  final double headerY;

  int? dayForX(double x) {
    if (x < centers.first - step / 2 || x > centers.last + step / 2)
      return null;
    var nearest = 0;
    var distance = (x - centers.first).abs();
    for (var i = 1; i < centers.length; i++) {
      final candidate = (x - centers[i]).abs();
      if (candidate < distance) {
        distance = candidate;
        nearest = i;
      }
    }
    return nearest + 1;
  }
}
