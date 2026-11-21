package com.planningperso.night_shift_planning

import android.content.ClipData
import android.content.ContentValues
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.provider.MediaStore
import androidx.core.content.FileProvider
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
            "com.planningperso.night_shift_planning/pdf_export"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "savePdfToDownloads" -> {
                    val fileName = call.argument<String>("fileName") ?: "Bilan_Planning_CHI.pdf"
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes == null || bytes.isEmpty()) {
                        result.error("invalid_pdf", "Contenu PDF vide.", null)
                        return@setMethodCallHandler
                    }
                    pdfExecutor.execute {
                        try {
                            val savedLocation = savePdfToDownloads(fileName, bytes)
                            mainHandler.post { result.success(savedLocation) }
                        } catch (error: Exception) {
                            mainHandler.post {
                                result.error("save_failed", error.message ?: "Impossible d'enregistrer le PDF.", null)
                            }
                        }
                    }
                }
                "sharePdf" -> {
                    val fileName = call.argument<String>("fileName") ?: "Bilan_Planning_CHI.pdf"
                    val title = call.argument<String>("title") ?: "Bilan Planning CHI"
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes == null || bytes.isEmpty()) {
                        result.error("invalid_pdf", "Contenu PDF vide.", null)
                        return@setMethodCallHandler
                    }
                    pdfExecutor.execute {
                        try {
                            val shareDir = File(cacheDir, "shared_pdfs")
                            if (!shareDir.exists() && !shareDir.mkdirs()) {
                                throw IllegalStateException("Impossible de créer le dossier de partage.")
                            }
                            shareDir.listFiles()?.forEach { it.delete() }
                            val safeName = fileName.replace(Regex("[^A-Za-z0-9._-]"), "_")
                            val pdfFile = File(shareDir, safeName)
                            pdfFile.writeBytes(bytes)

                            val uri = FileProvider.getUriForFile(
                                this@MainActivity,
                                "${applicationContext.packageName}.fileprovider",
                                pdfFile
                            )
                            mainHandler.post {
                                val sendIntent = Intent(Intent.ACTION_SEND).apply {
                                    type = "application/pdf"
                                    putExtra(Intent.EXTRA_STREAM, uri)
                                    putExtra(Intent.EXTRA_SUBJECT, title)
                                    putExtra(Intent.EXTRA_TEXT, title)
                                    clipData = ClipData.newRawUri(safeName, uri)
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                }
                                startActivity(Intent.createChooser(sendIntent, title))
                                result.success(true)
                            }
                        } catch (error: Exception) {
                            mainHandler.post {
                                result.error("share_failed", error.message ?: "Impossible de partager le PDF.", null)
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
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

    private fun savePdfToDownloads(fileName: String, bytes: ByteArray): String {
        val safeName = fileName.replace(Regex("[^A-Za-z0-9._-]"), "_")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, safeName)
                put(MediaStore.MediaColumns.MIME_TYPE, "application/pdf")
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val resolver = applicationContext.contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Impossible de créer le fichier dans Téléchargements.")
            try {
                resolver.openOutputStream(uri)?.use { out ->
                    out.write(bytes)
                } ?: throw IllegalStateException("Flux d'écriture indisponible.")
                val doneValues = ContentValues().apply {
                    put(MediaStore.MediaColumns.IS_PENDING, 0)
                }
                resolver.update(uri, doneValues, null, null)
                return "Téléchargements/$safeName"
            } catch (e: Exception) {
                resolver.delete(uri, null, null)
                throw e
            }
        } else {
            val dir = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS) ?: filesDir
            val outFile = File(dir, safeName)
            outFile.writeBytes(bytes)
            return outFile.absolutePath
        }
    }

    override fun onDestroy() {
        pdfExecutor.shutdown()
        super.onDestroy()
    }
}
