package io.sipcount.ai_water.probe

import android.app.AppOpsManager
import android.app.usage.NetworkStatsManager
import android.content.Context
import android.net.ConnectivityManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
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
 * "a session happened". It never tested polling the per-app counters once a second while the app is
 * in front. A prompt is a small upload followed by a larger streamed download — if that shape
 * survives into the counters at one-second resolution, the tunnel goes away, and with it a
 * userspace TCP/IP stack, the battery cost, the Play disclosure video and most of the review risk.
 *
 * KNOWN RISK, recorded before the experiment so the result is read honestly: NetworkStatsManager
 * serves data the system has flushed into buckets, and the flush cadence is not documented or
 * guaranteed. The counters may well move in coarse steps however often we ask. That is why every
 * row carries the running totals as well as the delta: flat totals with periodic jumps means the
 * API is too coarse and we need a different sensor — it does NOT mean the phone cannot see a
 * prompt, and it must not be read as a verdict for the VpnService.
 *
 * Reads byte totals per app. No packets, no hostnames, no content.
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
    private var thread: HandlerThread? = null
    private var handler: Handler? = null
    @Volatile private var running = false
    private var capped = false

    /**
     * Fixed at start, never recomputed. A sliding 24-hour window would drop old buckets out of the
     * far end as the run went on, and the "total" would fall — producing negative deltas that look
     * like data and are not.
     */
    private var windowStart = 0L

    fun isRunning(): Boolean = running
    fun isCapped(): Boolean = capped

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

    /** Bytes this app has sent and received since the window opened, across wifi and mobile. */
    private fun totals(ctx: Context, uid: Int): Pair<Long, Long> {
        val nsm = ctx.getSystemService(Context.NETWORK_STATS_SERVICE) as NetworkStatsManager
        val end = System.currentTimeMillis()
        var rx = 0L; var tx = 0L
        @Suppress("DEPRECATION")
        for (type in intArrayOf(ConnectivityManager.TYPE_WIFI, ConnectivityManager.TYPE_MOBILE)) {
            try {
                val b = nsm.querySummaryForUid(type, null, windowStart, end, uid)
                rx += b.rxBytes; tx += b.txBytes
            } catch (e: Exception) { /* that transport is simply unavailable; keep the other */ }
        }
        return rx to tx
    }

    /**
     * Called by [ProbeService], not by the UI. Each tick is six binder round-trips to the system
     * server, so it runs on its own thread: on the main looper it would jank the app it is
     * measuring, and a battery claim measured through that would be worthless.
     */
    @Synchronized
    fun startSampling(ctx: Context): Boolean {
        if (running) return true
        if (!hasPermission(ctx)) return false
        val app = ctx.applicationContext
        samples.clear(); lastRx.clear(); lastTx.clear(); capped = false
        windowStart = System.currentTimeMillis() - 60 * 60 * 1000L   // an hour of head-room, then frozen
        running = true
        val t = HandlerThread("sipcount-probe").also { it.start() }
        thread = t
        val h = Handler(t.looper)
        handler = h
        val tick = object : Runnable {
            override fun run() {
                if (!running) return
                for ((pkg, name) in WATCH) {
                    val uid = uidOf(app, pkg) ?: continue
                    val (rx, tx) = totals(app, uid)
                    val pRx = lastRx[name]; val pTx = lastTx[name]
                    // the first reading only establishes a baseline — a delta needs two points
                    if (pRx != null && pTx != null && (rx != pRx || tx != pTx)) {
                        if (samples.size < MAX_SAMPLES) {
                            synchronized(samples) {
                                samples.add(Sample(System.currentTimeMillis(), name, rx - pRx, tx - pTx, rx, tx))
                            }
                        } else {
                            capped = true    // say so rather than silently dropping rows
                        }
                    }
                    lastRx[name] = rx; lastTx[name] = tx
                }
                h.postDelayed(this, INTERVAL_MS)
            }
        }
        h.post(tick)
        return true
    }

    @Synchronized
    fun stopSampling() {
        running = false
        handler?.removeCallbacksAndMessages(null)
        thread?.quitSafely()
        handler = null; thread = null
    }

    fun count(): Int = synchronized(samples) { samples.size }

    /**
     * One row per second in which an app's counters moved. Bytes and times only — this is the whole
     * record, and it is why it can be pasted into a chat without a second thought.
     */
    fun dump(): String = synchronized(samples) {
        val f = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.UK)
        val sb = StringBuilder("time,app,bytes_up,bytes_down,total_up,total_down\n")
        for (s in samples) sb.append(f.format(Date(s.atMs))).append(',').append(s.app).append(',')
            .append(s.txDelta).append(',').append(s.rxDelta).append(',')
            .append(s.txTotal).append(',').append(s.rxTotal).append('\n')
        sb.toString()
    }
}
