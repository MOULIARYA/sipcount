import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../calculation_engine/domain/model_profile.dart';
import '../application/tracker.dart';

String fmtMl(double ml) => ml >= 100 ? ml.round().toString() : ml >= 10 ? ml.toStringAsFixed(1) : ml.toStringAsFixed(2);

String equivLabel(String key) => switch (key) {
      'sip' => 'sips',
      'espresso_cup' => 'espresso cups',
      'coffee_cup' => 'cups of coffee',
      'water_bottle' => 'water bottles',
      _ => key,
    };

class TodayPage extends StatelessWidget {
  const TodayPage({super.key, required this.tracker});
  final Tracker tracker;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: tracker,
        builder: (context, _) {
          final t = tracker.today;
          final budget = tracker.budgetMl;
          final double pct = budget == 0 ? 0.0 : (t.totalMl / budget).clamp(0.0, 1.0).toDouble();
          final over = t.totalMl > budget;
          final eq = tracker.equivalence.best(t.totalMl);
          final week = tracker.lastDays(7);
          final weekMax = week.fold<double>(0, (a, d) => math.max(a, d.totalMl));

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Row(children: [
                  Text('Sipcount', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.5)),
                  const Spacer(),
                  _Pill(text: tracker.listenerEnabled ? 'Listening' : 'Paused', color: tracker.listenerEnabled ? SipColors.good : SipColors.muted),
                ]),
                const SizedBox(height: 4),
                Text('Water your AI prompts used today', style: TextStyle(color: SipColors.muted)),
                const SizedBox(height: 20),
                if (!tracker.listenerEnabled) ...[
                  _EnableCard(onTap: tracker.openEnableSettings),
                  const SizedBox(height: 16),
                ],
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(children: [
                      SizedBox(height: 170, child: CustomPaint(painter: _DropletPainter(pct), child: const SizedBox.expand())),
                      const SizedBox(height: 12),
                      Text.rich(TextSpan(children: [
                        TextSpan(text: fmtMl(t.totalMl), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800, letterSpacing: -1.5)),
                        const TextSpan(text: ' mL', style: TextStyle(fontSize: 20, color: SipColors.muted, fontWeight: FontWeight.w600)),
                      ])),
                      Text(
                        t.promptCount == 0 ? 'No prompts counted yet' : '≈ ${eq.count.toStringAsFixed(eq.count >= 10 ? 0 : 1)} ${equivLabel(eq.label)} · ${t.promptCount} prompt${t.promptCount == 1 ? '' : 's'}',
                        style: const TextStyle(color: SipColors.muted),
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: SipColors.surface2, color: over ? SipColors.warn : SipColors.water),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        over ? 'Over budget by ${fmtMl(t.totalMl - budget)} mL (budget $budget mL)' : '${(pct * 100).round()}% of your $budget mL daily budget',
                        style: TextStyle(color: over ? SipColors.warn : SipColors.muted, fontSize: 13),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                if (tracker.lastNudge != null) _Nudge(text: tracker.lastNudge!),
                if (tracker.lastNudge != null) const SizedBox(height: 12),
                if (tracker.lastEventAt != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Last counted: ${tracker.lastVendor} · ${tracker.lastEventAt!.hour.toString().padLeft(2, '0')}:${tracker.lastEventAt!.minute.toString().padLeft(2, '0')} · ${fmtMl(tracker.lastEstimate?.totalMl ?? 0)} mL',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: SipColors.muted, fontSize: 12),
                    ),
                  ),
                Row(children: [
                  Expanded(child: _Stat(label: 'On-site cooling', value: '${fmtMl(t.scope1Ml)} mL', sub: 'Scope 1')),
                  const SizedBox(width: 12),
                  Expanded(child: _Stat(label: 'Power generation', value: '${fmtMl(t.scope2Ml)} mL', sub: 'Scope 2')),
                ]),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Text('Last 7 days', style: TextStyle(fontWeight: FontWeight.w700)),
                        const Spacer(),
                        Text('${fmtMl(tracker.sumMl(7))} mL · ${tracker.sumPrompts(7)} prompts', style: const TextStyle(color: SipColors.muted, fontSize: 13)),
                      ]),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 72,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (var i = 0; i < week.length; i++) ...[
                              Expanded(
                                child: Container(
                                  height: weekMax == 0 ? 4.0 : math.max(4.0, 72 * week[i].totalMl / weekMax),
                                  decoration: BoxDecoration(
                                    color: i == week.length - 1 ? SipColors.water : SipColors.waterDeep.withValues(alpha: .55),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                              if (i < week.length - 1) const SizedBox(width: 6),
                            ],
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                _DemoRow(tracker: tracker),
                const SizedBox(height: 12),
                const Text(
                  'Nothing you type is stored or sent anywhere. Sipcount only keeps daily totals on this phone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: SipColors.muted, fontSize: 12),
                ),
              ],
            ),
          );
        },
      );
}

class _EnableCard extends StatelessWidget {
  const _EnableCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Turn on counting', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 6),
            const Text(
              'Sipcount needs the Accessibility permission to notice when you tap Send in ChatGPT, Claude, Gemini or Chrome. It counts characters and throws the text away instantly.',
              style: TextStyle(color: SipColors.muted, height: 1.35),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onTap, child: const Text('Open Accessibility settings')),
          ]),
        ),
      );
}

class _Nudge extends StatelessWidget {
  const _Nudge({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: SipColors.water.withValues(alpha: .12), borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          const Icon(Icons.tips_and_updates_outlined, color: SipColors.water),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(height: 1.3))),
        ]),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.sub});
  final String label, value, sub;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(sub, style: const TextStyle(color: SipColors.muted, fontSize: 11, letterSpacing: .8)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(color: SipColors.muted, fontSize: 12)),
          ]),
        ),
      );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withValues(alpha: .15), borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      );
}

/// Lets the demo work before the Accessibility permission is granted.
class _DemoRow extends StatelessWidget {
  const _DemoRow({required this.tracker});
  final Tracker tracker;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Try it (demo)', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Adds a fake prompt so you can see the counter move.', style: TextStyle(color: SipColors.muted, fontSize: 12)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton(onPressed: () => tracker.simulate(charCount: 400), child: const Text('Standard prompt')),
              OutlinedButton(onPressed: () => tracker.simulate(modelHint: 'o3', charCount: 400), child: const Text('Reasoning')),
              OutlinedButton(onPressed: () => tracker.simulate(vendor: 'google', modelHint: 'flash', charCount: 400), child: const Text('Lightweight')),
              OutlinedButton(onPressed: () => tracker.simulate(task: TaskType.image), child: const Text('Image')),
            ]),
          ]),
        ),
      );
}

class _DropletPainter extends CustomPainter {
  _DropletPainter(this.fill);
  final double fill; // 0..1

  Path _drop(Size s) {
    final w = s.width, h = s.height;
    final cx = w / 2;
    final r = math.min(w, h) * .33;
    final cy = h - r - 4;
    final p = Path()..moveTo(cx, 4);
    p.cubicTo(cx + r * .05, h * .30, cx + r, cy - r * .55, cx + r, cy);
    p.arcToPoint(Offset(cx - r, cy), radius: Radius.circular(r), clockwise: true, largeArc: true);
    p.cubicTo(cx - r, cy - r * .55, cx - r * .05, h * .30, cx, 4);
    p.close();
    return p;
  }

  @override
  void paint(Canvas c, Size s) {
    final path = _drop(s);
    c.drawPath(path, Paint()..color = SipColors.surface2);
    c.save();
    c.clipPath(path);
    final top = s.height * (1 - fill);
    c.drawRect(Rect.fromLTWH(0, top, s.width, s.height - top), Paint()..shader = const LinearGradient(colors: [SipColors.water, SipColors.waterDeep], begin: Alignment.topCenter, end: Alignment.bottomCenter).createShader(Rect.fromLTWH(0, top, s.width, s.height - top)));
    c.restore();
    c.drawPath(path, Paint()..color = SipColors.line..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(_DropletPainter old) => old.fill != fill;
}
