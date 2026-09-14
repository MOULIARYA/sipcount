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

  Stream<PromptEvent> events() => _events
      .receiveBroadcastStream()
      .map((raw) => PromptEvent.fromJson(jsonDecode(raw as String) as Map<String, dynamic>));

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
  Future<List<PromptEvent>> drainPending() async {
    try {
      final raw = await _control.invokeListMethod<String>('drainPending') ?? const [];
      final out = <PromptEvent>[];
      for (final line in raw) {
        try {
          out.add(PromptEvent.fromJson(jsonDecode(line) as Map<String, dynamic>));
        } on FormatException {
          // Malformed or text-bearing payloads are dropped, never surfaced.
        }
      }
      return out;
    } on MissingPluginException {
      return const [];
    }
  }
}
