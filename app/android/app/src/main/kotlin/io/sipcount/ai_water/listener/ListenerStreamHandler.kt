package io.sipcount.ai_water.listener

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Bridge between the AccessibilityService (any thread) and Dart (main thread).
 * Holds at most one EventSink; when none is attached the service falls back to PendingQueue.
 */
object ListenerStreamHandler : EventChannel.StreamHandler {
    @Volatile private var sink: EventChannel.EventSink? = null
    private val main = Handler(Looper.getMainLooper())

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { sink = events }
    override fun onCancel(arguments: Any?) { sink = null }

    /** @return true if delivered live, false if Dart is not listening. */
    fun tryEmit(json: String): Boolean {
        val s = sink ?: return false
        main.post { s.success(json) }
        return true
    }
}
