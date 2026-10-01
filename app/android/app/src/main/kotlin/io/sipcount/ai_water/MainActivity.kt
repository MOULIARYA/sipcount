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
import io.sipcount.ai_water.probe.NetworkProbe
import io.sipcount.ai_water.probe.ProbeService

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

        /* Spike channel (I-22). Asks whether a phone can see an individual prompt from per-app
           byte counters alone — if it can, the whole VpnService design becomes unnecessary. */
        MethodChannel(messenger, "ai_water/probe").setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> result.success(NetworkProbe.hasPermission(applicationContext))
                "openUsageAccess" -> {
                    startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(null)
                }
                "apps" -> result.success(NetworkProbe.installedApps(applicationContext))
                // Sampling lives in a foreground service: the whole run happens while this app is
                // backgrounded, and a cached process gets frozen.
                "start" -> {
                    if (NetworkProbe.hasPermission(applicationContext)) {
                        ProbeService.start(applicationContext); result.success(true)
                    } else result.success(false)
                }
                "stop" -> { ProbeService.stop(applicationContext); result.success(null) }
                "status" -> result.success(mapOf(
                    "running" to NetworkProbe.isRunning(),
                    "samples" to NetworkProbe.count(),
                    "capped" to NetworkProbe.isCapped()))
                "dump" -> result.success(NetworkProbe.dump())
                else -> result.notImplemented()
            }
        }
    }

    private fun isServiceEnabled(): Boolean {
        val am = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        return am.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
            .any { it.resolveInfo.serviceInfo.packageName == packageName }
    }
}
