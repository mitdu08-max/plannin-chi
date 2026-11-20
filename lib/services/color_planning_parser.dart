import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'positioned_planning_parser.dart';

/// Résultat de l'analyse colorimétrique d'une grille de planning CHI.
class ColorPlanningGridResult {
  const ColorPlanningGridResult({
    required this.dayCodes,
    required this.detectedColumns,
  });

  /// agent -> { jour (1..totalDays) : code ('N', 'R', 'RH', 'CA', 'F', 'FC') }
  final Map<String, Map<int, String>> dayCodes;

  /// Nombre total de colonnes détectées dans la grille colorée.
  final int detectedColumns;
}

/// Analyseur de grille de planning par détection colorimétrique des cellules.
///
/// Sur les captures d'écran de téléphone (ex: 720x1544 en mode portrait) ou les
/// PDF scannés du planning CHI, les lettres ('N', 'R', 'RH', 'CA') à l'intérieur
/// des cellules ne font parfois que 4 à 6 pixels de haut et ne sont pas lues par
/// ML Kit OCR. En revanche, chaque code possède une couleur de fond standardisée :
/// - Bleu vif    -> 'N'  (Nuit travaillée)
/// - Orange      -> 'R'  (Repos)
/// - Gris-bleu   -> 'RH' (Repos hebdomadaire)
/// - Vert        -> 'CA' (Congés)
/// - Rose/Rouge  -> 'F'  (Formation)
/// - Jaune       -> 'FC' (Formation continue)
class ColorPlanningParser {
  /// Ordre standard des 12 lignes du planning CHI (format avec SSIAP 1).
  static const List<String> chi12RowsOrder = [
    'RINAUDO',
    'LEROY',
    'SSIAP 1',
    'PIAZZA',
    'TETON',
    'MONTEILLET',
    'CAUVIERE',
    'LIBAULT',
    'TOUZET',
    'WICKER',
    'ABDELALIM',
    'ARRAGAIN',
  ];

  /// Ordre standard des 13 lignes du planning CHI (format avec RENFORT 1 et MONTREUIL).
  static const List<String> chi13RowsOrder = [
    'RINAUDO',
    'TETON',
    'PIAZZA',
    'RENFORT 1',
    'LEROY',
    'MONTEILLET',
    'CAUVIERE',
    'LIBAULT',
    'TOUZET',
    'ABDELALIM',
    'ARRAGAIN',
    'MONTREUIL',
    'WICKER',
  ];

  /// Tous les noms d'agents connus pour la reconnaissance floue (fuzzy matching).
  static const List<String> allKnownChiAgents = [
    'RINAUDO',
    'LEROY',
    'SSIAP 1',
    'RENFORT 1',
    'RENFORT',
    'PIAZZA',
    'TETON',
    'MONTEILLET',
    'CAUVIERE',
    'LIBAULT',
    'TOUZET',
    'WICKER',
    'ABDELALIM',
    'ARRAGAIN',
    'MONTREUIL',
  ];

  /// Analyse une liste d'images (captures d'écran ou pages de PDF rendues).
  static Future<ColorPlanningGridResult?> parseImages(
    List<File> images, {
    required int totalDays,
    List<List<PlanningOcrWord>>? ocrPages,
  }) async {
    final combined = <String, Map<int, String>>{};
    var detectedCols = 0;

    for (var i = 0; i < images.length; i++) {
      final file = images[i];
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      final ocrWords = (ocrPages != null && i < ocrPages.length)
          ? ocrPages[i]
          : const <PlanningOcrWord>[];
      final pageResult = await parseImageBytes(
        bytes,
        totalDays: totalDays,
        ocrWords: ocrWords,
      );
      if (pageResult != null) {
        detectedCols = pageResult.detectedColumns;
        for (final entry in pageResult.dayCodes.entries) {
          combined[entry.key] = entry.value;
        }
      }
    }

    if (combined.isEmpty) return null;
    return ColorPlanningGridResult(
      dayCodes: combined,
      detectedColumns: detectedCols,
    );
  }

  /// Analyse les octets d'une image (PNG / JPEG) pour extraire la grille colorée.
  static Future<ColorPlanningGridResult?> parseImageBytes(
    Uint8List bytes, {
    required int totalDays,
    List<PlanningOcrWord> ocrWords = const [],
  }) async {
    ui.Codec? codec;
    ui.Image? image;
    try {
      codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      image = frame.image;
      final width = image.width;
      final height = image.height;
      if (width < 200 || height < 200) return null;

      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) return null;

      return parseRgbaPixels(
        byteData.buffer.asUint8List(),
        width: width,
        height: height,
        totalDays: totalDays,
        ocrWords: ocrWords,
      );
    } catch (_) {
      return null;
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }

  /// Analyse directe d'un tampon RGBA (permet également les tests unitaires rapides).
  static ColorPlanningGridResult? parseRgbaPixels(
    Uint8List rgba, {
    required int width,
    required int height,
    required int totalDays,
    List<PlanningOcrWord> ocrWords = const [],
  }) {
    // 1. Détection des bandes horizontales colorées (lignes des agents)
    final sampleXs = <int>[
      (width * 0.30).round(),
      (width * 0.40).round(),
      (width * 0.50).round(),
      (width * 0.60).round(),
      (width * 0.70).round(),
      (width * 0.80).round(),
    ];

    final minBandHeight = math.max(3, (height * 0.0022).round());
    final maxBandHeight = math.max(60, (height * 0.05).round());

    final rawBands = <_RowBand>[];
    var inBand = false;
    var bandStart = 0;

    for (var y = 0; y < height; y++) {
      var hits = 0;
      for (final sx in sampleXs) {
        final offset = (y * width + sx) * 4;
        if (_isCellColor(rgba[offset], rgba[offset + 1], rgba[offset + 2])) {
          hits++;
        }
      }
      if (hits >= 3) {
        if (!inBand) {
          inBand = true;
          bandStart = y;
        }
      } else if (inBand) {
        inBand = false;
        final bandH = y - bandStart;
        if (bandH >= minBandHeight && bandH <= maxBandHeight) {
          rawBands.add(_RowBand(bandStart, y - 1));
        }
      }
    }
    if (inBand) {
      final bandH = height - bandStart;
      if (bandH >= minBandHeight && bandH <= maxBandHeight) {
        rawBands.add(_RowBand(bandStart, height - 1));
      }
    }

    // Fusionner les bandes séparées par 1 ou 2 pixels de bruit
    final mergedBands = <_RowBand>[];
    for (final band in rawBands) {
      if (mergedBands.isNotEmpty && band.yStart - mergedBands.last.yEnd <= 2) {
        final prev = mergedBands.removeLast();
        mergedBands.add(_RowBand(prev.yStart, band.yEnd));
      } else {
        mergedBands.add(band);
      }
    }

    // Filtrer pour conserver le groupe régulier de lignes du tableau (au moins 6 agents)
    final rowBands = _selectRegularRowCluster(mergedBands);
    if (rowBands.length < 6) return null;

    // 2. Déterminer les bornes horizontales [xStart .. xEnd] de la grille colorée
    final rowStarts = <int>[];
    final rowEnds = <int>[];
    for (final band in rowBands) {
      final ry = band.centerY;
      int? firstX;
      int? lastX;
      for (var x = 0; x < width; x++) {
        final offset = (ry * width + x) * 4;
        if (_isCellColor(rgba[offset], rgba[offset + 1], rgba[offset + 2])) {
          firstX = x;
          break;
        }
      }
      for (var x = width - 1; x >= 0; x--) {
        final offset = (ry * width + x) * 4;
        if (_isCellColor(rgba[offset], rgba[offset + 1], rgba[offset + 2])) {
          lastX = x;
          break;
        }
      }
      if (firstX != null && lastX != null && lastX - firstX > width * 0.35) {
        rowStarts.add(firstX);
        rowEnds.add(lastX);
      }
    }
    if (rowStarts.length < 6) return null;
    rowStarts.sort();
    rowEnds.sort();
    final xStart = rowStarts[rowStarts.length ~/ 2].toDouble();
    final xEnd = rowEnds[rowEnds.length ~/ 2].toDouble();
    final gridWidth = xEnd - xStart + 1.0;
    if (gridWidth < width * 0.35) return null;

    // 3. Déterminer le nombre exact de colonnes (entre 28 et 33) via l'alignement
    // des transitions de couleurs entre cellules adjacentes.
    final detectedCols = _detectColumnCount(
      rgba,
      width: width,
      rowBands: rowBands,
      xStart: xStart,
      gridWidth: gridWidth,
      totalDays: totalDays,
    );
    final colWidth = gridWidth / detectedCols;

    // 4. Associer chaque ligne à un nom d'agent
    final agentNames = _resolveRowAgentNames(
      rowBands,
      xStart: xStart,
      ocrWords: ocrWords,
    );

    // 5. Classifier chaque cellule (jour 1 .. totalDays) pour chaque agent
    final daysToExtract = math.min(totalDays, detectedCols);
    final dxRadius = math.max(1, (colWidth * 0.08).round());
    final dayCodes = <String, Map<int, String>>{};

    for (var i = 0; i < rowBands.length; i++) {
      final agent = agentNames[i];
      final band = rowBands[i];
      final ry = band.centerY;
      final dyRadius = math.max(1, (band.height * 0.22).round());
      final rowCells = <int, String>{};

      for (var col = 0; col < daysToExtract; col++) {
        final day = col + 1;
        final cx = (xStart + (col + 0.5) * colWidth).round();
        final code = _classifyCell(
          rgba,
          width: width,
          height: height,
          cx: cx,
          cy: ry,
          dxRadius: dxRadius,
          dyRadius: dyRadius,
        );
        rowCells[day] = code;
      }
      dayCodes[agent] = rowCells;
    }

    return ColorPlanningGridResult(
      dayCodes: dayCodes,
      detectedColumns: detectedCols,
    );
  }

  /// Sélectionne le cluster principal de lignes espacées régulièrement.
  static List<_RowBand> _selectRegularRowCluster(List<_RowBand> bands) {
    if (bands.length < 6) return bands;

    final gaps = <int>[];
    for (var i = 1; i < bands.length; i++) {
      gaps.add(bands[i].centerY - bands[i - 1].centerY);
    }
    gaps.sort();
    final medianGap = gaps[gaps.length ~/ 2];
    if (medianGap <= 4) return const [];

    List<_RowBand> bestCluster = const [];
    var currentCluster = <_RowBand>[bands.first];

    for (var i = 1; i < bands.length; i++) {
      final gap = bands[i].centerY - bands[i - 1].centerY;
      if (gap >= medianGap * 0.55 && gap <= medianGap * 1.65) {
        currentCluster.add(bands[i]);
      } else {
        if (currentCluster.length > bestCluster.length) {
          bestCluster = currentCluster;
        }
        currentCluster = <_RowBand>[bands[i]];
      }
    }
    if (currentCluster.length > bestCluster.length) {
      bestCluster = currentCluster;
    }
    return bestCluster;
  }

  /// Détecte le nombre exact de colonnes de la grille en maximisant le score
  /// d'alignement des frontières de colonnes avec les transitions de couleur.
  static int _detectColumnCount(
    Uint8List rgba, {
    required int width,
    required List<_RowBand> rowBands,
    required double xStart,
    required double gridWidth,
    required int totalDays,
  }) {
    final approxCw = gridWidth / 31.0;
    final outerDelta = math.max(2, (approxCw * 0.22).round());
    final innerDelta = math.max(1, (approxCw * 0.07).round());

    var bestCols = totalDays;
    var bestScore = -1;

    // Les tableaux mensuels ont entre 28 et 33 colonnes (ex: 31 jours + 1er jour du mois suivant)
    final minCols = math.max(28, totalDays);
    final maxCols = math.min(34, totalDays + 2);

    for (var nCols = minCols; nCols <= maxCols; nCols++) {
      final cw = gridWidth / nCols;
      var score = 0;

      for (var k = 1; k < nCols; k++) {
        final bx = (xStart + k * cw).round();
        if (bx - outerDelta < 0 || bx + outerDelta >= width) continue;

        for (final band in rowBands) {
          final ry = band.centerY;
          final oLeft = (ry * width + (bx - outerDelta)) * 4;
          final oRight = (ry * width + (bx + outerDelta)) * 4;

          final cl1 = _quickColorClass(
            rgba[oLeft],
            rgba[oLeft + 1],
            rgba[oLeft + 2],
          );
          final cl2 = _quickColorClass(
            rgba[oRight],
            rgba[oRight + 1],
            rgba[oRight + 2],
          );

          if (cl1 != cl2) {
            final oMid1 = (ry * width + (bx - innerDelta)) * 4;
            final oMid2 = (ry * width + (bx + innerDelta)) * 4;
            final cm1 = _quickColorClass(
              rgba[oMid1],
              rgba[oMid1 + 1],
              rgba[oMid1 + 2],
            );
            final cm2 = _quickColorClass(
              rgba[oMid2],
              rgba[oMid2 + 1],
              rgba[oMid2 + 2],
            );
            if (cm1 == cl1 && cm2 == cl2) {
              score += 3;
            } else {
              score += 1;
            }
          }
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestCols = nCols;
      }
    }

    return bestCols;
  }

  /// Associe chaque ligne détectée à son nom d'agent (via OCR + correspondance floue
  /// + ordre standard de l'équipe de nuit CHI en secours).
  static List<String> _resolveRowAgentNames(
    List<_RowBand> rowBands, {
    required double xStart,
    required List<PlanningOcrWord> ocrWords,
  }) {
    final rowCount = rowBands.length;
    final avgGap = rowCount > 1
        ? (rowBands.last.centerY - rowBands.first.centerY) / (rowCount - 1)
        : 20.0;

    final matchedNames = List<String?>.filled(rowCount, null);
    final usedNames = <String>{};

    // 1. Tenter de lire les mots OCR à gauche de chaque ligne
    if (ocrWords.isNotEmpty) {
      for (var i = 0; i < rowCount; i++) {
        final ry = rowBands[i].centerY;
        final rowWords = ocrWords.where((w) {
          return w.centerX < xStart &&
              (w.centerY - ry).abs() <= avgGap * 0.48;
        }).toList()
          ..sort((a, b) => a.left.compareTo(b.left));

        if (rowWords.isEmpty) continue;
        final rawLabel = rowWords.map((w) => w.text.trim()).join(' ').toUpperCase();
        final matched = fuzzyMatchAgentName(rawLabel);
        if (matched != null && !usedNames.contains(matched)) {
          matchedNames[i] = matched;
          usedNames.add(matched);
        }
      }
    }

    // 2. Compléter avec l'ordre standard de l'équipe CHI (12 ou 13 lignes)
    final template = rowCount == 12
        ? chi12RowsOrder
        : rowCount == 13
            ? chi13RowsOrder
            : null;

    if (template != null) {
      for (var i = 0; i < rowCount; i++) {
        if (matchedNames[i] == null) {
          final candidate = template[i];
          if (!usedNames.contains(candidate)) {
            matchedNames[i] = candidate;
            usedNames.add(candidate);
          }
        }
      }
    }

    // 3. Garantir un nom non nul pour toute ligne restante
    final result = <String>[];
    for (var i = 0; i < rowCount; i++) {
      result.add(matchedNames[i] ?? 'AGENT ${i + 1}');
    }
    return result;
  }

  /// Recherche floue (fuzzy match) d'un nom d'agent parmi l'équipe connue.
  /// Tolère les caractères parasites de bordure ('|ARRAGAIN', '1ARRAGAIN')
  /// ou les confusions OCR ('ARRAGA1N', 'ARRAGAN', 'CAUV1ERE').
  static String? fuzzyMatchAgentName(
    String rawText, {
    List<String> candidates = allKnownChiAgents,
  }) {
    var cleaned = rawText
        .toUpperCase()
        .replaceAll('0', 'O')
        .replaceAll('1', 'I')
        .replaceAll('|', '')
        .replaceAll(RegExp(r"[^A-ZÀ-ÖØ-Þ\s]"), '')
        .trim();

    if (cleaned.length < 3) return null;
    if (cleaned.contains('NOM') || cleaned.contains('PRENOM')) return null;

    // Cas particulier SSIAP 1 / RENFORT 1
    if (cleaned.contains('SSIAP')) return 'SSIAP 1';
    if (cleaned.contains('RENFORT')) return 'RENFORT 1';

    // Si une bordure verticale a été lue comme un 'I' ou 'L' initial devant le nom
    for (final candidate in candidates) {
      final normCand = candidate.replaceAll(RegExp(r'[^A-Z]'), '');
      final normClean = cleaned.replaceAll(RegExp(r'[^A-Z]'), '');
      if (normClean == normCand ||
          normClean.contains(normCand) ||
          normCand.contains(normClean)) {
        return candidate;
      }
    }

    // Distance de Levenshtein tolérante (jusqu'à 2 erreurs d'OCR)
    String? bestMatch;
    var bestDistance = 999;
    final normClean = cleaned.replaceAll(RegExp(r'[^A-Z]'), '');

    for (final candidate in candidates) {
      final normCand = candidate.replaceAll(RegExp(r'[^A-Z]'), '');
      if (normCand.isEmpty) continue;
      final dist = _levenshtein(normClean, normCand);
      final maxAllowed = normCand.length >= 7 ? 2 : 1;
      if (dist <= maxAllowed && dist < bestDistance) {
        bestDistance = dist;
        bestMatch = candidate;
      }
    }
    return bestMatch;
  }

  static int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    var v0 = List<int>.generate(t.length + 1, (i) => i);
    var v1 = List<int>.filled(t.length + 1, 0);

    for (var i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (var j = 0; j < t.length; j++) {
        final cost = s[i] == t[j] ? 0 : 1;
        v1[j + 1] = math.min(
          v1[j] + 1,
          math.min(v0[j + 1] + 1, v0[j] + cost),
        );
      }
      final temp = v0;
      v0 = v1;
      v1 = temp;
    }
    return v0[t.length];
  }

  static bool _isCellColor(int r, int g, int b) {
    // Bleu vif (N)
    if ((b - r) > 85 && b > 140) return true;
    // Orange (R)
    if ((r - b) > 65 && r > (g + 25) && r > 140) return true;
    // Vert (CA / CS)
    if (g > (r + 30) && g > (b + 18) && g > 95) return true;
    // Rose / Magenta (F)
    if (r > 150 && g < 90 && b > 65) return true;
    // Jaune (FC)
    if (r > 180 && g > 170 && b < 105) return true;
    // Gris-bleu ardoise (RH)
    if ((b - r) >= 22 &&
        (b - r) <= 85 &&
        b >= 140 &&
        b <= 225 &&
        g >= 120 &&
        r >= 80 &&
        r <= 185 &&
        (b - g) >= 8) {
      return true;
    }
    return false;
  }

  static int _quickColorClass(int r, int g, int b) {
    if (g > (r + 35) && g > (b + 20)) return 1; // CA
    if (r > 160 && g < 85 && b > 70) return 2; // F
    if (r > 180 && g > 170 && b < 100) return 3; // FC
    if (r > (b + 65) && r > (g + 25)) return 4; // R
    if ((b - r) > 95 && b > 160) return 5; // N
    return 6; // RH
  }

  static String _classifyCell(
    Uint8List rgba, {
    required int width,
    required int height,
    required int cx,
    required int cy,
    required int dxRadius,
    required int dyRadius,
  }) {
    var bestSat = -1;
    var bestR = 0;
    var bestG = 0;
    var bestB = 0;

    for (var dx = -dxRadius; dx <= dxRadius; dx++) {
      final x = (cx + dx).clamp(0, width - 1);
      for (var dy = -dyRadius; dy <= dyRadius; dy++) {
        final y = (cy + dy).clamp(0, height - 1);
        final offset = (y * width + x) * 4;
        final r = rgba[offset];
        final g = rgba[offset + 1];
        final b = rgba[offset + 2];
        final maxC = math.max(r, math.max(g, b));
        final minC = math.min(r, math.min(g, b));
        final sat = maxC - minC;
        if (sat > bestSat) {
          bestSat = sat;
          bestR = r;
          bestG = g;
          bestB = b;
        }
      }
    }

    if (bestG > (bestR + 35) && bestG > (bestB + 20)) {
      return 'CA';
    }
    if (bestR > 160 && bestG < 85 && bestB > 70) {
      return 'F';
    }
    if (bestR > 180 && bestG > 170 && bestB < 100) {
      return 'FC';
    }
    if (bestR > (bestB + 65) && bestR > (bestG + 25)) {
      return 'R';
    }
    if ((bestB - bestR) > 95 && bestB > 160) {
      return 'N';
    }
    return 'RH';
  }
}

class _RowBand {
  const _RowBand(this.yStart, this.yEnd);
  final int yStart;
  final int yEnd;

  int get centerY => (yStart + yEnd) ~/ 2;
  int get height => yEnd - yStart + 1;
}
