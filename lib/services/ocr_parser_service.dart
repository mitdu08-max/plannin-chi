import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/models.dart';
import 'pdf_parser_service.dart';

class OcrParserService {
  static final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Parse an image file to extract the team planning grid using OCR
  static Future<Map<String, List<int>>> parsePlanningImage(File imageFile) async {
    final result = await parsePlanningImageFull(imageFile);
    return result.agentShifts;
  }

  /// Parse image with full metadata
  static Future<PlanningParseResult> parsePlanningImageFull(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      final text = recognizedText.text;

      // DEBUG: Print raw OCR text
      print('=== TEXTE BRUT DU FICHIER (OCR) ===');
      print(text);
      print('=== FIN TEXTE BRUT ===');

      return PdfParserService.parsePlanningText(text);
    } catch (e) {
      throw Exception('Erreur lors de l\'OCR: $e');
    }
  }

  /// Parse image from bytes (for web compatibility)
  static Future<Map<String, List<int>>> parsePlanningImageBytes(Uint8List bytes) async {
    try {
      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: const Size(1000, 1000),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.bgra8888,
          bytesPerRow: 1000 * 4,
        ),
      );
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      final text = recognizedText.text;

      // DEBUG: Print raw OCR text
      print('=== TEXTE BRUT DU FICHIER (OCR BYTES) ===');
      print(text);
      print('=== FIN TEXTE BRUT ===');

      return PdfParserService.parsePlanningText(text).agentShifts;
    } catch (e) {
      throw Exception('Erreur lors de l\'OCR: $e');
    }
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
    return PdfParserService.createNightShiftsFromParsedData(
      agentShifts: agentShifts,
      year: year,
      month: month,
      currentUserName: currentUserName,
      teamMembers: teamMembers,
      shiftStartTime: shiftStartTime,
      shiftEndTime: shiftEndTime,
    );
  }

  /// Dispose resources
  static void dispose() {
    _textRecognizer.close();
  }
}