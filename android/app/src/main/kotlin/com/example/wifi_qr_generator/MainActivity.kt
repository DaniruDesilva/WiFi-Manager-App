package com.example.wifi_qr_generator

import android.app.KeyguardManager
import android.content.Context
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.example.wifi_qr_generator/security"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "isDeviceSecure") {
                val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                result.success(keyguardManager.isKeyguardSecure)
            } else {
                result.notImplemented()
            }
        }
    }
}
