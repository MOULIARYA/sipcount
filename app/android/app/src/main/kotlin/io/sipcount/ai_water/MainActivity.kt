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
import io.sipcount.ai_water.usage.UsageHarvester

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

        /* Estimate mode (I-73): minutes in each AI app from the system's usage history. No
           Accessibility permission, so it coexists with banking apps (I-72). The Dart side asks
           for a window and clips what comes back, so it is idempotent. */
        MethodChannel(messenger, "ai_water/usage").setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> result.success(UsageHarvester.hasPermission(applicationContext))
                "openSettings" -> {
                    startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(null)
                }
                "sessions" -> {
                    val since = call.argument<Number>("since_ms")?.toLong()
                    val until = call.argument<Number>("until_ms")?.toLong()
                    if (since == null || until == null) result.error("args", "since_ms and until_ms required", null)
                    else result.success(UsageHarvester.sessionsJson(applicationContext, since, until))
                }
                else -> result.notImplemented()
            }
        }

        /* The probe channel that lived here is gone. Its question — can per-app byte counters
           resolve a single prompt without a VpnService — was answered on a real phone on
           2026-10-06, and the answer is no (I-60). */
    }

    private fun isServiceEnabled(): Boolean {
        val am = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        return am.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
            .any { it.resolveInfo.serviceInfo.packageName == packageName }
    }
}
