/// About — the prototype's `#s-about`, at contract 15.
///
/// This copy is the product owner's, word for word. It is the only screen whose job is to make
/// someone care, so it is not paraphrased, shortened or "improved" here. The one change ever made
/// to it was "exact" → "estimated", which was a correctness fix.
library;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
          children: [
            Text('Sipcount · See what your AI drinks.'.toUpperCase(),
                style: const TextStyle(
                    color: SipColors.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            const SizedBox(height: 26),

            const _H('The cloud is on the ground'),
            const _P('AI feels like magic. It runs on servers that get very hot, and the cheapest '
                'way to cool them is to evaporate fresh water — millions of litres of it, every '
                'day, in real places.'),

            const _H('You already check your screen time'),
            const _P('This is the same idea for your prompts. We turn data-centre arithmetic into '
                'a number you can picture: a glass, a bottle, a shower.'),

            const _H('What it’s for'),
            const _P('Not guilt. Just knowing — and knowing changes small things:'),
            const SizedBox(height: 4),
            const _Goal(bold: 'Shorter questions, shorter answers.', rest: ' Most of the water goes into the reply.'),
            const _Goal(bold: 'A lighter model', rest: ' handles everyday things for about a fifth of the water.'),
            const _Goal(
                bold: 'Enough people watching',
                rest: ' is how the companies building the servers end up answering for them.'),

            const SizedBox(height: 26),
            const Text('Every prompt has a price. Now you can see yours.',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, height: 1.45)),

            const SizedBox(height: 18),
            const Text(
              'Every figure here is an estimate built from published research (Li et al. 2023; '
              'WRI 2020; LBNL 2024; vendor disclosures 2025) — see Settings → How the number is '
              'worked out.',
              style: TextStyle(color: SipColors.muted, fontSize: 11.5, height: 1.6),
            ),
          ],
        ),
      );
}

class _H extends StatelessWidget {
  const _H(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, height: 1.3)),
      );
}

class _P extends StatelessWidget {
  const _P(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(color: SipColors.muted, fontSize: 14, height: 1.75));
}

/// One of the three things knowing changes. The opening phrase carries the weight, so it is white
/// and the rest is muted — the emphasis is part of the copy, not styling applied over it.
class _Goal extends StatelessWidget {
  const _Goal({required this.bold, required this.rest});
  final String bold;
  final String rest;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(top: 7, right: 10),
            child: SizedBox(width: 5, height: 5, child: DecoratedBox(
                decoration: BoxDecoration(color: SipColors.good, shape: BoxShape.circle))),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: bold, style: const TextStyle(color: SipColors.text, fontWeight: FontWeight.w700)),
                TextSpan(text: rest, style: const TextStyle(color: SipColors.muted)),
              ]),
              style: const TextStyle(fontSize: 14, height: 1.7),
            ),
          ),
        ]),
      );
}
