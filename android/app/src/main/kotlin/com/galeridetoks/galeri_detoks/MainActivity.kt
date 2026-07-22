package com.galeridetoks.galeri_detoks

import android.app.Activity
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Bundle
import android.os.Environment
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val LIFECYCLE_CHANNEL = "com.galeridetoks.app/lifecycle"
    private val MEDIA_CHANNEL = "com.galeridetoks.app/media"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Lifecycle channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LIFECYCLE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "moveTaskToBack" -> {
                    moveTaskToBack(true)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        
        // Media channel - MediaStore tazeleme
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scanMedia" -> {
                    scanMediaStore()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun scanMediaStore() {
        try {
            // DCIM ve Pictures dizinlerini tazele
            val dcimDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM)
            val picturesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
            
            val scanPaths = mutableListOf<String>()
            
            if (dcimDir != null && dcimDir.exists()) {
                scanPaths.add(dcimDir.absolutePath)
                // Alt dizinleri de ekle
                dcimDir.listFiles()?.forEach { file ->
                    if (file.isDirectory) {
                        scanPaths.add(file.absolutePath)
                    }
                }
            }
            
            if (picturesDir != null && picturesDir.exists()) {
                scanPaths.add(picturesDir.absolutePath)
            }
            
            if (scanPaths.isNotEmpty()) {
                MediaScannerConnection.scanFile(
                    this,
                    scanPaths.toTypedArray(),
                    null
                ) { path, uri ->
                    println("MediaStore tarandı: $path -> $uri")
                }
            }
        } catch (e: Exception) {
            println("MediaStore tarama hatası: ${e.message}")
        }
    }
}
