import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'pdf_parser_service.dart';
import 'positioned_planning_parser.dart';

/// OCR local (ML Kit) pour les captures, photos et pages de PDF scannés.
/// Les coordonnées des mots sont conservées pour éviter qu'une case illisible
/// décale les dates des cases suivantes.
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
        final recognized = await _recognizer.processImage(
          InputImage.fromFile(image),
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
                  left: box.left,
                  top: box.top,
                  width: box.width,
                  height: box.height,
                ),
              );
            }
          }
        }
        pages.add(words);
      }
      return PdfParserService.parsePlanningText(
        text.toString(),
        ocrPages: pages,
      );
    } on Exception catch (e) {
      throw Exception('Erreur lors de l\'OCR : $e');
    }
  }

  /// Libère les ressources natives.
  static Future<void> dispose() async {
    await _textRecognizer?.close();
    _textRecognizer = null;
  }
}
