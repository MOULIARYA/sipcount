package io.sipcount.ai_water.probe

import android.app.AppOpsManager
import android.app.usage.NetworkStats
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
 * Spike only (I-60) — not part of the shipping app. Attempt two, after attempt one was written
 * against an API that does not exist.
 *
 * THE QUESTION: can a phone resolve an individual prompt from per-app byte counters, without a
 * VpnService?
 *
 * What changed since attempt one. That build called `querySummaryForUid`, which I had invented;
 * the compiler said so. Reading the real reference then answered more than the typo:
 *
 *  - `queryDetailsForUid` is the documented per-app history query, and its own javadoc rules it out
 *    for us — "Since bucket length is in the order of hours, this method cannot be used to measure
 *    data usage on a fine grained time scale."
 *  - `TrafficStats.getUidRxBytes` reads live counters but "will only report traffic statistics for
 *    the calling UID… UNSUPPORTED for all other UIDs" since Android 7.
 *
 * I then called the whole idea impossible. That was too broad, and this probe is the correction.
 * There is a third route I never tested: [NetworkStatsManager.querySummary] returns a bucket per
 * UID for every app belonging to the calling user — which is every app on a normal phone — and
 * `NetworkStatsManager`'s constructor sets `setPollOnOpen(true)`, so each query may force the
 * system to flush fresh counters rather than serve an hours-old bucket. Whether it actually does is
 * **not documented anywhere**. It is one afternoon to measure, and if it is true, Android needs
 * neither a tunnel nor the accessibility service.
 *
 * THE DIAGNOSTIC THAT MAKES THE ANSWER UNAMBIGUOUS: every row carries the bucket's own
 * [NetworkStats.Bucket.getStartTimeStamp] and [getEndTimeStamp]. That is the difference between
 * "the phone cannot see this" and "we asked the wrong way":
 *
 *  - bucket spans of minutes or hours, values stepping occasionally  → the API is too coarse, the
 *    polling idea is dead, and the VpnService is genuinely required.
 *  - bucket spans tracking our query window, values rising each second → prompts are resolvable
 *    with no VPN, no accessibility service, and no Play Protect install block.
 *
 * Either answer is worth the afternoon. Neither is a guess.
 *
 * Reads byte totals per app. No packets, no hostnames, no content.
 */
object NetworkProbe {

    /**
     * The apps worth watching. Anything not installed is skipped rather than failing.
     *
     * Madhur's first run used Gemini and the log showed nothing for it, because on most phones
     * Gemini is not a separate app — it lives inside the Google app. Our own accessibility config
     * has listed `googlequicksearchbox` for exactly this reason since September; the probe was
     * written without looking at it. Both package names map to the same label so a phone with
     * either (or both) reports as "Gemini".
     */
    private val WATCH = mapOf(
        "com.openai.chatgpt" to "ChatGPT",
        "com.anthropic.claude" to "Claude",
        "com.google.android.apps.bard" to "Gemini",
        "com.google.android.googlequicksearchbox" to "Gemini"
    )

    private const val INTERVAL_MS = 1_000L
    private const val MAX_SAMPLES = 7200          // two hours at one a second, then it stops growing

    data class Sample(
        val atMs: Long, val app: String,
        val rxDelta: Long, val txDelta: Long,
        val rxTotal: Long, val txTotal: Long,
        val bucketStartMs: Long, val bucketEndMs: Long
    )

    private val samples = ArrayList<Sample>()
    private val lastRx = HashMap<Int, Long>()
    private val lastTx = HashMap<Int, Long>()
    private var thread: HandlerThread? = null
    private var handler: Handler? = null
    @Volatile private var running = false
    @Volatile private var capped = false
    @Volatile private var lastError: String? = null

    /**
     * Fixed at start, never recomputed. A sliding window would drop old buckets out of the far end
     * as the run went on, the total would fall, and the delta would go negative — noise that reads
     * exactly like data.
     */
    private var windowStart = 0L

    fun isRunning(): Boolean = running
    fun isCapped(): Boolean = capped
    fun lastError(): String? = lastError

    /** Usage access is a special permission the user grants in Settings; we cannot request it inline. */
    fun hasPermission(ctx: Context): Boolean {
        val ops = ctx.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
            ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), ctx.packageName)
        else
            @Suppress("DEPRECATION") ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), ctx.packageName)
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /// `distinct()` because two packages share the label "Gemini"; without it the screen would
    /// read "ChatGPT, Claude, Gemini, Gemini".
    fun installedApps(ctx: Context): List<String> =
        WATCH.filter { uidOf(ctx, it.key) != null }.map { it.value }.distinct()

    private fun uidOf(ctx: Context, pkg: String): Int? = try {
        ctx.packageManager.getApplicationInfo(pkg, 0).uid
    } catch (e: Exception) { null }

    private data class Totals(var rx: Long = 0, var tx: Long = 0, var start: Long = 0, var end: Long = 0)

    /**
     * One pass over every bucket the system will give us, keeping only the UIDs we watch.
     *
     * `querySummary` is deliberately the call here rather than `queryDetailsForUid`: it returns a
     * bucket per UID for all apps of the calling user, and it is the one whose granularity is
     * undocumented rather than documented-as-hours. Each call is a binder round-trip that the docs
     * say "may take several seconds", so this never runs on the main thread.
     */
    private fun readWatched(ctx: Context, wanted: Map<Int, String>): Map<Int, Totals> {
        val nsm = ctx.getSystemService(Context.NETWORK_STATS_SERVICE) as NetworkStatsManager
        val out = HashMap<Int, Totals>()
        val now = System.currentTimeMillis()
        @Suppress("DEPRECATION")
        for (type in intArrayOf(ConnectivityManager.TYPE_WIFI, ConnectivityManager.TYPE_MOBILE)) {
            var stats: NetworkStats? = null
            try {
                stats = nsm.querySummary(type, null, windowStart, now)
                val b = NetworkStats.Bucket()
                while (stats.hasNextBucket() && stats.getNextBucket(b)) {
                    if (!wanted.containsKey(b.uid)) continue
                    // Keyed by UID, not by label. Two packages now share the label "Gemini" (the
                    // standalone app and the Google app that hosts it); summing them meant a tick
                    // where only one appeared in the buckets would look like the total going DOWN.
                    val t = out.getOrPut(b.uid) { Totals() }
                    t.rx += b.rxBytes
                    t.tx += b.txBytes
                    // the whole point of the experiment: how wide is the bucket the system gave us?
                    if (t.start == 0L || b.startTimeStamp < t.start) t.start = b.startTimeStamp
                    if (b.endTimeStamp > t.end) t.end = b.endTimeStamp
                }
            } catch (e: Exception) {
                // one transport may simply be unavailable; record it rather than hiding it
                lastError = "${e.javaClass.simpleName}: ${e.message}"
            } finally {
                try { stats?.close() } catch (e: Exception) { /* nothing useful to do */ }
            }
        }
        return out
    }

    /** Called by [ProbeService], not by the UI — the run happens while this app is backgrounded. */
    @Synchronized
    fun startSampling(ctx: Context): Boolean {
        if (running) return true
        if (!hasPermission(ctx)) return false
        val app = ctx.applicationContext
        synchronized(samples) { samples.clear() }
        lastRx.clear(); lastTx.clear(); capped = false; lastError = null
        windowStart = System.currentTimeMillis() - 60 * 60 * 1000L   // an hour of head-room, then frozen
        val wanted = WATCH.mapNotNull { (pkg, name) -> uidOf(app, pkg)?.let { it to name } }.toMap()
        if (wanted.isEmpty()) { lastError = "None of the three AI apps are installed."; return false }
        running = true
        val t = HandlerThread("sipcount-probe").also { it.start() }
        thread = t
        val h = Handler(t.looper)
        handler = h
        val tick = object : Runnable {
            override fun run() {
                if (!running) return
                val now = System.currentTimeMillis()
                for ((uid, tot) in readWatched(app, wanted)) {
                    val name = wanted[uid] ?: continue
                    val pRx = lastRx[uid]; val pTx = lastTx[uid]
                    // the first reading only establishes a baseline — a delta needs two points
                    if (pRx != null && pTx != null && (tot.rx != pRx || tot.tx != pTx)) {
                        if (synchronized(samples) { samples.size } < MAX_SAMPLES) {
                            synchronized(samples) {
                                samples.add(Sample(now, name, tot.rx - pRx, tot.tx - pTx,
                                                   tot.rx, tot.tx, tot.start, tot.end))
                            }
                        } else capped = true   // say so rather than silently dropping rows
                    }
                    lastRx[uid] = tot.rx; lastTx[uid] = tot.tx
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
     * One row per second in which an app's counters moved. `bucket_span_s` is the column that
     * decides the experiment: seconds means the API is live enough to see a prompt, thousands of
     * seconds means it is hour-bucketed and the tunnel is genuinely needed.
     *
     * Times and byte counts only — this is the whole record, which is why it can be pasted into a
     * chat without a second thought.
     */
    fun dump(): String = synchronized(samples) {
        val f = SimpleDateFormat("HH:mm:ss", Locale.UK)
        val sb = StringBuilder("time,app,bytes_up,bytes_down,total_up,total_down,bucket_span_s\n")
        for (s in samples) {
            val span = if (s.bucketEndMs > s.bucketStartMs) (s.bucketEndMs - s.bucketStartMs) / 1000 else -1
            sb.append(f.format(Date(s.atMs))).append(',').append(s.app).append(',')
                .append(s.txDelta).append(',').append(s.rxDelta).append(',')
                .append(s.txTotal).append(',').append(s.rxTotal).append(',')
                .append(span).append('\n')
        }
        sb.toString()
    }
}
