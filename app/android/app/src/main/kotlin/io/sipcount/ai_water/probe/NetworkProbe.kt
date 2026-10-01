package io.sipcount.ai_water.probe

import android.app.AppOpsManager
import android.app.usage.NetworkStatsManager
import android.content.Context
import android.net.ConnectivityManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Spike only — not part of the shipping app.
 *
 * The question: can a phone see an individual prompt WITHOUT a VpnService?
 *
 * The September research (SENSING-REVIEW §7) rejected a no-VPN "coarse mode" as not prompt-level,
 * and it was right about what it tested: a byte delta taken when you leave the app tells you only
 * "a session happened". But it never tested polling the per-app counters once a second while the
 * app is in front. A prompt is a small upload followed by a larger streamed download — if that
 * shape survives into the counters at one-second resolution, we never need the tunnel, and with it
 * goes the userspace TCP/IP stack, the battery cost, the Play disclosure video and most of the
 * review risk. Cheap to ask; expensive to assume.
 *
 * Reads only byte totals per app. No packets, no hostnames, no content — it could not see what was
 * typed even if it wanted to.
 */
object NetworkProbe {

    /** The apps worth watching. Anything not installed is skipped rather than failing. */
    private val WATCH = mapOf(
        "com.openai.chatgpt" to "ChatGPT",
        "com.anthropic.claude" to "Claude",
        "com.google.android.apps.bard" to "Gemini"
    )

    private const val INTERVAL_MS = 1_000L
    private const val MAX_SAMPLES = 7200          // two hours at one a second, then it stops growing

    data class Sample(val atMs: Long, val app: String, val rxDelta: Long, val txDelta: Long,
                      val rxTotal: Long, val txTotal: Long)

    private val samples = ArrayList<Sample>()
    private val lastRx = HashMap<String, Long>()
    private val lastTx = HashMap<String, Long>()
    private var handler: Handler? = null
    private var running = false

    fun isRunning(): Boolean = running

    /** Usage access is a special permission the user grants in Settings; we cannot request it inline. */
    fun hasPermission(ctx: Context): Boolean {
        val ops = ctx.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
            ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), ctx.packageName)
        else
            @Suppress("DEPRECATION") ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), ctx.packageName)
        return mode == AppOpsManager.MODE_ALLOWED
    }

    fun installedApps(ctx: Context): List<String> =
        WATCH.filter { uidOf(ctx, it.key) != null }.map { it.value }

    private fun uidOf(ctx: Context, pkg: String): Int? = try {
        ctx.packageManager.getApplicationInfo(pkg, 0).uid
    } catch (e: Exception) { null }

    /** Bytes this app has sent and received today, across both wifi and mobile. */
    private fun totals(ctx: Context, uid: Int): Pair<Long, Long> {
        val nsm = ctx.getSystemService(Context.NETWORK_STATS_SERVICE) as NetworkStatsManager
        val end = System.currentTimeMillis()
        val start = end - 24 * 60 * 60 * 1000L
        var rx = 0L; var tx = 0L
        @Suppress("DEPRECATION")
        for (type in intArrayOf(ConnectivityManager.TYPE_WIFI, ConnectivityManager.TYPE_MOBILE)) {
            try {
                val b = nsm.querySummaryForUid(type, null, start, end, uid)
                rx += b.rxBytes; tx += b.txBytes
            } catch (e: Exception) { /* that transport is simply unavailable; keep the other */ }
        }
        return rx to tx
    }

    fun start(ctx: Context): Boolean {
        if (running) return true
        if (!hasPermission(ctx)) return false
        val app = ctx.applicationContext
        samples.clear(); lastRx.clear(); lastTx.clear()
        running = true
        handler = Handler(Looper.getMainLooper())
        val tick = object : Runnable {
            override fun run() {
                if (!running) return
                for ((pkg, name) in WATCH) {
                    val uid = uidOf(app, pkg) ?: continue
                    val (rx, tx) = totals(app, uid)
                    val pRx = lastRx[name]; val pTx = lastTx[name]
                    // the first reading only establishes a baseline — a delta needs two points
                    if (pRx != null && pTx != null && (rx != pRx || tx != pTx) && samples.size < MAX_SAMPLES) {
                        samples.add(Sample(System.currentTimeMillis(), name, rx - pRx, tx - pTx, rx, tx))
                    }
                    lastRx[name] = rx; lastTx[name] = tx
                }
                handler?.postDelayed(this, INTERVAL_MS)
            }
        }
        handler?.post(tick)
        return true
    }

    fun stop() { running = false; handler?.removeCallbacksAndMessages(null); handler = null }

    fun count(): Int = samples.size

    /**
     * One row per second in which an app's counters moved. Bytes and times only — this is the
     * whole record, and it is why the file can be shared without a second thought.
     */
    fun dump(): String {
        val f = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.UK)
        val sb = StringBuilder("time,app,bytes_up,bytes_down,total_up,total_down\n")
        for (s in samples) sb.append(f.format(Date(s.atMs))).append(',').append(s.app).append(',')
            .append(s.txDelta).append(',').append(s.rxDelta).append(',')
            .append(s.txTotal).append(',').append(s.rxTotal).append('\n')
        return sb.toString()
    }
}
