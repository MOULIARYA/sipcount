/// THE privacy boundary. This is the only shape that may cross from any
/// listener (Android AccessibilityService, iOS keyboard/share extension,
/// browser extension) into the app. It carries counts and hints — never text.
///
/// Wire format (JSON over MethodChannel / native messaging):
/// {
///   "v": 1,
///   "source": "android_a11y" | "ios_keyboard" | "ios_share" | "browser_ext",
///   "vendor": "openai" | "anthropic" | "google" | "unknown",
///   "model_hint": "gpt-4o" | "o3" | "claude-opus" | null,   // as shown in the UI, lowercase
///   "task": "text" | "code" | "long_context" | "image",
///   "char_count": 1234,          // characters in the submitted prompt
///   "attachment_count": 0,       // files/images attached (drives long_context / image)
///   "ts": 1726300000,            // unix seconds, used only for daily bucketing
///   "turn_id": "…",              // optional; pairs the prompt with its ReplyEvent (below)
///   "context_chars": 5200        // optional; visible conversation length at send
/// }
library;

import '../../calculation_engine/domain/model_profile.dart';

enum ListenerSource { androidA11y, iosKeyboard, iosShare, browserExt }

/// Anything a listener may send: a prompt, or the measured length of its answer.
abstract class ListenerMessage {
  const ListenerMessage();

  /// Routes on `kind`. A reply carries `"kind": "reply"`; a prompt carries no kind, which keeps
  /// every event queued by an older build readable.
  static ListenerMessage fromJson(Map<String, dynamic> j) =>
      j['kind'] == 'reply' ? ReplyEvent.fromJson(j) : PromptEvent.fromJson(j);
}

/// How long the answer to [turnId] was (I-70, 2026-10-19). Cumulative: a later report for the
/// same turn supersedes an earlier one. Lengths and milliseconds only.
///
/// { "v": 1, "kind": "reply", "source": "android_a11y", "turn_id": "…",
///   "reply_chars": 1830, "active_ms": 9400, "ts": 1726300000 }
class ReplyEvent extends ListenerMessage {
  const ReplyEvent({required this.turnId, required this.replyChars, required this.activeMs});

  final String turnId;
  final int replyChars;
  final int activeMs;

  factory ReplyEvent.fromJson(Map<String, dynamic> j) {
    if (j['v'] != PromptEvent.schemaVersion) throw FormatException('Unsupported ReplyEvent schema ${j['v']}');
    for (final k in const ['text', 'prompt', 'content', 'body', 'reply']) {
      if (j.containsKey(k)) throw const FormatException('ReplyEvent must not contain text');
    }
    final id = j['turn_id'];
    if (id is! String || id.isEmpty) throw const FormatException('ReplyEvent needs a turn_id');
    return ReplyEvent(
      turnId: id,
      replyChars: (j['reply_chars'] as num?)?.toInt() ?? 0,
      activeMs: (j['active_ms'] as num?)?.toInt() ?? 0,
    );
  }
}

class PromptEvent extends ListenerMessage {
  const PromptEvent({
    required this.source,
    required this.vendor,
    required this.modelHint,
    required this.task,
    required this.charCount,
    required this.attachmentCount,
    required this.timestamp,
    this.turnId,
    this.contextChars = 0,
  });

  /// Pairs this prompt with the [ReplyEvent]s that measure its answer. Null from older builds and
  /// from the demo button, in which case the assumed reply stands.
  final String? turnId;

  /// Visible conversation length at send, which the model re-reads (the context factor).
  final int contextChars;

  final ListenerSource source;
  final String vendor;
  final String? modelHint;
  final TaskType task;
  final int charCount;
  final int attachmentCount;
  final DateTime timestamp;

  static const int schemaVersion = 1;

  factory PromptEvent.fromJson(Map<String, dynamic> j) {
    if (j['v'] != schemaVersion) throw FormatException('Unsupported PromptEvent schema ${j['v']}');
    // Defensive: refuse any payload that smuggles text. Fail closed.
    for (final k in const ['text', 'prompt', 'content', 'body']) {
      if (j.containsKey(k)) throw const FormatException('PromptEvent must not contain prompt text');
    }
    return PromptEvent(
      source: _source(j['source'] as String),
      vendor: j['vendor'] as String? ?? 'unknown',
      modelHint: j['model_hint'] as String?,
      task: _task(j['task'] as String? ?? 'text'),
      charCount: (j['char_count'] as num?)?.toInt() ?? 0,
      attachmentCount: (j['attachment_count'] as num?)?.toInt() ?? 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(((j['ts'] as num).toInt()) * 1000, isUtc: true),
      turnId: j['turn_id'] as String?,
      contextChars: (j['context_chars'] as num?)?.toInt() ?? 0,
    );
  }

  static ListenerSource _source(String s) => switch (s) {
        'android_a11y' => ListenerSource.androidA11y,
        'ios_keyboard' => ListenerSource.iosKeyboard,
        'ios_share' => ListenerSource.iosShare,
        'browser_ext' => ListenerSource.browserExt,
        _ => throw FormatException('Unknown source $s'),
      };

  static TaskType _task(String s) => switch (s) {
        'code' => TaskType.code,
        'long_context' => TaskType.longContext,
        'image' => TaskType.image,
        _ => TaskType.text,
      };
}
