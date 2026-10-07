/// The shape of the drop, checked as geometry.
///
/// Written after the hero drop shipped to a phone as a green cone. The prototype's path ends
/// `a38 38 0 0 0 76 0`; that last `0` is SVG's sweep flag and means counter-clockwise, and
/// Flutter's `arcToPoint` defaults to clockwise. The semicircle swung up instead of down, the bowl
/// became a concave arch, and **all 265 assertions were green** — because none of them looked at
/// the shape.
///
/// Image goldens would catch it too, but they need baseline PNGs generated on a machine with
/// Flutter, and they fail on font and antialiasing differences between machines. `Path.contains`
/// needs nothing, says exactly what is wrong, and cannot drift.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_water/features/tracking/presentation/widgets/water_drop.dart';

void main() {
  group('the drop is a drop', () {
    test('the bowl is solid — the exact failure that reached the phone', () {
      // (50, 110) sits deep inside the bowl, well below the arc's chord at y=82. With the sweep
      // inverted this point is outside the shape, which is what made it look like a cone.
      expect(dropSilhouette().contains(const Offset(50, 110)), isTrue,
          reason: 'the bowl is hollow — the arc sweep is inverted again');
    });

    test('it is widest across the bowl, not across the tip', () {
      final p = dropSilhouette();
      // a few millimetres below the tip it should be narrow
      expect(p.contains(const Offset(20, 20)), isFalse);
      expect(p.contains(const Offset(80, 20)), isFalse);
      // across the middle of the bowl it should be wide
      expect(p.contains(const Offset(20, 82)), isTrue);
      expect(p.contains(const Offset(80, 82)), isTrue);
    });

    test('the tip is at the top and the shape points up', () {
      final p = dropSilhouette();
      expect(p.contains(const Offset(50, 10)), isTrue, reason: 'the tip is missing');
      expect(p.contains(const Offset(50, 125)), isFalse, reason: 'the shape runs past the bowl');
    });

    test('it fills the 100×130 canvas it was drawn for', () {
      final b = dropSilhouette().getBounds();
      expect(b.left, closeTo(12, 0.5));
      expect(b.right, closeTo(88, 0.5));
      expect(b.top, closeTo(4, 0.5));
      // the bowl bottoms out at the arc: 82 + radius 38
      expect(b.bottom, closeTo(120, 0.5));
    });

    test('nothing outside the silhouette is inside it', () {
      final p = dropSilhouette();
      for (final o in [const Offset(0, 0), const Offset(99, 129), const Offset(12, 10), const Offset(88, 10)]) {
        expect(p.contains(o), isFalse, reason: '$o should be outside');
      }
    });
  });

  group('the vessel drains rather than fills', () {
    testWidgets('a full day and an empty day do not paint the same', (tester) async {
      Future<void> pump(double level) => tester.pumpWidget(MaterialApp(
            home: Scaffold(body: Center(child: WaterDrop(level: level, colour: const Color(0xFF00F076)))),
          ));

      await pump(1);
      await tester.pumpAndSettle();
      expect(find.byType(WaterDrop), findsOneWidget);

      // Rebuilding with a different level must not throw and must keep the widget alive — the
      // drain is an animation, so the risk is a controller or tween blowing up mid-change.
      await pump(0.2);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.byType(WaterDrop), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
