package com.example.epayload

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val CHANNEL = "epayload/settings"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
			if (call.method == "openBluetoothSettings") {
				try {
					val intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
					intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
					startActivity(intent)
					result.success(null)
				} catch (e: Exception) {
					result.error("ERROR", "Failed to open Bluetooth settings: ${e.message}", null)
				}
			} else {
				result.notImplemented()
			}
		}
	}
}
