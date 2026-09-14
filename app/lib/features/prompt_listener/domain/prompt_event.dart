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
///   "ts": 1726300000             // unix seconds, used only for daily bucketing
/// }
library;

import '../../calculation_engine/domain/model_profile.dart';

enum ListenerSource { androidA11y, iosKeyboard, iosShare, browserExt }

class PromptEvent {
  const PromptEvent({
    required this.source,
    required this.vendor,
    required this.modelHint,
    required this.task,
    required this.charCount,
    required this.attachmentCount,
    required this.timestamp,
  });

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
