package com.netvault.app

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.example.wifi_qr_generator/security"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isDeviceSecure" -> {
                    val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                    result.success(keyguardManager.isKeyguardSecure)
                }
                "openGooglePlayStore" -> {
                    val targetPackage = call.argument<String>("packageName") ?: packageName
                    val success = openGooglePlay(targetPackage)
                    result.success(success)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun openGooglePlay(targetPackage: String): Boolean {
        val playStorePackage = "com.android.vending"

        // 1. Check if Google Play Store app is installed
        val isPlayStoreInstalled = try {
            packageManager.getPackageInfo(playStorePackage, 0)
            true
        } catch (e: Exception) {
            false
        }

        if (isPlayStoreInstalled) {
            try {
                val marketIntent = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$targetPackage")).apply {
                    setPackage(playStorePackage)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(marketIntent)
                return true
            } catch (e: Exception) {
                try {
                    val webIntent = Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=$targetPackage")).apply {
                        setPackage(playStorePackage)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(webIntent)
                    return true
                } catch (e2: Exception) {
                    // Fall through to browser
                }
            }
        }

        // 2. Play Store app not installed (e.g. Huawei device without Play Store).
        // Open directly in a web browser to prevent Huawei AppGallery or other OEM stores from intercepting.
        try {
            val url = "https://play.google.com/store/apps/details?id=$targetPackage"
            val uri = Uri.parse(url)

            // Resolve an actual web browser component so Huawei AppGallery cannot intercept
            val testBrowserIntent = Intent(Intent.ACTION_VIEW, Uri.parse("https://www.google.com"))
            val resolveInfo = packageManager.resolveActivity(testBrowserIntent, PackageManager.MATCH_DEFAULT_ONLY)
            val browserPackage = resolveInfo?.activityInfo?.packageName

            val browserIntent = Intent(Intent.ACTION_VIEW, uri).apply {
                addCategory(Intent.CATEGORY_BROWSABLE)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                if (browserPackage != null && 
                    browserPackage != "android" && 
                    !browserPackage.contains("market") && 
                    !browserPackage.contains("appmarket")) {
                    setPackage(browserPackage)
                }
            }
            startActivity(browserIntent)
            return true
        } catch (e: Exception) {
            try {
                val genericIntent = Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=$targetPackage")).apply {
                    addCategory(Intent.CATEGORY_BROWSABLE)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(genericIntent)
                return true
            } catch (e2: Exception) {
                return false
            }
        }
    }
}
