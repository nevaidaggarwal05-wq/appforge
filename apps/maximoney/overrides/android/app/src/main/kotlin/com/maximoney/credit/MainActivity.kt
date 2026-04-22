package com.maximoney.credit

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Native bridge for things flutter plugins can't do well.
 *
 * Channel `appforge/native` — stable across every white-label app so
 * the shell's Dart code (`IntentBridgeService`) doesn't need to know
 * the per-app package id. If you fork this to a new app, keep the
 * channel name exactly the same.
 *
 *   launchIntent(url: String) -> Boolean
 *       Parses `intent://…#Intent;…;end` with Intent.parseUri and
 *       fires startActivity. Falls back to browser_fallback_url,
 *       then to Play Store, if the target app isn't installed.
 *       This is what makes GPay / PhonePe / any UPI-app handoff
 *       from Razorpay actually work — url_launcher can't do it.
 *
 *   setSecureFlag(enabled: Boolean) -> null
 *       Toggles FLAG_SECURE. Driven by the admin-panel
 *       `screenshot_block` flag; called once after remote config
 *       loads. Default (no call, no flag set) = screenshots allowed.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "appforge/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "launchIntent" -> {
                        val url = call.argument<String>("url")
                        if (url.isNullOrBlank()) {
                            result.success(false)
                        } else {
                            result.success(launchIntentUri(url))
                        }
                    }
                    "setSecureFlag" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        runOnUiThread {
                            if (enabled) {
                                window.setFlags(
                                    WindowManager.LayoutParams.FLAG_SECURE,
                                    WindowManager.LayoutParams.FLAG_SECURE
                                )
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            }
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Parse an intent:// URL and hand it off to the OS. Handles:
     *   • `scheme=upi` with `package=com.google.android.apps.nbu.paisa.user`
     *     → GPay UPI app
     *   • `scheme=upi` with `package=com.phonepe.app` → PhonePe
     *   • `scheme=upi` with no package → UPI app chooser
     *   • bank deep links, market://, any custom scheme
     *
     * Android's `Intent.parseUri(url, URI_INTENT_SCHEME)` does the
     * real parsing — it reads the path, query, scheme, package, and
     * extras (including S.browser_fallback_url) from the string.
     *
     * We clear `component` and `selector` because Razorpay sometimes
     * ships an intent with a component restriction that doesn't
     * actually exist on the device; clearing lets the package-level
     * resolver pick the right activity.
     */
    private fun launchIntentUri(url: String): Boolean {
        val intent: Intent = try {
            Intent.parseUri(url, Intent.URI_INTENT_SCHEME)
        } catch (e: Exception) {
            return false
        }

        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        intent.component = null
        intent.selector = null

        // Try direct launch first.
        try {
            startActivity(intent)
            return true
        } catch (_: ActivityNotFoundException) {
            // fall through
        } catch (_: SecurityException) {
            // fall through
        }

        // Fallback 1: S.browser_fallback_url — Razorpay always sets
        // this to a Play Store URL or a web checkout URL.
        val fallback = intent.getStringExtra("browser_fallback_url")
        if (!fallback.isNullOrBlank()) {
            try {
                startActivity(
                    Intent(Intent.ACTION_VIEW, Uri.parse(fallback))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
                return true
            } catch (_: Exception) {
                // fall through
            }
        }

        // Fallback 2: open Play Store for the missing package.
        val pkg = intent.`package`
        if (!pkg.isNullOrBlank()) {
            return try {
                startActivity(
                    Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$pkg"))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
                true
            } catch (_: Exception) {
                try {
                    startActivity(
                        Intent(
                            Intent.ACTION_VIEW,
                            Uri.parse("https://play.google.com/store/apps/details?id=$pkg")
                        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                    true
                } catch (_: Exception) {
                    false
                }
            }
        }

        return false
    }
}
