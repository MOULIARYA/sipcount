/// Dart side of the native bridge. Native code pushes PromptEvent JSON; Dart
/// never asks for anything richer. EventChannel keeps Dart idle until an event
/// arrives (no polling → no battery cost).
///
/// While the Flutter engine is not running, the Android service queues events
/// (counts only) in an app-private file; [drainPending] fetches and clears them.
library;

import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/prompt_event.dart';

class ListenerChannel {
  static const _events = EventChannel('ai_water/prompt_events');
  static const _control = MethodChannel('ai_water/listener_control');

  /// Prompts and the measured length of their answers, in the order the phone saw them. A
  /// malformed or text-bearing payload is dropped here rather than surfacing as a stream error.
  Stream<ListenerMessage> events() => _events.receiveBroadcastStream().expand((raw) {
        try {
          return [ListenerMessage.fromJson(jsonDecode(raw as String) as Map<String, dynamic>)];
        } catch (_) {
          // malformed (a FormatException, or a TypeError on a missing field): drop it
          return const <ListenerMessage>[];
        }
      });

  Future<bool> isEnabled() async {
    try {
      return (await _control.invokeMethod<bool>('isEnabled')) ?? false;
    } on MissingPluginException {
      return false; // e.g. running tests / unsupported platform
    }
  }

  /// Opens the OS settings page (Accessibility on Android, Keyboards on iOS).
  Future<void> openEnableSettings() => _control.invokeMethod('openSettings');

  /// Events captured while the app was not running. Cleared on the native side once returned.
  Future<List<ListenerMessage>> drainPending() async {
    try {
      final raw = await _control.invokeListMethod<String>('drainPending') ?? const [];
      final out = <ListenerMessage>[];
      for (final line in raw) {
        try {
          out.add(ListenerMessage.fromJson(jsonDecode(line) as Map<String, dynamic>));
        } catch (_) {
          // Malformed or text-bearing payloads are dropped, never surfaced — including a line
          // with a missing field, which throws a TypeError and would otherwise stop the app
          // from starting.
        }
      }
      return out;
    } on MissingPluginException {
      return const [];
    }
  }
}
