package io.sipcount.ai_water.usage

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process
import org.json.JSONArray
import org.json.JSONObject

/**
 * Estimate mode (I-73, 2026-10-19). Reads how long each AI app was in the foreground from the
 * system's usage history — the same data the phone's own Digital Wellbeing screen shows — and
 * hands the Dart side a list of sessions. Nothing here needs the Accessibility permission, so it
 * works alongside banking apps, which block any Accessibility service that is not a disability
 * tool (I-72).
 *
 * What it sees: that an app was open, from when to when. What it cannot see: prompts, text,
 * models, replies. The Dart side turns minutes into an *estimated* prompt count and says so.
 *
 * API facts this is written against (developer.android.com, read 2026-10-19):
 *  - `UsageStatsManager.queryEvents(begin, end)`: "Events are only kept by the system for a few
 *    days." Requires PACKAGE_USAGE_STATS, which the user grants in Settings
 *    (`Settings.ACTION_USAGE_ACCESS_SETTINGS`); declaring it is not enough.
 *  - `UsageEvents.Event.ACTIVITY_RESUMED` / `ACTIVITY_PAUSED` (API 29) replace the deprecated
 *    MOVE_TO_FOREGROUND / MOVE_TO_BACKGROUND and share their values (1 and 2).
 *  - `AppOpsManager.OPSTR_GET_USAGE_STATS` is the op the grant sets; `unsafeCheckOpNoThrow`
 *    (API 29, deprecated in 36 in favour of `checkOpNoThrow`) reads it.
 */
object UsageHarvester {

    /** Packages whose foreground time is AI use. Chrome and the Google app are deliberately NOT
     *  here: time in Chrome is not time on chatgpt.com, and the Google app is mostly Search. */
    private val AI_PACKAGES = mapOf(
        "com.openai.chatgpt" to "openai",
        "com.anthropic.claude" to "anthropic",
        "com.google.android.apps.bard" to "google",
    )

    /** Longer than this between a resume and a pause is treated as a dangling session (phone
     *  died, process killed without a pause event) and capped — a forgotten app cannot bill a
     *  night's sleep as chat. */
    private const val MAX_SESSION_MS = 2 * 60 * 60 * 1000L

    /** False on any failure — a permission check must never be able to stop the app (I-74). */
    @Suppress("DEPRECATION")
    fun hasPermission(ctx: Context): Boolean = try {
        checkOp(ctx)
    } catch (_: Throwable) {
        false
    }

    @Suppress("DEPRECATION")
    private fun checkOp(ctx: Context): Boolean {
        val ops = ctx.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), ctx.packageName)
        } else {
            ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), ctx.packageName)
        }
        return when (mode) {
            AppOpsManager.MODE_ALLOWED -> true
            // MODE_DEFAULT means "fall back to the manifest permission check"
            AppOpsManager.MODE_DEFAULT ->
                ctx.checkCallingOrSelfPermission(android.Manifest.permission.PACKAGE_USAGE_STATS) == PackageManager.PERMISSION_GRANTED
            else -> false
        }
    }

    /**
     * Foreground sessions of the AI apps that overlap [sinceMs, untilMs), as a JSON array of
     * `{ "vendor": "openai", "start_ms": …, "end_ms": … }`. Sessions are returned whole; the Dart
     * side clips them to the window it asked for, so calling twice over overlapping windows
     * never double-counts. A session still open at [untilMs] is closed there.
     *
     * The query starts [MAX_SESSION_MS] before [sinceMs] so a session that began before the
     * window is seen beginning, not just ending.
     */
    fun sessionsJson(ctx: Context, sinceMs: Long, untilMs: Long): String {
        val out = JSONArray()
        if (untilMs <= sinceMs) return out.toString()
        val usm = ctx.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = usm.queryEvents(sinceMs - MAX_SESSION_MS, untilMs) ?: return out.toString()

        val open = HashMap<String, Long>() // package → resume time
        val e = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(e)
            val pkg = e.packageName ?: continue
            if (pkg !in AI_PACKAGES) continue
            when (e.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> {   // == MOVE_TO_FOREGROUND on older APIs
                    if (pkg !in open) open[pkg] = e.timeStamp
                }
                UsageEvents.Event.ACTIVITY_PAUSED -> {    // == MOVE_TO_BACKGROUND on older APIs
                    val start = open.remove(pkg) ?: continue
                    emit(out, pkg, start, e.timeStamp)
                }
                else -> Unit
            }
        }
        // still in the foreground (or no pause event recorded): close at the end of the window
        for ((pkg, start) in open) emit(out, pkg, start, untilMs)
        return out.toString()
    }

    private fun emit(out: JSONArray, pkg: String, start: Long, end: Long) {
        val vendor = AI_PACKAGES[pkg] ?: return
        val stop = if (end - start > MAX_SESSION_MS) start + MAX_SESSION_MS else end
        if (stop <= start) return
        out.put(JSONObject().apply {
            put("vendor", vendor)
            put("start_ms", start)
            put("end_ms", stop)
        })
    }
}
