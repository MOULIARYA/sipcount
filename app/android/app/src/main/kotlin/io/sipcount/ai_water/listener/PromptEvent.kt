package io.sipcount.ai_water.listener

import org.json.JSONObject

/**
 * Kotlin mirror of lib/features/prompt_listener/domain/prompt_event.dart (schema v1).
 * This is the ONLY object the service is allowed to hand to the Dart side.
 * It has no field that could hold prompt text — by construction.
 */
data class PromptEvent(
    val vendor: String,          // openai | anthropic | google | unknown
    val modelHint: String?,      // lowercase keyword seen on screen, e.g. "o3", "flash"; never free text
    val task: String,            // text | code | long_context | image
    val charCount: Int,
    val attachmentCount: Int,
    val tsSeconds: Long,
) {
    fun toJson(): String = JSONObject().apply {
        put("v", 1)
        put("source", "android_a11y")
        put("vendor", vendor)
        put("model_hint", modelHint ?: JSONObject.NULL)
        put("task", task)
        put("char_count", charCount)
        put("attachment_count", attachmentCount)
        put("ts", tsSeconds)
    }.toString()
}
