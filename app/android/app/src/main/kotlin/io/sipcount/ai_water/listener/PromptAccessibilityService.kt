package io.sipcount.ai_water.listener

import android.accessibilityservice.AccessibilityService
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

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        val pkg = event.packageName?.toString() ?: return
        when (event.eventType) {
            AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED -> {
                // event.text holds what was typed; we keep only its length.
                var len = 0
                for (cs in event.text) len += cs?.length ?: 0
                if (len > 0) lastEditLength[pkg] = len
            }
            AccessibilityEvent.TYPE_VIEW_CLICKED -> handleClick(pkg, event)
            else -> Unit
        }
    }

    override fun onInterrupt() = Unit

    // ------------------------------------------------------------------------------------------

    private fun handleClick(pkg: String, event: AccessibilityEvent) {
        val src = event.source ?: return
        val isSend = try { looksLikeSend(src) } finally { safeRecycle(src) }
        if (!isSend) return

        val now = System.currentTimeMillis()
        if (now - lastEmitMs < DEBOUNCE_MS) return

        val root = rootInActiveWindow
        val vendor = vendorFor(pkg, root) ?: run { safeRecycle(root); return }

        val scan = if (root != null) scanWindow(root, vendor) else WindowScan(null, 0, null)
        safeRecycle(root)

        val chars = scan.editLength ?: lastEditLength[pkg] ?: 0
        if (chars == 0 && scan.attachments == 0) return

        val ev = PromptEvent(
            vendor = vendor,
            modelHint = scan.modelHint,
            task = if (scan.attachments > 0) "long_context" else "text",
            charCount = chars,
            attachmentCount = scan.attachments,
            tsSeconds = now / 1000,
        )
        lastEmitMs = now
        lastEditLength.remove(pkg)

        val json = ev.toJson()
        if (!ListenerStreamHandler.tryEmit(json)) PendingQueue.append(applicationContext, json)
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

    private class WindowScan(val modelHint: String?, val attachments: Int, val editLength: Int?)

    /** Bounded BFS over the window. Reads lengths and short labels only. */
    private fun scanWindow(root: AccessibilityNodeInfo, vendor: String): WindowScan {
        val keywords = MODEL_KEYWORDS[vendor] ?: emptyList()
        var best: String? = null
        var attachments = 0
        var editLength: Int? = null
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
                    for (k in keywords) if (label.contains(k) && (best == null || k.length > best!!.length)) best = k
                    if (label.contains("remove") && (label.contains("attach") || label.contains("file") || label.contains("image"))) attachments++
                }
            }
            for (i in 0 until n.childCount) n.getChild(i)?.let { q.add(it) }
            if (n !== root) safeRecycle(n)
        }
        while (q.isNotEmpty()) safeRecycle(q.poll())
        return WindowScan(best, attachments, editLength)
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
        private const val DEBOUNCE_MS = 1500L
        private const val MAX_NODES = 300
        private const val MAX_LABEL_CHARS = 40

        // Lowercase substrings that appear in model-picker labels. Longest match wins in Dart too.
        private val MODEL_KEYWORDS: Map<String, List<String>> = mapOf(
            "openai" to listOf("o1", "o3", "o4", "thinking", "mini", "nano", "gpt-4o", "gpt-4.1", "gpt-5"),
            "anthropic" to listOf("opus", "sonnet", "haiku", "extended"),
            "google" to listOf("flash-lite", "flash", "pro", "thinking"),
        )
    }
}
