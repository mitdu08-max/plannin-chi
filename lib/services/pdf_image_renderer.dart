import 'dart:io';

import 'package:flutter/services.dart';

/// Rend les pages d'un PDF en images locales pour l'OCR des PDF scannés.
/// Le rendu utilise PdfRenderer sur Android et ne transmet aucun fichier.
class PdfImageRenderer {
  static const _channel = MethodChannel(
    'com.planningperso.night_shift_planning/pdf_ocr',
  );

  static Future<List<File>> renderPages(File pdf) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'La lecture des PDF scannés est actuellement disponible sur Android. '
        'Sur cet appareil, utilisez une image du planning.',
      );
    }
    final paths = await _channel.invokeListMethod<String>('renderPages', {
      'path': pdf.path,
    });
    if (paths == null || paths.isEmpty) {
      throw StateError('Aucune page du PDF n’a pu être lue.');
    }
    return paths.map(File.new).toList();
  }

  /// Ne doit être appelé que sur les fichiers temporaires retournés ci-dessus.
  static Future<void> deleteTemporaryPages(List<File> pages) async {
    for (final page in pages) {
      try {
        if (await page.exists()) await page.delete();
      } on FileSystemException {
        // Android effacera le cache plus tard ; le prochain rendu tentera
        // également de supprimer les pages temporaires restantes.
      }
    }
  }
}
