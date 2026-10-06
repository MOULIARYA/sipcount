/// Spike only (I-60) — not part of the shipping app.
///
/// One question: can a phone resolve an individual prompt from per-app byte counters, with no
/// VpnService? If it can, Android needs neither a tunnel nor the accessibility service — and the
/// Play Protect block that stops people installing the APK goes with it.
///
/// Reads byte totals. No packets, no hostnames, nothing typed.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';

class ProbePage extends StatefulWidget {
  const ProbePage({super.key});
  @override
  State<ProbePage> createState() => _ProbePageState();
}

class _ProbePageState extends State<ProbePage> {
  static const _ch = MethodChannel('ai_water/probe');

  bool _permitted = false;
  bool _running = false;
  bool _capped = false;
  int _samples = 0;
  List<String> _apps = const [];
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _refresh();
    // A row count frozen during a ten-minute run reads as "it is broken"; it is not, we simply
    // never asked again.
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final permitted = await _ch.invokeMethod<bool>('hasPermission') ?? false;
      final apps = (await _ch.invokeMethod<List<dynamic>>('apps') ?? const []).cast<String>();
      final status = (await _ch.invokeMethod<Map<dynamic, dynamic>>('status') ?? {});
      if (!mounted) return;
      setState(() {
        _permitted = permitted;
        _apps = apps;
        _running = status['running'] == true;
        _samples = (status['samples'] as int?) ?? 0;
        _capped = status['capped'] == true;
        _error = status['error'] as String?;
      });
    } on PlatformException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _toggle() async {
    if (_running) {
      await _ch.invokeMethod('stop');
    } else {
      final ok = await _ch.invokeMethod<bool>('start') ?? false;
      if (!ok && mounted) {
        setState(() => _error = 'Could not start — check usage access is granted.');
        return;
      }
    }
    await _refresh();
  }

  Future<void> _copy() async {
    final csv = await _ch.invokeMethod<String>('dump') ?? '';
    await Clipboard.setData(ClipboardData(text: csv));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Copied $_samples rows — paste them into the chat')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Sensor probe')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              const Text(
                'Can this phone tell one prompt from the next, without routing your traffic '
                'through anything?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'It reads how many bytes each AI app has sent and received, once a second. '
                'No packets, no addresses, nothing you type — it could not see your prompt if it tried.',
                style: TextStyle(color: SipColors.muted, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 20),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: SipColors.danger)),
                const SizedBox(height: 12),
              ],
              _Row(label: 'Usage access', value: _permitted ? 'granted' : 'not granted yet'),
              _Row(label: 'AI apps found', value: _apps.isEmpty ? 'none' : _apps.join(', ')),
              _Row(label: 'Recording', value: _running ? 'yes' : 'no'),
              _Row(label: 'Rows recorded', value: _capped ? '$_samples (full)' : '$_samples'),
              const SizedBox(height: 20),
              if (!_permitted)
                FilledButton(
                  onPressed: () async => _ch.invokeMethod('openUsageAccess'),
                  child: const Text('Grant usage access'),
                ),
              if (_permitted) ...[
                FilledButton(
                  onPressed: _toggle,
                  child: Text(_running ? 'Stop recording' : 'Start recording'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(onPressed: _samples == 0 ? null : _copy, child: const Text('Copy rows')),
              ],
              const SizedBox(height: 24),
              const Text('What to do', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text(
                '1. Start recording. A notification appears and stays — that is deliberate: Android '
                'would freeze the counting without it, and you should be able to see that something '
                'is sampling.\n'
                '2. Open ChatGPT (or Claude, or Gemini) and send five or six prompts over about ten '
                'minutes — some short, one that produces a long answer, and leave a quiet minute or '
                'two between a couple of them.\n'
                '3. Note roughly when you sent each one.\n'
                '4. Come back, stop, copy the rows, and send them over with your rough timings.\n\n'
                'Either answer settles the design. If the counts move second by second, the phone can '
                'do this with no traffic routing at all. If they move in big occasional jumps, the '
                'counters are too coarse and the tunnel is genuinely needed — worth knowing before '
                'building one.',
                style: TextStyle(color: SipColors.muted, fontSize: 13, height: 1.55),
              ),
            ],
          ),
        ),
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: SipColors.muted)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );
}
