package com.planningperso.night_shift_planning

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sqrt

class MainActivity : FlutterActivity() {
    private val pdfExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.planningperso.night_shift_planning/pdf_ocr"
        ).setMethodCallHandler { call, result ->
            if (call.method != "renderPages") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val path = call.argument<String>("path")
            if (path.isNullOrBlank()) {
                result.error("invalid_pdf", "Fichier PDF inaccessible.", null)
                return@setMethodCallHandler
            }
            pdfExecutor.execute {
                val files = mutableListOf<File>()
                try {
                    val tempDir = File(cacheDir, "planning_pdf_ocr")
                    if (!tempDir.exists() && !tempDir.mkdirs()) {
                        throw IllegalStateException("Impossible de créer le dossier temporaire.")
                    }
                    // En cas d'interruption précédente, ne pas garder de copie
                    // nominative au-delà du prochain import.
                    tempDir.listFiles()?.forEach { it.delete() }
                    ParcelFileDescriptor.open(File(path), ParcelFileDescriptor.MODE_READ_ONLY).use { descriptor ->
                        PdfRenderer(descriptor).use { renderer ->
                            require(renderer.pageCount in 1..10) {
                                "Le PDF doit contenir entre 1 et 10 pages."
                            }
                            for (index in 0 until renderer.pageCount) {
                                renderer.openPage(index).use { page ->
                                    // Garder une image lisible sans allouer plus
                                    // d'environ 8 millions de pixels par page.
                                    val area = page.width.toDouble() * page.height.toDouble()
                                    require(area > 0) { "Dimensions de page invalides." }
                                    val scale = min(
                                        3600.0 / max(page.width, page.height),
                                        sqrt(8_000_000.0 / area)
                                    )
                                    val width = max(1, (page.width * scale).roundToInt())
                                    val height = max(1, (page.height * scale).roundToInt())
                                    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                                    try {
                                        bitmap.eraseColor(Color.WHITE)
                                        page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                                        val file = File.createTempFile("page_", ".png", tempDir)
                                        files.add(file)
                                        file.outputStream().use { output ->
                                            check(bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)) {
                                                "Impossible d'enregistrer une page temporaire."
                                            }
                                        }
                                    } finally {
                                        bitmap.recycle()
                                    }
                                }
                            }
                        }
                    }
                    mainHandler.post { result.success(files.map { it.absolutePath }) }
                } catch (error: OutOfMemoryError) {
                    files.forEach { it.delete() }
                    mainHandler.post {
                        result.error(
                            "pdf_out_of_memory",
                            "Mémoire insuffisante pour lire ce PDF. Essayez une image du planning ou fermez d'autres applications.",
                            null
                        )
                    }
                } catch (error: Exception) {
                    files.forEach { it.delete() }
                    mainHandler.post {
                        result.error(
                            "pdf_render_failed",
                            "Impossible de lire ce PDF scanné. Vérifiez qu'il n'est pas protégé et qu'il contient au maximum 10 pages.",
                            null
                        )
                    }
                }
            }
        }
    }

    override fun onDestroy() {
        pdfExecutor.shutdown()
        super.onDestroy()
    }
}
