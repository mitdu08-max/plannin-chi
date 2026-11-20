import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:night_shift_planning/services/color_planning_parser.dart';

void main() {
  group('ColorPlanningParser', () {
    test('décode une grille synthétique colorée de 12 agents sur 30 jours', () {
      const width = 600;
      const height = 400;
      final rgba = Uint8List(width * height * 4);
      // Fond blanc
      for (var i = 0; i < rgba.length; i += 4) {
        rgba[i] = 255;
        rgba[i + 1] = 255;
        rgba[i + 2] = 255;
        rgba[i + 3] = 255;
      }

      const xStart = 120;
      const colWidth = 14;
      const totalDays = 30;

      // Dessiner 12 lignes d'agents espacées de 20px (hauteur de bande 8px)
      for (var row = 0; row < 12; row++) {
        final y0 = 60 + row * 20;
        for (var day = 1; day <= totalDays; day++) {
          final x0 = xStart + (day - 1) * colWidth;
          // Alterner les couleurs pour créer des transitions de colonnes nettes
          int r, g, b;
          if ((row + day) % 5 == 0) {
            // Bleu vif -> N
            r = 8;
            g = 128;
            b = 200;
          } else if ((row + day) % 5 == 1) {
            // Orange -> R
            r = 230;
            g = 128;
            b = 56;
          } else if ((row + day) % 5 == 2) {
            // Vert -> CA
            r = 30;
            g = 145;
            b = 65;
          } else {
            // Gris-bleu -> RH
            r = 145;
            g = 178;
            b = 200;
          }

          for (var dy = 0; dy < 8; dy++) {
            for (var dx = 0; dx < colWidth; dx++) {
              final offset = ((y0 + dy) * width + (x0 + dx)) * 4;
              rgba[offset] = r;
              rgba[offset + 1] = g;
              rgba[offset + 2] = b;
              rgba[offset + 3] = 255;
            }
          }
        }
      }

      final result = ColorPlanningParser.parseRgbaPixels(
        rgba,
        width: width,
        height: height,
        totalDays: totalDays,
      );

      expect(result, isNotNull);
      expect(result!.dayCodes.keys, contains('ARRAGAIN'));
      expect(result.dayCodes.keys.length, 12);
      expect(result.dayCodes['ARRAGAIN']!.length, 30);
      // Pour row=11 (ARRAGAIN) :
      // day=1 -> (11+1)%5 = 2 -> CA
      // day=4 -> (11+4)%5 = 0 -> N
      // day=5 -> (11+5)%5 = 1 -> R
      expect(result.dayCodes['ARRAGAIN']![1], 'CA');
      expect(result.dayCodes['ARRAGAIN']![4], 'N');
      expect(result.dayCodes['ARRAGAIN']![5], 'R');
    });

    test('reconnaît ARRAGAIN malgré des erreurs OCR ou bordures', () {
      expect(ColorPlanningParser.fuzzyMatchAgentName('|ARRAGAIN'), 'ARRAGAIN');
      expect(ColorPlanningParser.fuzzyMatchAgentName('1ARRAGAIN'), 'ARRAGAIN');
      expect(ColorPlanningParser.fuzzyMatchAgentName('ARRAGA1N'), 'ARRAGAIN');
      expect(ColorPlanningParser.fuzzyMatchAgentName('ARRAGAN'), 'ARRAGAIN');
      expect(ColorPlanningParser.fuzzyMatchAgentName('CAUV1ERE'), 'CAUVIERE');
      expect(ColorPlanningParser.fuzzyMatchAgentName('MONTE1LLET'), 'MONTEILLET');
    });

    test('décode la capture réelle si présente localement', () async {
      final file = File('WhatsApp Image 2026-10-27 at 23.23.54.jpeg');
      if (!file.existsSync()) return;

      final bytes = await file.readAsBytes();
      final result = await ColorPlanningParser.parseImageBytes(
        bytes,
        totalDays: 31,
      );

      expect(result, isNotNull);
      expect(result!.detectedColumns, 32);
      expect(result.dayCodes.keys, contains('ARRAGAIN'));
      final arragain = result.dayCodes['ARRAGAIN']!;
      // Vérifie les nuits d'ARRAGAIN sur Janvier 2026 :
      // Jours travaillés (N) : 2, 5, 6, 10, 11, 15, 16, 19, 21, 24, 25, 29, 30
      final workingDays = arragain.entries
          .where((e) => e.value == 'N')
          .map((e) => e.key)
          .toList()
        ..sort();
      expect(
        workingDays,
        [2, 5, 6, 10, 11, 15, 16, 19, 21, 24, 25, 29, 30],
      );
    });
  });
}
