/// THE APP ALWAYS REACHES ITS FIRST SCREEN (I-74).
///
/// Build 30 froze on the launch logo on Madhur's phone. Nothing in 300+ assertions could see it,
/// because nothing started the app the way a phone does: constants from the asset bundle, stored
/// days from a previous build, the Android bridge answering — or not. These tests do exactly
/// that, with the bridge healthy, missing, and broken, and with data written by the previous
/// build. Every one of them must end with something on screen.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_water/main.dart';
import 'package:ai_water/features/calculation_engine/data/aggregate_store.dart';
import 'package:ai_water/features/tracking/application/tracker.dart';

/// The two Android channels, by name — the same names the real code uses.
const _usage = MethodChannel('ai_water/usage');
const _control = MethodChannel('ai_water/listener_control');
/// The event stream's listen/cancel calls travel on a MethodChannel of the same name.
const _events = MethodChannel('ai_water/prompt_events');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// A phone that has already answered the age question (so the shell, not the intro, shows) and
  /// carries one day written by build 29 — the shape before estimate mode existed.
  final yesterday = AggregateStore.dayKey(DateTime.now().subtract(const Duration(days: 1)));
  Map<String, Object> build29Prefs() => {
        'sipcount.age_tier': 18,
        'sipcount.installed_at': '2026-10-01',
        'sipcount.days.v1': jsonEncode({
          yesterday: {
            'n': 3, 's1': 0.57, 's2': 3.25, 'wh': 0.9,
            'tiers': {'standard': 3.82}, 'tasks': {'text': 3.82},
            'vendors': {'openai': 3.82}, 'vendorN': {'openai': 3},
          },
        }),
      };

  void bridge(MethodChannel ch, Future<Object?> Function(MethodCall) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(ch, handler);
  }

  /// "No Android here": the reply production code gets on a platform without the bridge. In a
  /// test an UN-mocked channel never answers at all, so this has to be said explicitly.
  void noBridge(MethodChannel ch) => bridge(ch, (call) async => throw MissingPluginException());

  setUp(() {
    // the event stream must always acknowledge 'listen', or EventChannel reports an error
    bridge(_events, (call) async => null);
  });

  tearDown(() {
    for (final ch in [_usage, _control, _events]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(ch, null);
    }
  });

  group('Tracker.start() completes', () {
    testWidgets('with no Android bridge at all (how tests and unsupported platforms look)', (tester) async {
      SharedPreferences.setMockInitialValues(build29Prefs());
      noBridge(_control);
      noBridge(_usage);
      final t = await Tracker.start();
      expect(t.startupNotes, isEmpty, reason: t.startupNotes.join('; '));
      await t.refreshListenerState();
      expect(t.listenerEnabled, isFalse);
      expect(t.usageEnabled, isFalse);
      // the day written by the previous build is still there, untouched
      expect(t.sumPrompts(7), 3);
      expect(t.sumMl(7), closeTo(3.82, 1e-9));
    });

    testWidgets('with a healthy bridge that grants both permissions and returns usage', (tester) async {
      SharedPreferences.setMockInitialValues(build29Prefs());
      bridge(_control, (call) async => switch (call.method) {
            'isEnabled' => true,
            'drainPending' => <String>[],
            _ => null,
          });
      // a session safely inside today, so the test cannot straddle midnight
      final now = DateTime.now();
      final sessionStart = DateTime(now.year, now.month, now.day, now.hour > 0 ? now.hour - 1 : 0);
      bridge(_usage, (call) async => switch (call.method) {
            'hasPermission' => true,
            'sessions' => jsonEncode([
                {
                  'vendor': 'google',
                  'start_ms': sessionStart.millisecondsSinceEpoch,
                  'end_ms': sessionStart.add(const Duration(minutes: 10)).millisecondsSinceEpoch,
                }
              ]),
            _ => null,
          });
      final t = await Tracker.start();
      await t.refreshListenerState();
      expect(t.startupNotes, isEmpty, reason: t.startupNotes.join('; '));
      expect(t.listenerEnabled, isTrue);
      expect(t.usageEnabled, isTrue);
      // ten minutes of Gemini became an estimate on today, and the card will say so
      expect(t.today.estimatedPrompts, closeTo(5, 1e-6));
      expect(t.todayHasEstimate, isTrue);
    });

    testWidgets('with a bridge that throws on every call — the fault that froze build 30', (tester) async {
      SharedPreferences.setMockInitialValues(build29Prefs());
      bridge(_control, (call) async => throw PlatformException(code: 'boom', message: 'native failure'));
      bridge(_usage, (call) async => throw PlatformException(code: 'boom', message: 'native failure'));
      final t = await Tracker.start();
      await t.refreshListenerState();
      expect(t.listenerEnabled, isFalse);
      expect(t.usageEnabled, isFalse);
      expect(t.sumPrompts(7), 3, reason: 'a broken bridge must not lose stored days');
    });

    testWidgets('with events queued by the previous build, in its wire shape', (tester) async {
      SharedPreferences.setMockInitialValues(build29Prefs());
      bridge(_control, (call) async => switch (call.method) {
            'isEnabled' => false,
            'drainPending' => <String>[
                jsonEncode({
                  'v': 1, 'source': 'android_a11y', 'vendor': 'anthropic', 'model_hint': null,
                  'task': 'text', 'char_count': 200, 'attachment_count': 0,
                  'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
                }),
                'not json at all',
              ],
            _ => null,
          });
      final t = await Tracker.start();
      expect(t.today.promptCount, 1);
      expect(t.startupNotes, isEmpty, reason: t.startupNotes.join('; '));
    });

    testWidgets('on a brand-new install with nothing stored', (tester) async {
      SharedPreferences.setMockInitialValues({});
      noBridge(_control);
      noBridge(_usage);
      final t = await Tracker.start();
      expect(t.introSeen, isFalse);
      expect(t.today.totalMl, 0);
      expect(t.unlockedCharacters, ['plant']);
    });
  });

  group('the first screen', () {
    testWidgets('appears once the tracker is up', (tester) async {
      SharedPreferences.setMockInitialValues(build29Prefs());
      noBridge(_control);
      noBridge(_usage);
      final t = await Tracker.start();
      await tester.pumpWidget(SipcountBoot(start: () async => t));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Sipcount'), findsWidgets, reason: 'the Today screen header');
      expect(find.byType(StartupFailed), findsNothing);
    });

    testWidgets('is an error screen with the reason, never a frozen logo, when start-up throws', (tester) async {
      await tester.pumpWidget(SipcountBoot(start: () async => throw StateError('constants file unreadable')));
      await tester.pump();
      expect(find.byType(StartupFailed), findsOneWidget);
      expect(find.text('Sipcount could not start'), findsOneWidget);
      expect(find.textContaining('constants file unreadable'), findsOneWidget);
    });

    testWidgets('is an error screen when start-up hangs', (tester) async {
      final never = Completer<Tracker>();
      await tester.pumpWidget(SipcountBoot(start: () => never.future, startupTimeout: const Duration(seconds: 2)));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(StartupFailed), findsOneWidget);
      expect(find.textContaining('TimeoutException'), findsOneWidget);
    });
  });
}
