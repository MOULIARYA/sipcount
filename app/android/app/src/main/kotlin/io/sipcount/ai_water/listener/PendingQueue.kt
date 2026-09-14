package io.sipcount.ai_water.listener

import android.content.Context
import java.io.File

/**
 * Bounded, app-private queue of PromptEvent JSON lines captured while the Flutter
 * engine was not running. Contents are counts and hints only (see PromptEvent.kt).
 * Drained and deleted the next time the app opens.
 */
object PendingQueue {
    private const val FILE = "pending_prompt_events.jsonl"
    private const val MAX_LINES = 2000
    private val lock = Any()

    fun append(ctx: Context, line: String) = synchronized(lock) {
        val f = File(ctx.filesDir, FILE)
        val existing = if (f.exists()) f.readLines() else emptyList()
        val kept = if (existing.size >= MAX_LINES) existing.drop(existing.size - MAX_LINES + 1) else existing
        f.writeText((kept + line).joinToString("\n", postfix = "\n"))
    }

    fun drain(ctx: Context): List<String> = synchronized(lock) {
        val f = File(ctx.filesDir, FILE)
        if (!f.exists()) return emptyList()
        val lines = f.readLines().filter { it.isNotBlank() }
        f.delete()
        lines
    }
}
