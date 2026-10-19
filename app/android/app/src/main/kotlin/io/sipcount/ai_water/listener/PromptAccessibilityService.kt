package io.sipcount.ai_water.listener

import android.accessibilityservice.AccessibilityService
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import java.util.ArrayDeque

/**
 * Detects "prompt sent" in ChatGPT, Claude, Gemini and Chrome (on the three vendors' sites),
 * and emits ONE PromptEvent per send. Privacy rules enforced in this file:
 *
 *  1. Text is only ever measured (`.length`) — never copied into a field, log or file.
 *  2. Only short UI labels (<= MAX_LABEL_CHARS) are compared against keyword lists, so
 *     message bodies are never inspected.
 *  3. The URL bar is read only to derive the vendor from the host; the URL is not kept.
 *  4. Window scans are bounded (MAX_NODES) to keep CPU/battery cost negligible.
 */
class PromptAccessibilityService : AccessibilityService() {

    private val lastEditLength = HashMap<String, Int>()
    private var lastEmitMs = 0L
    private var lastPollMs = 0L
    private var lastWindowStateMs = 0L

    // ---- measuring the answer (I-70, 2026-10-19) ----------------------------------------------
    // Until now the phone priced every reply as a fixed 300 tokens, while the extension measured
    // it. The reply is most of the water, so this mirrors content.js `watchReply()`: watch how
    // much text the conversation gains after a send — LENGTHS ONLY, nothing kept — and report it
    // cumulatively. Positive changes are summed rather than taking (now − then), because a chat
    // screen only holds what is visible: old messages scroll out of the tree as the answer grows.
    private class ReplyWatch(val pkg: String, val turnId: String, val promptChars: Int, val tSend: Long, var last: Int) {
        var grew = 0
        var lastActive = tSend
        var reported = -1
    }
    private var watch: ReplyWatch? = null
    private var lastReplyPollMs = 0L
    private var turnSeq = 0
    private val main = Handler(Looper.getMainLooper())
    private val settle = Runnable { onSettle() }
    private val idle = Runnable { finishWatch() }
    private val cap = Runnable { finishWatch() }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        val pkg = event.packageName?.toString() ?: return
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) pollReply(pkg)
        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                // Screen navigation (chat → settings, new chat…). Used to suppress the
                // "text box vanished" heuristic right after such a change.
                lastWindowStateMs = System.currentTimeMillis()
                lastEditLength.remove(pkg)
            }
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> pollEditLength(pkg)
            AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED -> {
                // event.text holds what was typed; we keep only its length.
                var len = 0
                for (cs in event.text) len += cs?.length ?: 0
                val previous = lastEditLength[pkg] ?: 0
                if (len > 0) {
                    lastEditLength[pkg] = len
                } else if (previous >= MIN_SEND_CHARS || event.removedCount >= MIN_SEND_CHARS) {
                    // Field went from N chars to empty in ONE event: that is what a send does.
                    // Backspacing shrinks the field one character (or word) at a time and
                    // never trips this because `previous` is then 1 or 2 by the time it hits 0.
                    // Jetpack Compose apps (ChatGPT, Gemini) never emit TYPE_VIEW_CLICKED for
                    // finger taps, so this is the primary detector on Android; the click path
                    // below still covers View-based apps and Chrome.
                    handleSend(pkg, maxOf(previous, event.removedCount))
                } else {
                    lastEditLength.remove(pkg)
                }
            }
            AccessibilityEvent.TYPE_VIEW_CLICKED -> handleClick(pkg, event)
            else -> Unit
        }
    }

    override fun onInterrupt() = finishWatch()

    override fun onDestroy() {
        finishWatch()
        super.onDestroy()
    }

    // ---- the answer ---------------------------------------------------------------------------

    private fun startWatch(pkg: String, turnId: String, promptChars: Int, now: Long, convo: Int) {
        finishWatch() // a new send closes the previous turn with whatever it measured
        watch = ReplyWatch(pkg, turnId, promptChars, now, convo)
        main.postDelayed(idle, IDLE_MS)
        main.postDelayed(cap, CAP_MS)
    }

    private fun pollReply(pkg: String) {
        val w = watch ?: return
        if (pkg != w.pkg) return
        val now = System.currentTimeMillis()
        if (now - lastReplyPollMs < REPLY_POLL_MS) return
        lastReplyPollMs = now
        val root = rootInActiveWindow ?: return
        val cur = try { convoChars(root) } finally { safeRecycle(root) }
        val delta = cur - w.last
        w.last = cur
        if (delta > 0) w.grew += delta
        if (delta != 0) w.lastActive = now
        main.removeCallbacks(settle); main.postDelayed(settle, SETTLE_MS)
        main.removeCallbacks(idle); main.postDelayed(idle, IDLE_MS)
    }

    /** The page went quiet. If the stop control is still up the model is thinking, not done. */
    private fun onSettle() {
        val w = watch ?: return
        val root = rootInActiveWindow
        val samePkg = root?.packageName?.toString() == w.pkg
        val generating = samePkg && root != null && stopVisible(root)
        safeRecycle(root)
        if (!samePkg) { finishWatch(); return } // left the app mid-answer: keep what we measured
        if (generating) {
            w.lastActive = System.currentTimeMillis()
            main.postDelayed(settle, SETTLE_MS)
        } else {
            report(w)
        }
    }

    private fun report(w: ReplyWatch) {
        // the echoed prompt bubble is not the answer
        val reply = maxOf(0, w.grew - w.promptChars)
        // Nothing measured yet (e.g. the user left before the answer appeared): say nothing, so
        // the assumed reply stands instead of being replaced by zero.
        if (reply == 0 && w.reported < 0) return
        if (reply == w.reported) return
        w.reported = reply
        val json = ReplyEvent(w.turnId, reply, maxOf(0L, w.lastActive - w.tSend), System.currentTimeMillis() / 1000).toJson()
        if (!ListenerStreamHandler.tryEmit(json)) PendingQueue.append(applicationContext, json)
    }

    private fun finishWatch() {
        val w = watch ?: return
        watch = null
        main.removeCallbacks(settle); main.removeCallbacks(idle); main.removeCallbacks(cap)
        report(w)
    }

    /** Total text length on screen outside the text box. A length — the text is never kept. */
    private fun convoChars(root: AccessibilityNodeInfo): Int {
        var total = 0
        var visited = 0
        val q = ArrayDeque<AccessibilityNodeInfo>().apply { add(root) }
        while (q.isNotEmpty() && visited < MAX_REPLY_NODES) {
            val n = q.poll() ?: break
            visited++
            if (!n.isEditable) total += n.text?.length ?: 0
            for (i in 0 until n.childCount) n.getChild(i)?.let { q.add(it) }
            if (n !== root) safeRecycle(n)
        }
        while (q.isNotEmpty()) safeRecycle(q.poll())
        return total
    }

    /** A "Stop" control is on screen exactly while the model is generating (as in content.js). */
    private fun stopVisible(root: AccessibilityNodeInfo): Boolean {
        var visited = 0
        var found = false
        val q = ArrayDeque<AccessibilityNodeInfo>().apply { add(root) }
        while (q.isNotEmpty() && visited < MAX_NODES && !found) {
            val n = q.poll() ?: break
            visited++
            val label = shortLabel(n)
            if (label != null && (label.startsWith("stop") || label.contains("stop generating") || label.contains("stop response"))) found = true
            for (i in 0 until n.childCount) n.getChild(i)?.let { q.add(it) }
            if (n !== root) safeRecycle(n)
        }
        while (q.isNotEmpty()) safeRecycle(q.poll())
        return found
    }

    // ------------------------------------------------------------------------------------------

    /**
     * Fallback for apps (Gemini, Claude) that replace the text box on send instead of
     * clearing it, so no TYPE_VIEW_TEXT_CHANGED arrives. Throttled; reads one length only.
     *   box had >= MIN_SEND_CHARS  →  box present and empty        = send (strong)
     *   box had >= MIN_SEND_CHARS  →  no box in the window at all  = send, unless the screen
     *                                                                 just changed (weak)
     */
    private fun pollEditLength(pkg: String) {
        val now = System.currentTimeMillis()
        if (now - lastPollMs < POLL_MS) return
        lastPollMs = now

        val root = rootInActiveWindow ?: return
        val len = try { findEditLength(root) } finally { safeRecycle(root) }
        val previous = lastEditLength[pkg] ?: 0

        when {
            len == null -> {
                // Text box gone. Only trust it if this is not a screen change.
                if (previous >= MIN_SEND_CHARS && now - lastWindowStateMs > NAV_GUARD_MS) handleSend(pkg, previous)
                else if (previous > 0 && now - lastWindowStateMs <= NAV_GUARD_MS) lastEditLength.remove(pkg)
            }
            len > 0 -> lastEditLength[pkg] = len
            previous >= MIN_SEND_CHARS -> handleSend(pkg, previous)
            else -> lastEditLength.remove(pkg)
        }
    }

    /** Length of the first editable field found (bounded BFS), or null if none exists. */
    private fun findEditLength(root: AccessibilityNodeInfo): Int? {
        var visited = 0
        var result: Int? = null
        val q = ArrayDeque<AccessibilityNodeInfo>().apply { add(root) }
        while (q.isNotEmpty() && visited < MAX_EDIT_SCAN_NODES) {
            val n = q.poll() ?: break
            visited++
            if (n.isEditable) {
                result = n.text?.length ?: 0
                if (n !== root) safeRecycle(n)
                break
            }
            for (i in 0 until n.childCount) n.getChild(i)?.let { q.add(it) }
            if (n !== root) safeRecycle(n)
        }
        while (q.isNotEmpty()) safeRecycle(q.poll())
        return result
    }

    private fun handleClick(pkg: String, event: AccessibilityEvent) {
        val src = event.source ?: return
        val isSend = try { looksLikeSend(src) } finally { safeRecycle(src) }
        if (!isSend) return
        handleSend(pkg, 0)
    }

    /** [knownChars] is the length inferred by the caller (0 = unknown, fall back to window scan). */
    private fun handleSend(pkg: String, knownChars: Int) {
        val now = System.currentTimeMillis()
        if (now - lastEmitMs < DEBOUNCE_MS) return

        val root = rootInActiveWindow
        val vendor = vendorFor(pkg, root) ?: run { safeRecycle(root); return }

        val scan = if (root != null) scanWindow(root, vendor) else WindowScan(null, 0, null)
        val convo = if (root != null) convoChars(root) else 0
        safeRecycle(root)

        // The Google app is also Search/Discover; only its Gemini screen counts.
        if (pkg == GOOGLE_APP && !scan.sawGemini) return

        val chars = if (knownChars > 0) knownChars else scan.editLength ?: lastEditLength[pkg] ?: 0
        if (chars == 0 && scan.attachments == 0) return

        // timestamp + counter + random tail, as in content.js: two turns must never share an id
        val turnId = "$now-${++turnSeq}-${(1000..9999).random()}"
        val ev = PromptEvent(
            vendor = vendor,
            modelHint = scan.modelHint,
            task = if (scan.attachments > 0) "long_context" else "text",
            charCount = chars,
            attachmentCount = scan.attachments,
            tsSeconds = now / 1000,
            turnId = turnId,
            contextChars = convo,
        )
        lastEmitMs = now
        lastEditLength.remove(pkg)

        val json = ev.toJson()
        // Count at once on the assumed reply, then correct it when the answer lands — a user who
        // leaves mid-answer keeps the estimate rather than losing the turn.
        if (!ListenerStreamHandler.tryEmit(json)) PendingQueue.append(applicationContext, json)
        startWatch(pkg, turnId, chars, now, convo)
    }

    private fun looksLikeSend(n: AccessibilityNodeInfo): Boolean {
        val label = shortLabel(n) ?: return false
        if (!(label.contains("send") || label.contains("submit"))) return false
        val cls = n.className?.toString() ?: ""
        return cls.contains("Button") || cls.contains("ImageView") || cls.contains("View") || n.isClickable
    }

    private fun vendorFor(pkg: String, root: AccessibilityNodeInfo?): String? = when (pkg) {
        "com.openai.chatgpt" -> "openai"
        "com.anthropic.claude" -> "anthropic"
        "com.google.android.apps.bard" -> "google"
        GOOGLE_APP -> "google" // Gemini screen inside the Google app; verified after the window scan
        "com.android.chrome" -> hostVendor(root)
        else -> null
    }

    /** Reads the Chrome URL bar, maps host → vendor, discards the URL. */
    private fun hostVendor(root: AccessibilityNodeInfo?): String? {
        if (root == null) return null
        val bars = root.findAccessibilityNodeInfosByViewId("com.android.chrome:id/url_bar")
        var vendor: String? = null
        for (b in bars) {
            val host = b.text?.toString()?.lowercase()?.substringAfter("://")?.substringBefore('/') ?: ""
            vendor = when {
                host.endsWith("chatgpt.com") || host.endsWith("openai.com") -> "openai"
                host.endsWith("claude.ai") -> "anthropic"
                host.endsWith("gemini.google.com") -> "google"
                else -> null
            }
            safeRecycle(b)
            if (vendor != null) break
        }
        return vendor
    }

    private class WindowScan(val modelHint: String?, val attachments: Int, val editLength: Int?, val sawGemini: Boolean = false)

    /** Bounded BFS over the window. Reads lengths and short labels only. */
    private fun scanWindow(root: AccessibilityNodeInfo, vendor: String): WindowScan {
        val keywords = MODEL_KEYWORDS[vendor] ?: emptyList()
        var best: String? = null
        var attachments = 0
        var editLength: Int? = null
        var sawGemini = false
        var visited = 0
        val q = ArrayDeque<AccessibilityNodeInfo>().apply { add(root) }
        while (q.isNotEmpty() && visited < MAX_NODES) {
            val n = q.poll() ?: break
            visited++
            if (n.isEditable) {
                val len = n.text?.length ?: 0
                if (len > 0) editLength = len
            } else {
                shortLabel(n)?.let { label ->
                    // whole words only: "Profile" must not read as "pro", nor "Highlights" as "high"
                    // — both would price the turn as reasoning, ten times over (I-69 review)
                    for (k in keywords) if (hasWord(label, k) && (best == null || k.length > best!!.length)) best = k
                    if (label.contains("remove") && (label.contains("attach") || label.contains("file") || label.contains("image"))) attachments++
                    if (label.contains("gemini")) sawGemini = true
                }
            }
            for (i in 0 until n.childCount) n.getChild(i)?.let { q.add(it) }
            if (n !== root) safeRecycle(n)
        }
        while (q.isNotEmpty()) safeRecycle(q.poll())
        return WindowScan(best, attachments, editLength, sawGemini)
    }

    /** [keyword] appears in [label] as a whole word (or whole words), not inside another word. */
    private fun hasWord(label: String, keyword: String): Boolean {
        var from = 0
        while (true) {
            val i = label.indexOf(keyword, from)
            if (i < 0) return false
            val before = if (i == 0) ' ' else label[i - 1]
            val afterIdx = i + keyword.length
            val after = if (afterIdx >= label.length) ' ' else label[afterIdx]
            if (!before.isLetterOrDigit() && !after.isLetterOrDigit()) return true
            from = i + 1
        }
    }

    /** contentDescription or text, lowercased, only if short enough to be a UI label. */
    private fun shortLabel(n: AccessibilityNodeInfo): String? {
        val cd = n.contentDescription
        val t = n.text
        val s = when {
            cd != null && cd.length in 1..MAX_LABEL_CHARS -> cd
            t != null && t.length in 1..MAX_LABEL_CHARS -> t
            else -> return null
        }
        return s.toString().lowercase()
    }

    @Suppress("DEPRECATION")
    private fun safeRecycle(n: AccessibilityNodeInfo?) {
        try { n?.recycle() } catch (_: Throwable) { /* no-op on API 34+ */ }
    }

    companion object {
        private const val GOOGLE_APP = "com.google.android.googlequicksearchbox"
        private const val DEBOUNCE_MS = 1500L
        private const val MIN_SEND_CHARS = 3
        private const val POLL_MS = 400L
        private const val NAV_GUARD_MS = 1500L
        private const val MAX_EDIT_SCAN_NODES = 150
        private const val MAX_NODES = 300
        private const val MAX_LABEL_CHARS = 40

        // the answer watch — the same timings content.js uses, so phone and browser agree
        private const val REPLY_POLL_MS = 600L
        private const val SETTLE_MS = 2500L
        private const val IDLE_MS = 25_000L
        private const val CAP_MS = 300_000L
        private const val MAX_REPLY_NODES = 500

        // Lowercase substrings that appear in model-picker labels. Longest match wins in Dart too.
        private val MODEL_KEYWORDS: Map<String, List<String>> = mapOf(
            // thinking levels (I-69): the engine prices "high"/"extra high" as reasoning
            "openai" to listOf("o1", "o3", "o4", "thinking", "pro", "extra high", "high", "medium", "instant", "mini", "nano", "gpt-4o", "gpt-4.1", "gpt-5", "gpt-6"),
            "anthropic" to listOf("opus", "sonnet", "haiku", "extended"),
            "google" to listOf("flash-lite", "flash", "pro", "argon", "thinking", "deep think", "high", "medium", "low"),
        )
    }
}
