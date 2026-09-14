/// Dart side of the native bridge. Native code pushes PromptEvent JSON; Dart
/// never asks for anything richer. EventChannel keeps Dart idle until an event
/// arrives (no polling → no battery cost).
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

  Future<bool> isEnabled() async => (await _control.invokeMethod<bool>('isEnabled')) ?? false;

  /// Opens the OS settings page (Accessibility on Android, Keyboards on iOS).
  Future<void> openEnableSettings() => _control.invokeMethod('openSettings');
}
