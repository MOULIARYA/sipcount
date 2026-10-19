import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/sipcount_app.dart';
import 'app/theme.dart';
import 'features/tracking/application/tracker.dart';

/// THE RULE OF START-UP (I-74). Build 30 froze on the launch logo: everything was awaited before
/// `runApp`, so one failing Android call meant no first frame, ever, and nothing on screen to say
/// why. Now:
///   1. the first frame does not wait for anything that can fail slowly or at all;
///   2. a failure on the way to it shows a screen with the actual error, never a frozen logo;
///   3. the Android-side checks (permissions, usage history) run *after* the screen exists.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  } catch (_) {
    // cosmetic; never worth a blank screen
  }
  runApp(const SipcountBoot());
}

/// Starts the tracker while a plain screen is already showing, then swaps in the app. A start
/// that takes longer than [startupTimeout] or throws shows [StartupFailed] with the reason.
class SipcountBoot extends StatefulWidget {
  const SipcountBoot({super.key, this.start, this.startupTimeout = const Duration(seconds: 15)});

  /// Injected by tests; the real app starts the real tracker.
  final Future<Tracker> Function()? start;
  final Duration startupTimeout;

  @override
  State<SipcountBoot> createState() => _SipcountBootState();
}

class _SipcountBootState extends State<SipcountBoot> {
  Tracker? _tracker;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      final t = await (widget.start ?? Tracker.start)().timeout(widget.startupTimeout);
      if (!mounted) return;
      setState(() => _tracker = t);
      // Android-side checks only once something is on screen. Each is guarded inside.
      unawaited(t.refreshListenerState());
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _tracker;
    if (t != null) return SipcountApp(tracker: t);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: sipcountTheme(),
      themeMode: ThemeMode.dark,
      home: _error == null ? const _Starting() : StartupFailed(error: _error!),
    );
  }
}

class _Starting extends StatelessWidget {
  const _Starting();
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: SipColors.water)),
      );
}

/// Shown instead of a frozen logo. Plain words first, the raw error underneath so a screenshot
/// is enough to diagnose it.
class StartupFailed extends StatelessWidget {
  const StartupFailed({super.key, required this.error});
  final Object error;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Sipcount could not start', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              const Text(
                'Your totals are safe on this phone. Please screenshot this screen and send it to Madhur.',
                style: TextStyle(color: SipColors.muted, height: 1.4),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText('$error', style: const TextStyle(fontSize: 12, color: SipColors.muted, fontFamily: 'monospace')),
                ),
              ),
            ]),
          ),
        ),
      );
}
