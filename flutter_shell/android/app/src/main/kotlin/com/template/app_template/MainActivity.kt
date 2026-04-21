package com.template.app_template

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // FLAG_SECURE — block screenshots and hide the app from the
        // recent-apps preview. Controlled client-side only; the backend
        // `features.screenshot_block` flag toggles visual behaviour in
        // the webview but the flag here is always on by design for
        // defence-in-depth.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
    }
}
