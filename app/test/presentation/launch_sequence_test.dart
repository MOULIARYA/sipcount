/// The opening sequence actually moves.
///
/// Written after the launch sequence shipped as a single static screen — with statistics I had
/// invented rather than the prototype's. Madhur noticed because he remembered the prototype's text
/// changing. No test could have told him: nothing we had pumped a widget or advanced a clock.
///
/// So this asserts the two things that were wrong: that the cards change over time, and that the
/// figures are the real published ones with their sources.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_water/features/intro/presentation/intro_page.dart';

void main() {
  Future<void> show(WidgetTester tester, {required VoidCallback onDone}) =>
      tester.pumpWidget(MaterialApp(home: LaunchSequence(onDone: onDone)));

  group('three cards, in order, on a timer', () {
    testWidgets('it opens on the first figure', (tester) async {
      await show(tester, onDone: () {});

      // The label is static, so it is there on the first frame.
      expect(find.textContaining('to train one AI model'), findsOneWidget);
      // The second card must not be on screen yet.
      expect(find.textContaining('data centres'), findsNothing);

      // The figure COUNTS UP from zero, so on the first frame it reads "0". Asserting the final
      // value immediately is what failed in CI — my own test ignored the animation I had written.
      // Advance past the 1,200 ms count-up, while staying inside this card's 3,000 ms.
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.textContaining('700,000'), findsOneWidget);

      await tester.pumpAndSettle();
    });

    testWidgets('the figure starts at zero and climbs — a number that is simply there is skipped',
        (tester) async {
      await show(tester, onDone: () {});
      expect(find.text('700,000'), findsNothing, reason: 'it appeared fully formed, without counting');
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.text('700,000'), findsOneWidget, reason: 'it never reached the real figure');
      await tester.pumpAndSettle();
    });

    testWidgets('the second figure replaces it, which is what was broken', (tester) async {
      await show(tester, onDone: () {});
      await tester.pump(Duration(milliseconds: LaunchSequence.durationsMs[0] + 50));
      await tester.pump(const Duration(seconds: 2));   // let the counter finish
      expect(find.textContaining('data centres'), findsOneWidget);
      expect(find.textContaining('to train one AI model'), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('then the brand, then it hands over', (tester) async {
      var done = false;
      await show(tester, onDone: () => done = true);
      await tester.pump(Duration(milliseconds: LaunchSequence.durationsMs[0] + 50));
      await tester.pump(Duration(milliseconds: LaunchSequence.durationsMs[1] + 50));
      expect(find.text('Sipcount'), findsOneWidget);
      expect(find.text('Now see your share.'), findsOneWidget);
      expect(done, isFalse, reason: 'it finished before the last card had its time');

      await tester.pump(Duration(milliseconds: LaunchSequence.durationsMs[2] + 50));
      expect(done, isTrue, reason: 'the sequence never handed over to the age question');
      await tester.pumpAndSettle();
    });

    testWidgets('Skip hands over immediately', (tester) async {
      var done = false;
      await show(tester, onDone: () => done = true);
      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(done, isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets('it does not run on past the last card', (tester) async {
      var calls = 0;
      await show(tester, onDone: () => calls++);
      for (final ms in LaunchSequence.durationsMs) {
        await tester.pump(Duration(milliseconds: ms + 50));
      }
      await tester.pump(const Duration(seconds: 10));
      expect(calls, 1, reason: 'the timer kept firing after the sequence ended');
      await tester.pumpAndSettle();
    });
  });

  group('the figures are the published ones, not invented', () {
    testWidgets('700,000 litres is attributed to Li et al.', (tester) async {
      await show(tester, onDone: () {});
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('GPT-3 · Li et al., 2023'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('66 billion litres is attributed to LBNL', (tester) async {
      await show(tester, onDone: () {});
      await tester.pump(Duration(milliseconds: LaunchSequence.durationsMs[0] + 50));
      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining('66'), findsOneWidget);
      expect(find.text('Lawrence Berkeley National Laboratory, 2024'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('every card cites a source', (tester) async {
      // A figure with no source is the shape of the mistake I made: a number that looks
      // authoritative and came from nowhere.
      await show(tester, onDone: () {});
      for (var card = 0; card < 2; card++) {
        await tester.pump(const Duration(seconds: 2));
        expect(find.textContaining(', 20'), findsWidgets, reason: 'card $card has no dated source');
        await tester.pump(Duration(milliseconds: LaunchSequence.durationsMs[card] + 50));
      }
      await tester.pumpAndSettle();
    });
  });
}
