/// The first thing anyone sees: two facts, the brand, and one question.
///
/// The age question exists for two reasons and no others: sharing is off under 13, and syncing
/// across devices is off under 18. **Only the derived tier is stored — never the number typed.**
/// That is why this asks for a band rather than a date of birth: a date of birth would be personal
/// data we would then have to justify keeping, and we do not want it.
library;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../tracking/application/tracker.dart';

class IntroPage extends StatelessWidget {
  const IntroPage({super.key, required this.tracker});
  final Tracker tracker;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 28, 26, 26),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(color: SipColors.good, shape: BoxShape.circle),
                  child: const Center(child: Text('💧', style: TextStyle(fontSize: 20))),
                ),
                const SizedBox(width: 12),
                Text('Sipcount',
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.5)),
              ]),
              const Spacer(),

              // Two facts, not three. The point is to land one idea, not to brief anyone.
              const _Stat(
                figure: '700,000 litres',
                line: 'of clean water evaporated to train a single AI model.',
              ),
              const SizedBox(height: 22),
              const _Stat(
                figure: '41 billion litres',
                line: 'of water used by Google in 2025 — up 34% in a single year.',
              ),

              const Spacer(),
              const Text('See what your AI drinks.',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.3)),
              const SizedBox(height: 10),
              const Text(
                'One question first, so the app knows what to show you. Your answer is not stored '
                '— only whether you are over 13 and over 18.',
                style: TextStyle(color: SipColors.muted, fontSize: 13, height: 1.55),
              ),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: _AgeButton(label: 'Under 13', age: 12, tracker: tracker)),
                const SizedBox(width: 10),
                Expanded(child: _AgeButton(label: '13 to 17', age: 13, tracker: tracker)),
                const SizedBox(width: 10),
                Expanded(child: _AgeButton(label: '18 or over', age: 18, tracker: tracker)),
              ]),
            ]),
          ),
        ),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.figure, required this.line});
  final String figure;
  final String line;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(figure,
            style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800, color: SipColors.good, letterSpacing: -1)),
        const SizedBox(height: 4),
        Text(line, style: const TextStyle(color: SipColors.muted, fontSize: 14, height: 1.5)),
      ]);
}

class _AgeButton extends StatelessWidget {
  const _AgeButton({required this.label, required this.age, required this.tracker});
  final String label;
  final int age;
  final Tracker tracker;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: () => tracker.setAge(age),
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
        child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5)),
      );
}
