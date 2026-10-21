package com.bltr.sossoldi

import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.os.PersistableBundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val biometricVault by lazy { BiometricVault(this) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sossoldi/security")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Blocks screenshots, screen recording and the recents preview.
                    "setSecure" -> {
                        if (call.arguments == true) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(null)
                    }
                    // Marked sensitive so Android 13+ hides it in the copy preview.
                    "copySensitive" -> {
                        val clip = ClipData.newPlainText("Sossoldi", call.arguments as String)
                        clip.description.extras = PersistableBundle().apply {
                            if (Build.VERSION.SDK_INT >= 33) {
                                putBoolean(ClipDescription.EXTRA_IS_SENSITIVE, true)
                            } else {
                                putBoolean("android.content.extra.IS_SENSITIVE", true)
                            }
                        }
                        clipboard().setPrimaryClip(clip)
                        result.success(null)
                    }
                    "clearClipboard" -> {
                        val manager = clipboard()
                        if (Build.VERSION.SDK_INT >= 28) {
                            manager.clearPrimaryClip()
                        } else {
                            manager.setPrimaryClip(ClipData.newPlainText("", ""))
                        }
                        result.success(null)
                    }
                    "bioStatus" -> result.success(biometricVault.status())
                    "bioReset" -> {
                        biometricVault.reset()
                        result.success(null)
                    }
                    "bioEncrypt" -> biometricVault.encrypt(
                        call.argument<ByteArray>("data")!!,
                        call.argument<String>("reason")!!,
                        result,
                    )
                    "bioDecrypt" -> biometricVault.decrypt(
                        call.argument<ByteArray>("iv")!!,
                        call.argument<ByteArray>("ct")!!,
                        call.argument<String>("reason")!!,
                        result,
                    )
                    else -> result.notImplemented()
                }
            }
    }

    private fun clipboard() = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
}
