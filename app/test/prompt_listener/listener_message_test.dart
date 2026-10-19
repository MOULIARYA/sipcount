import 'package:flutter_test/flutter_test.dart';

import 'package:ai_water/features/prompt_listener/domain/prompt_event.dart';

// I-70 (2026-10-19): the phone now measures the answer, not just the prompt. These pin the wire
// shape that crosses from the Accessibility service into Dart.
void main() {
  test('a prompt from an older build (no kind, no turn id) still parses', () {
    final m = ListenerMessage.fromJson({
      'v': 1, 'source': 'android_a11y', 'vendor': 'openai', 'model_hint': null,
      'task': 'text', 'char_count': 120, 'attachment_count': 0, 'ts': 1760000000,
    });
    expect(m, isA<PromptEvent>());
    final p = m as PromptEvent;
    expect(p.turnId, isNull);
    expect(p.contextChars, 0);
  });

  test('a prompt carries its turn id and the conversation length', () {
    final p = ListenerMessage.fromJson({
      'v': 1, 'source': 'android_a11y', 'vendor': 'anthropic', 'model_hint': 'sonnet',
      'task': 'text', 'char_count': 80, 'attachment_count': 0, 'ts': 1760000000,
      'turn_id': 't-1', 'context_chars': 4200,
    }) as PromptEvent;
    expect(p.turnId, 't-1');
    expect(p.contextChars, 4200);
  });

  test('a reply parses as a ReplyEvent with lengths and time only', () {
    final r = ListenerMessage.fromJson({
      'v': 1, 'kind': 'reply', 'source': 'android_a11y', 'turn_id': 't-1',
      'reply_chars': 1830, 'active_ms': 9400, 'ts': 1760000010,
    });
    expect(r, isA<ReplyEvent>());
    final reply = r as ReplyEvent;
    expect(reply.replyChars, 1830);
    expect(reply.activeMs, 9400);
  });

  test('a reply that smuggles text is refused', () {
    expect(
      () => ListenerMessage.fromJson({'v': 1, 'kind': 'reply', 'turn_id': 't', 'reply': 'hello', 'ts': 1}),
      throwsFormatException,
    );
  });

  test('a reply without a turn id is refused rather than guessed at', () {
    expect(() => ListenerMessage.fromJson({'v': 1, 'kind': 'reply', 'reply_chars': 10, 'ts': 1}),
        throwsFormatException);
  });
}
