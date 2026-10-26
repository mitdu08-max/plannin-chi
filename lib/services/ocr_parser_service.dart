import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'pdf_parser_service.dart';

/// OCR local (ML Kit) pour les captures d'écran / photos de planning.
///
/// Le texte reconnu est transmis au même analyseur que le PDF.
class OcrParserService {
  static TextRecognizer? _textRecognizer;

  static TextRecognizer get _recognizer => _textRecognizer ??=
      TextRecognizer(script: TextRecognitionScript.latin);

  /// Analyse une image et renvoie le planning détecté.
  static Future<PlanningParseResult> parsePlanningImage(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognized = await _recognizer.processImage(inputImage);
      return PdfParserService.parsePlanningText(recognized.text);
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
