/// The hero drop: a vessel that starts full and drains as the day's water is spent.
///
/// It uses the prototype's exact silhouette — `M50 4 C50 4 12 52 12 82 a38 38 0 0 0 76 0
/// C88 52 50 4 50 4 Z` on a 100×130 canvas — so the shape on the phone is the shape Mouli signed
/// off, not an approximation of it.
///
/// It drains rather than fills, which is the whole point: you are spending something, and the
/// mechanic only works if the vessel starts full. On every arrival it replays from full and
/// catches up over three seconds, as the prototype does.
library;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

class WaterDrop extends StatefulWidget {
  const WaterDrop({
    super.key,
    required this.level,
    required this.colour,
    this.size = const Size(124, 156),
  });

  /// 1 = untouched, 0 = empty. This is what is LEFT, not what has been used.
  final double level;
  final Color colour;
  final Size size;

  @override
  State<WaterDrop> createState() => _WaterDropState();
}

class _WaterDropState extends State<WaterDrop> {
  /// Starts full on mount so the drain is always seen, then settles to the real level.
  double _target = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _target = widget.level);
    });
  }

  @override
  void didUpdateWidget(WaterDrop old) {
    super.didUpdateWidget(old);
    if (old.level != widget.level) _target = widget.level;
  }

  @override
  Widget build(BuildContext context) {
    // Respect the system setting: someone who asked for less motion should not sit through three
    // seconds of animation every time they open the app.
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return SizedBox(
      width: widget.size.width,
      height: widget.size.height,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: _target),
        duration: reduced ? Duration.zero : const Duration(seconds: 3),
        curve: const Cubic(.22, .61, .36, 1),
        builder: (_, level, __) => CustomPaint(painter: _DropPainter(level: level, colour: widget.colour)),
      ),
    );
  }
}

/// The drop's silhouette in its own 100×130 units, exposed for tests.
///
/// An inverted arc sweep turned this shape into a cone on a real phone and nothing we had could
/// see it. `Path.contains` can — cheaper and more precise than comparing screenshots.
Path dropSilhouette() => _DropPainter.silhouette();

class _DropPainter extends CustomPainter {
  _DropPainter({required this.level, required this.colour});
  final double level;
  final Color colour;

  /// The prototype's path, transcribed verbatim in its own 100×130 user units.
  ///
  /// Public via [WaterDrop.silhouette] so a test can check the geometry. An inverted arc sweep
  /// turned this into a cone on a real phone and nothing we had could see it — `Path.contains`
  /// can, which is cheaper and more precise than a screenshot comparison.
  ///
  /// Drawn through a canvas transform rather than a `Matrix4`: the matrix helpers for translate
  /// and scale are deprecated, and their replacements take four arguments whose meaning I would
  /// have been guessing at. `Canvas.translate`/`scale` are stable, do the same job, and keep the
  /// path readable as the SVG it came from.
  static Path silhouette() => Path()
    ..moveTo(50, 4)
    ..cubicTo(50, 4, 12, 52, 12, 82)
    /* `a38 38 0 0 0 76 0` — the last 0 before the coordinates is SVG's sweep flag, and it means
       counter-clockwise. I left Flutter's `clockwise` at its default of true, which swung the
       semicircle UP instead of down: the bowl became a concave arch and the whole drop rendered as
       a green cone. Visible in the first screenshot from the phone, and invisible to every test we
       have, because none of them looks at pixels. */
    ..arcToPoint(const Offset(88, 82), radius: const Radius.circular(38), clockwise: false)
    ..cubicTo(88, 52, 50, 4, 50, 4)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final s = (size.width / 100) < (size.height / 130) ? size.width / 100 : size.height / 130;
    final path = silhouette();
    final bounds = path.getBounds();

    canvas.save();
    canvas.translate((size.width - 100 * s) / 2, (size.height - 130 * s) / 2);
    canvas.scale(s, s);

    // 1. the empty vessel
    canvas.drawPath(path, Paint()..color = SipColors.surface2);

    // 2. what is left, clipped to the silhouette and sunk by however much has been spent
    canvas.save();
    canvas.clipPath(path);
    final top = bounds.top + bounds.height * (1 - level.clamp(0.0, 1.0));
    canvas.drawRect(Rect.fromLTRB(bounds.left, top, bounds.right, bounds.bottom), Paint()..color = colour);
    canvas.restore();

    // 3. the outline on top, so the shape still reads when the vessel is nearly empty.
    // Stroke width is in user units and the canvas is scaled, so divide to keep it 1.5 device px.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 / s
        ..color = SipColors.line,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_DropPainter old) => old.level != level || old.colour != colour;
}
