/// Estimate mode (I-73): how long each AI app was open, from the system's usage history.
///
/// This is the sensor that works next to banking apps (I-72): it needs the Usage Access
/// permission, not Accessibility. It sees that an app was open and for how long — never a
/// prompt, a reply, or a model. The tracker turns minutes into an *estimated* prompt count.
///
/// Wire format from native (JSON array): `[{ "vendor": "openai", "start_ms": …, "end_ms": … }]`
library;

import 'dart:convert';

import 'package:flutter/services.dart';

class UsageSession {
  const UsageSession({required this.vendor, required this.start, required this.end});
  final String vendor;
  final DateTime start;
  final DateTime end;
}

class UsageChannel {
  static const _channel = MethodChannel('ai_water/usage');

  Future<bool> hasPermission() async {
    try {
      return (await _channel.invokeMethod<bool>('hasPermission')) ?? false;
    } on MissingPluginException {
      return false; // tests, unsupported platform
    }
  }

  /// Opens the system's Usage Access settings page.
  Future<void> openSettings() => _channel.invokeMethod('openSettings');

  /// AI-app sessions overlapping [since, until). Returned whole; the caller clips them.
  /// **Null means the read failed** (permission revoked mid-way, platform error), which the
  /// caller must treat differently from "no sessions": the window has not been read, so the
  /// cursor must not move past it.
  Future<List<UsageSession>?> sessions(DateTime since, DateTime until) async {
    try {
      final raw = await _channel.invokeMethod<String>('sessions', {
        'since_ms': since.millisecondsSinceEpoch,
        'until_ms': until.millisecondsSinceEpoch,
      });
      if (raw == null) return null;
      final out = <UsageSession>[];
      for (final item in jsonDecode(raw) as List) {
        try {
          final m = item as Map<String, dynamic>;
          out.add(UsageSession(
            vendor: m['vendor'] as String,
            start: DateTime.fromMillisecondsSinceEpoch((m['start_ms'] as num).toInt()),
            end: DateTime.fromMillisecondsSinceEpoch((m['end_ms'] as num).toInt()),
          ));
        } catch (_) {
          // a malformed row is dropped, never surfaced
        }
      }
      return out;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
