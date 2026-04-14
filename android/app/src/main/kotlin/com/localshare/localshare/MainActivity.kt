package com.localshare.localshare

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {

    private val channel = "com.localshare/downloads"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "publishToDownloads" -> {
                        val sourcePath = call.argument<String>("path")
                        val fileName   = call.argument<String>("fileName")
                        if (sourcePath == null || fileName == null) {
                            result.error("INVALID_ARGS", "path and fileName required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val destPath = publishToDownloads(sourcePath, fileName)
                            result.success(destPath)
                        } catch (e: Exception) {
                            result.error("PUBLISH_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun publishToDownloads(sourcePath: String, fileName: String): String {
        val sourceFile = File(sourcePath)
        val subDir = "LocalShare"

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10+ (API 29+): write through MediaStore so the file lands in
            // Downloads/LocalShare/ and is immediately visible in the Files app.
            val resolver = contentResolver
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.RELATIVE_PATH, "Download/$subDir")
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw Exception("MediaStore insert failed")

            resolver.openOutputStream(uri)?.use { out ->
                FileInputStream(sourceFile).use { input -> input.copyTo(out) }
            } ?: throw Exception("Could not open output stream")

            // Mark as complete so it's visible immediately
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)

            // Delete the temp file from app-specific storage
            sourceFile.delete()

            // Return the physical path — DATA is deprecated for querying other
            // apps' files but works fine for entries we just inserted ourselves.
            val path = resolver.query(
                uri,
                arrayOf(MediaStore.Downloads.DATA),
                null, null, null
            )?.use { cursor ->
                if (cursor.moveToFirst()) cursor.getString(0) else null
            }

            // Fallback: construct path from known root + relative path.
            // Note: Environment.DIRECTORY_DOWNLOADS == "Download" on all Android versions.
            path ?: run {
                val base = Environment.getExternalStorageDirectory().absolutePath
                "$base/${Environment.DIRECTORY_DOWNLOADS}/$subDir/$fileName"
            }
        } else {
            // API < 29: write directly to the public Downloads folder
            val downloadsDir = Environment.getExternalStoragePublicDirectory(
                Environment.DIRECTORY_DOWNLOADS
            )
            val destDir = File(downloadsDir, subDir)
            destDir.mkdirs()
            val destFile = uniqueFile(destDir, fileName)
            sourceFile.copyTo(destFile, overwrite = false)
            sourceFile.delete()
            destFile.absolutePath
        }
    }

    /** Mirrors the Dart _uniquePath logic so filenames don't collide. */
    private fun uniqueFile(dir: File, fileName: String): File {
        val dotIdx = fileName.lastIndexOf('.')
        val base = if (dotIdx > 0) fileName.substring(0, dotIdx) else fileName
        val ext  = if (dotIdx > 0) fileName.substring(dotIdx) else ""

        var candidate = File(dir, fileName)
        var count = 1
        while (candidate.exists()) {
            candidate = File(dir, "${base}_$count$ext")
            count++
        }
        return candidate
    }
}
