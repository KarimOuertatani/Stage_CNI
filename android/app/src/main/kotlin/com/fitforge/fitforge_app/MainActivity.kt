package com.fitforge.fitforge_app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Sélecteur de document natif via le Storage Access Framework
 * (ACTION_OPEN_DOCUMENT). Remplace le plugin file_picker, incompatible avec
 * l'Android Gradle Plugin 9. Le fichier choisi est copié dans le cache de l'app
 * et son chemin réel est renvoyé à Flutter, prêt à être uploadé.
 */
class MainActivity : FlutterActivity() {

    private val channelName = "fitforge/document_picker"
    private val pickRequestCode = 0xF11E
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "pickDocument") {
                    if (pendingResult != null) {
                        result.error("in_progress", "Sélection déjà en cours", null)
                        return@setMethodCallHandler
                    }
                    pendingResult = result
                    launchPicker()
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun launchPicker() {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
        }
        try {
            startActivityForResult(intent, pickRequestCode)
        } catch (e: Exception) {
            pendingResult?.error("unavailable", "Aucune application de fichiers", null)
            pendingResult = null
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickRequestCode) return
        val result = pendingResult ?: return
        pendingResult = null

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null) // annulé
            return
        }
        try {
            val info = copyToCache(data.data!!)
            result.success(info)
        } catch (e: Exception) {
            result.error("copy_failed", e.message, null)
        }
    }

    /** Copie le contenu de l'URI dans le cache et renvoie {path, name, size}. */
    private fun copyToCache(uri: Uri): Map<String, Any?> {
        var name = "document"
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val nameIdx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (nameIdx >= 0 && !cursor.isNull(nameIdx)) name = cursor.getString(nameIdx)
            }
        }
        val safeName = name.replace(Regex("[\\\\/:*?\"<>|]"), "_")
        val outFile = File(cacheDir, "${System.currentTimeMillis()}_$safeName")
        contentResolver.openInputStream(uri)?.use { input ->
            outFile.outputStream().use { output -> input.copyTo(output) }
        } ?: throw IllegalStateException("Lecture du fichier impossible")

        return mapOf(
            "path" to outFile.absolutePath,
            "name" to name,
            "size" to outFile.length()
        )
    }
}
