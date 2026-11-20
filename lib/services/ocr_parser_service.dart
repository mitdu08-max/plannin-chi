import 'dart:io';
import 'dart:ui' as ui;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'color_planning_parser.dart';
import 'pdf_parser_service.dart';
import 'positioned_planning_parser.dart';

/// OCR local (ML Kit) combiné à l'analyse colorimétrique de la grille pour
/// les captures d'écran, photos et pages de PDF scannés.
class OcrParserService {
  static TextRecognizer? _textRecognizer;

  static TextRecognizer get _recognizer =>
      _textRecognizer ??= TextRecognizer(script: TextRecognitionScript.latin);

  static Future<PlanningParseResult> parsePlanningImage(File imageFile) =>
      parsePlanningImages([imageFile]);

  static Future<PlanningParseResult> parsePlanningImages(
    List<File> images,
  ) async {
    try {
      final text = StringBuffer();
      final pages = <List<PlanningOcrWord>>[];
      for (final image in images) {
        final prepared = await _prepareImageForOcr(image);
        final scale = prepared.scale;
        try {
          final recognized = await _recognizer.processImage(
            InputImage.fromFile(prepared.file),
          );
          text.writeln(recognized.text);
          final words = <PlanningOcrWord>[];
          for (final block in recognized.blocks) {
            for (final line in block.lines) {
              for (final element in line.elements) {
                final box = element.boundingBox;
                if (element.text.trim().isEmpty ||
                    box.width <= 0 ||
                    box.height <= 0) {
                  continue;
                }
                words.add(
                  PlanningOcrWord(
                    text: element.text,
                    left: box.left / scale,
                    top: box.top / scale,
                    width: box.width / scale,
                    height: box.height / scale,
                  ),
                );
              }
            }
          }
          pages.add(words);
        } finally {
          if (prepared.isTemporary) {
            try {
              if (await prepared.file.exists()) {
                await prepared.file.delete();
              }
            } catch (_) {}
          }
        }
      }

      final rawText = text.toString();
      final detected = PdfParserService.detectMonthAndYear(rawText);
      final totalDays = (detected.$1 != null && detected.$2 != null)
          ? DateTime(detected.$1!, detected.$2! + 1, 0).day
          : 31;

      final colorGrid = await ColorPlanningParser.parseImages(
        images,
        totalDays: totalDays,
        ocrPages: pages,
      );

      return PdfParserService.parsePlanningText(
        rawText,
        ocrPages: pages,
        colorDayCodes: colorGrid?.dayCodes,
      );
    } on Exception catch (e) {
      throw Exception('Erreur lors de l\'OCR : $e');
    }
  }

  /// Agrandit les captures d'écran de faible résolution (ex: 720x1544) avant
  /// le passage dans ML Kit afin que les petits noms d'agents (ex: ARRAGAIN)
  /// et les en-têtes soient lisibles.
  static Future<_PreparedOcrImage> _prepareImageForOcr(File original) async {
    ui.Codec? codec;
    ui.Image? decoded;
    ui.Image? upscaled;
    try {
      final bytes = await original.readAsBytes();
      codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      decoded = frame.image;
      final w = decoded.width;
      final h = decoded.height;

      if (w >= 1600 || w <= 0 || h <= 0) {
        return _PreparedOcrImage(original, 1.0, false);
      }

      final scale = (1800.0 / w).clamp(1.5, 2.5);
      final targetW = (w * scale).round();
      final targetH = (h * scale).round();

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImageRect(
        decoded,
        ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        ui.Rect.fromLTWH(0, 0, targetW.toDouble(), targetH.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
      final picture = recorder.endRecording();
      upscaled = await picture.toImage(targetW, targetH);
      final pngBytes = await upscaled.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (pngBytes == null) {
        return _PreparedOcrImage(original, 1.0, false);
      }

      final tempFile = File(
        '${Directory.systemTemp.path}/ocr_upscaled_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await tempFile.writeAsBytes(pngBytes.buffer.asUint8List(), flush: true);
      return _PreparedOcrImage(tempFile, scale, true);
    } catch (_) {
      return _PreparedOcrImage(original, 1.0, false);
    } finally {
      upscaled?.dispose();
      decoded?.dispose();
      codec?.dispose();
    }
  }

  /// Libère les ressources natives.
  static Future<void> dispose() async {
    await _textRecognizer?.close();
    _textRecognizer = null;
  }
}

class _PreparedOcrImage {
  const _PreparedOcrImage(this.file, this.scale, this.isTemporary);
  final File file;
  final double scale;
  final bool isTemporary;
}
