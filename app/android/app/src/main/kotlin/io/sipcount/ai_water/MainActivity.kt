package io.sipcount.ai_water

import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.view.accessibility.AccessibilityManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.sipcount.ai_water.listener.ListenerStreamHandler
import io.sipcount.ai_water.listener.PendingQueue

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        EventChannel(messenger, "ai_water/prompt_events").setStreamHandler(ListenerStreamHandler)

        MethodChannel(messenger, "ai_water/listener_control").setMethodCallHandler { call, result ->
            when (call.method) {
                "isEnabled" -> result.success(isServiceEnabled())
                "openSettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(null)
                }
                "drainPending" -> result.success(PendingQueue.drain(applicationContext))
                else -> result.notImplemented()
            }
        }

        /* The probe channel that lived here is gone. Its question — can per-app byte counters
           resolve a single prompt without a VpnService — was answered on a real phone on
           2026-10-06, and the answer is no (I-60). The accessibility listener is the sensor. */
    }

    private fun isServiceEnabled(): Boolean {
        val am = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        return am.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
            .any { it.resolveInfo.serviceInfo.packageName == packageName }
    }
}
