/// The opening: a three-card launch sequence, then the age question.
///
/// I had collapsed these into one static screen, with statistics I had invented. Both wrong. The
/// prototype plays two figures and the brand — counting up, ~8.2 seconds, skippable — and only
/// then asks the age. The sequence is the argument: the scale first, your share second. A static
/// screen makes the figures decoration.
///
/// Figures and copy are the prototype's, verbatim, with their sources.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../calculation_engine/domain/plain_words.dart';
import '../../tracking/application/tracker.dart';

class _Card {
  const _Card({required this.figure, this.suffix = '', required this.label, required this.source});
  final int figure;
  final String suffix;
  final String label;
  final String source;
}

const List<_Card> _cards = [
  _Card(
    figure: 700000,
    label: 'litres of fresh water evaporated to train one AI model.',
    source: 'GPT-3 · Li et al., 2023',
  ),
  _Card(
    figure: 66,
    suffix: ' billion',
    label: 'litres of water consumed on-site by US data centres in 2023.',
    source: 'Lawrence Berkeley National Laboratory, 2024',
  ),
];

/// Two figures, then the brand. The last card is shorter because it has nothing to read.
const List<int> _durationsMs = [3000, 3000, 2200];

class IntroPage extends StatefulWidget {
  const IntroPage({super.key, required this.tracker});
  final Tracker tracker;

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> {
  int _stage = 0;
  bool _asking = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: _durationsMs[_stage]), () {
      if (!mounted) return;
      if (_stage >= _durationsMs.length - 1) {
        setState(() => _asking = true);
      } else {
        setState(() => _stage++);
        _schedule();
      }
    });
  }

  void _skip() {
    _timer?.cancel();
    setState(() => _asking = true);
  }

  @override
  Widget build(BuildContext context) =>
      _asking ? _AgeScreen(tracker: widget.tracker) : _Launch(stage: _stage, onSkip: _skip);
}

class _Launch extends StatelessWidget {
  const _Launch({required this.stage, required this.onSkip});
  final int stage;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final brand = stage >= _cards.length;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 16, 26, 26),
          child: Column(children: [
            Row(children: [
              // Progress, one bar per card, so nobody wonders how long this lasts.
              for (var i = 0; i < _durationsMs.length; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i == _durationsMs.length - 1 ? 0 : 6),
                    child: _Bar(filled: i < stage, active: i == stage, durationMs: _durationsMs[i]),
                  ),
                ),
              const SizedBox(width: 12),
              TextButton(onPressed: onSkip, child: const Text('Skip')),
            ]),
            Expanded(
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 450),
                  child: brand
                      ? Column(
                          key: const ValueKey('brand'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text('Sipcount',
                                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                      fontWeight: FontWeight.w800, letterSpacing: -1.5)),
                              const SizedBox(width: 8),
                              const Text('💧', style: TextStyle(fontSize: 26)),
                            ]),
                            const SizedBox(height: 10),
                            const Text('Now see your share.',
                                style: TextStyle(color: SipColors.muted, fontSize: 15)),
                          ],
                        )
                      : _Figure(key: ValueKey(stage), card: _cards[stage]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.filled, required this.active, required this.durationMs});
  final bool filled;
  final bool active;
  final int durationMs;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: Container(
          height: 3,
          color: SipColors.surface2,
          child: Align(
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: filled ? 1 : (active ? 1 : 0)),
              duration: active ? Duration(milliseconds: durationMs) : Duration.zero,
              curve: Curves.linear,
              builder: (_, v, __) => FractionallySizedBox(
                widthFactor: v.clamp(0.0, 1.0),
                child: Container(color: SipColors.good),
              ),
            ),
          ),
        ),
      );
}

/// The figure counts up rather than appearing. A number that climbs is read; a number that is
/// simply there is skipped.
class _Figure extends StatelessWidget {
  const _Figure({super.key, required this.card});
  final _Card card;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: card.figure.toDouble()),
        duration: reduced ? Duration.zero : const Duration(milliseconds: 1200),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => Text(
          '${fmt(v.round(), 0)}${card.suffix}',
          style: const TextStyle(
              fontSize: 44, fontWeight: FontWeight.w800, color: SipColors.good, letterSpacing: -2, height: 1.1),
        ),
      ),
      const SizedBox(height: 10),
      Text(card.label, style: const TextStyle(fontSize: 17, height: 1.5)),
      const SizedBox(height: 14),
      Text(card.source, style: const TextStyle(color: SipColors.muted, fontSize: 12)),
    ]);
  }
}

/// The age question.
///
/// Precise on purpose: with syncing available to 18+, "nothing leaves this device" is not true
/// unconditionally. What is always true is that nothing you type is ever kept — so that is what
/// the copy promises, and only the derived mode is stored, never the number.
class _AgeScreen extends StatefulWidget {
  const _AgeScreen({required this.tracker});
  final Tracker tracker;
  @override
  State<_AgeScreen> createState() => _AgeScreenState();
}

class _AgeScreenState extends State<_AgeScreen> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go() {
    final age = int.tryParse(_controller.text.trim());
    if (age == null || age < 5 || age > 120) {
      setState(() => _error = 'Enter an age between 5 and 120.');
      return;
    }
    widget.tracker.setAge(age);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(26, 26, 26, 26),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(color: SipColors.good, shape: BoxShape.circle),
                  child: const Center(child: Text('💧', style: TextStyle(fontSize: 28))),
                ),
                const SizedBox(height: 18),
                Text('Sipcount'.toUpperCase(),
                    style: const TextStyle(
                        color: SipColors.good, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.6)),
                const SizedBox(height: 4),
                const Text('See what your AI drinks.',
                    style: TextStyle(color: SipColors.muted, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 18),
                Text('How old are you?',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.5)),
                const SizedBox(height: 10),
                const ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 300),
                  child: Text(
                    'One question, then straight in. We keep only the mode it picks — never the '
                    'number. Nothing you type is ever stored, here or anywhere.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: SipColors.muted, fontSize: 13, height: 1.55),
                  ),
                ),
                const SizedBox(height: 20),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    autofocus: true,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                    decoration: const InputDecoration(hintText: '18', counterText: ''),
                    maxLength: 3,
                    onSubmitted: (_) => _go(),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: SipColors.danger, fontSize: 12)),
                ],
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(onPressed: _go, child: const Text('Continue')),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
}
