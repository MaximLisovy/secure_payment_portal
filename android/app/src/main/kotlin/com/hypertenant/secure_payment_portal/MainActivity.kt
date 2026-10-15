package com.hypertenant.secure_payment_portal

import com.hypertenant.secure_payment_portal.security.SecurityPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/** Wiring only: each native module is an in-app plugin, added here. */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(SecurityPlugin())
    }
}
