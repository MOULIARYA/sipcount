/// The Today screen, ported from the prototype's `#s-today` (contract 15).
///
/// Order and copy follow the reference design deliberately: the number first, the character
/// second, the comparison line third. A few hundred millilitres is a small figure and a small
/// figure shown alone argues against caring — the character and the scale line are what make it
/// mean something, so they are not decoration and they are not optional.
library;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../calculation_engine/data/constants_repository.dart';
import '../../calculation_engine/domain/plain_words.dart';
import '../application/tracker.dart';
import 'widgets/water_drop.dart';

/// Off unless a build asks for it. CI passes it for the sideloaded test APK; a store build never
/// will, so the demo controls cannot reach a user by being forgotten.
const bool _showDemo = bool.fromEnvironment('SIPCOUNT_DEMO');

Color zoneColour(String zone) => switch (zone) {
      'amber' => SipColors.warn,
      'red' => SipColors.danger,
      _ => SipColors.good,
    };

class TodayPage extends StatefulWidget {
  const TodayPage({super.key, required this.tracker});
  final Tracker tracker;

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  /// The comparison line alternates between the personal one and the scale one on each visit, so
  /// neither becomes wallpaper.
  bool _altLine = false;
  WaterFact? _fact;

  @override
  void initState() {
    super.initState();
    _altLine = DateTime.now().minute.isEven;
    _fact = widget.tracker.takeFactIfDue();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tracker;
    return ListenableBuilder(
      listenable: t,
      builder: (context, _) {
        final day = t.today;
        final ml = day.totalMl;
        final pct = t.todayPct;
        final zone = t.zone;
        final colour = zoneColour(zone);
        final look = t.zoneLook;

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            children: [
              // ---- header ----------------------------------------------------------------
              Row(children: [
                Text('Sipcount',
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.5)),
                const Spacer(),
                _Pill(text: '${look.icon} ${look.label}', colour: colour),
              ]),
              const SizedBox(height: 14),

              if (!t.listenerEnabled) ...[
                _EnableCard(onTap: t.openEnableSettings),
                const SizedBox(height: 14),
              ],

              // ---- the number ------------------------------------------------------------
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(children: [
                    WaterDrop(level: (1 - pct).clamp(0.0, 1.0), colour: colour),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const _Eyebrow('Today · this device'),
                        const SizedBox(height: 2),
                        Row(crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic, children: [
                          Text(fmt(ml, ml < 10 ? 1 : 0),
                              style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w800,
                                  letterSpacing: -2, height: 1.05)),
                          const SizedBox(width: 5),
                          const Text('mL',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: SipColors.muted)),
                        ]),
                        const SizedBox(height: 10),
                        _Ring(pct: pct, zone: zone),
                        const SizedBox(height: 7),
                        Text('${(pct * 100).round()}% of ${t.budgetMl} mL used',
                            style: const TextStyle(color: SipColors.muted, fontSize: 12.5)),
                      ]),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 12),

              // ---- the character ---------------------------------------------------------
              _CharacterCard(tracker: t, colour: colour, icon: look.icon),
              const SizedBox(height: 12),

              // ---- what the number means -------------------------------------------------
              Text(
                (_altLine ? scaleLine(ml) : null) ?? opportunityCost(ml),
                style: const TextStyle(color: SipColors.muted, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 14),

              if (_fact != null) ...[
                _FactCard(fact: _fact!, onClose: () => setState(() => _fact = null)),
                const SizedBox(height: 12),
              ],

              if (t.showWatchCard) ...[
                _Notice(
                  text: 'Sipcount is watching for your prompts. Use ChatGPT, Claude or Gemini and come back.',
                  actionLabel: 'Got it',
                  onAction: t.dismissWatchCard,
                ),
                const SizedBox(height: 12),
              ] else if (t.showWidgetCard) ...[
                _Notice(
                  text: 'Add Sipcount to your home screen.',
                  actionLabel: 'Not now',
                  onAction: t.dismissWidgetCard,
                ),
                const SizedBox(height: 12),
              ],

              // ---- insights --------------------------------------------------------------
              _InsightsCard(tracker: t),
              const SizedBox(height: 12),

              // ---- analytics -------------------------------------------------------------
              _AnalyticsCard(tracker: t),
              const SizedBox(height: 16),

              if (_showDemo) ...[
                _DemoRow(tracker: t),
                const SizedBox(height: 12),
              ],

              const Text(
                'Nothing you type is stored or sent anywhere. Sipcount only keeps daily totals on this phone.',
                textAlign: TextAlign.center,
                style: TextStyle(color: SipColors.muted, fontSize: 12, height: 1.5),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------------------------

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: const TextStyle(color: SipColors.muted, fontSize: 10.5,
          fontWeight: FontWeight.w700, letterSpacing: 1.1));
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.colour});
  final String text;
  final Color colour;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: colour.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: colour.withValues(alpha: .35)),
        ),
        child: Text(text.toUpperCase(),
            style: TextStyle(color: colour, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: .8)),
      );
}

/// Never colour alone: each zone also has a texture, so the status survives colour-blindness and
/// a greyscale screenshot.
class _Ring extends StatelessWidget {
  const _Ring({required this.pct, required this.zone});
  final double pct;
  final String zone;

  @override
  Widget build(BuildContext context) {
    final colour = zoneColour(zone);
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: Container(
        height: 8,
        color: SipColors.surface2,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: pct.clamp(0.0, 1.0),
            child: zone == 'green'
                ? Container(color: colour)
                : CustomPaint(painter: _StripePainter(colour, zone == 'red' ? 45 : 135)),
          ),
        ),
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  _StripePainter(this.colour, this.degrees);
  final Color colour;
  final int degrees;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = colour);
    final dark = Paint()
      ..color = Colors.black.withValues(alpha: .45)
      ..strokeWidth = 3;
    final step = degrees == 45 ? 5.0 : 8.0;
    for (var x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), dark);
    }
  }

  @override
  bool shouldRepaint(_StripePainter old) => old.colour != colour || old.degrees != degrees;
}

class _EnableCard extends StatelessWidget {
  const _EnableCard({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Turn on counting',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            const Text(
              'Sipcount needs the Accessibility permission to notice when you tap Send in ChatGPT, '
              'Claude, Gemini or Chrome. It counts characters and throws the text away instantly.',
              style: TextStyle(color: SipColors.muted, fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: onTap, child: const Text('Open Accessibility settings')),
          ]),
        ),
      );
}

/// The ecosystem card. The art is Mouli's five frames; the state word and the line come from the
/// shared character definitions, so the phone says what the prototype says.
class _CharacterCard extends StatelessWidget {
  const _CharacterCard({required this.tracker, required this.colour, required this.icon});
  final Tracker tracker;
  final Color colour;
  final String icon;

  @override
  Widget build(BuildContext context) {
    final c = tracker.mascot;
    final stage = tracker.mascotStage;
    final frames = tracker.constants.characterFrames[c.id];
    final alive = tracker.aliveDays;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (frames != null && frames.length == 5)
            SizedBox(
              height: 190,
              width: double.infinity,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 550),
                child: Image.asset(
                  'assets/characters/${frames[stage]}',
                  key: ValueKey(frames[stage]),
                  fit: BoxFit.contain,
                  // If the art is missing the card still has to read, so fall back to the emoji
                  // rather than showing a broken-image box.
                  errorBuilder: (_, __, ___) =>
                      Center(child: Text(c.emoji, style: const TextStyle(fontSize: 72))),
                ),
              ),
            ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: Text('$icon ${tracker.mascotLabel} · ${c.stateAt(stage)}',
                  style: TextStyle(color: colour, fontWeight: FontWeight.w800, fontSize: 15)),
            ),
            Text('$alive ${alive == 1 ? 'day' : 'days'} alive',
                style: const TextStyle(color: SipColors.muted, fontSize: 12)),
          ]),
          const SizedBox(height: 6),
          // Shown at every stage, not only when things are going wrong — the careful user was
          // being told nothing at all.
          Text(c.lineAt(stage, tracker.mascotName),
              style: const TextStyle(color: SipColors.muted, fontSize: 13, height: 1.45)),
        ]),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.actionLabel, required this.onAction});
  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x4D3B82F6)),
        ),
        child: Row(children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5, height: 1.45))),
          const SizedBox(width: 8),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ]),
      );
}

class _FactCard extends StatefulWidget {
  const _FactCard({required this.fact, required this.onClose});
  final WaterFact fact;
  final VoidCallback onClose;
  @override
  State<_FactCard> createState() => _FactCardState();
}

class _FactCardState extends State<_FactCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.fact;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SipColors.line),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(f.emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _open = true),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(f.hook, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              if (!_open)
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Text('Tap to read',
                      style: TextStyle(color: SipColors.warn, fontSize: 11.5, fontWeight: FontWeight.w700)),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(f.text, style: const TextStyle(color: SipColors.muted, fontSize: 12.5, height: 1.5)),
                    const SizedBox(height: 6),
                    Text('Source: ${f.source}',
                        style: const TextStyle(color: SipColors.good, fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ]),
                ),
            ]),
          ),
        ),
        IconButton(
          onPressed: widget.onClose,
          icon: const Icon(Icons.close, size: 18, color: SipColors.muted),
          tooltip: 'Close',
        ),
      ]),
    );
  }
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.tracker});
  final Tracker tracker;

  @override
  Widget build(BuildContext context) {
    final bars = tracker.brandBars;
    final total = bars.fold(0.0, (a, b) => a + b.$2);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: _Eyebrow('Insights')),
            Text(tracker.insightScope, style: const TextStyle(color: SipColors.muted, fontSize: 12)),
          ]),
          const SizedBox(height: 10),
          Text(tracker.insightLines.join(' '),
              style: const TextStyle(fontSize: 13, height: 1.5)),
          if (bars.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final b in bars)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(children: [
                  SizedBox(width: 68, child: Text(b.$1, style: const TextStyle(fontSize: 12))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: Container(
                        height: 6,
                        color: SipColors.surface2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: total <= 0 ? 0 : (b.$2 / total).clamp(0.0, 1.0),
                            child: Container(color: SipColors.waterDeep),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 86,
                    child: Text('${fmt(b.$2)} mL · ${b.$3}',
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontSize: 11.5, color: SipColors.muted)),
                  ),
                ]),
              ),
          ],
        ]),
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard({required this.tracker});
  final Tracker tracker;

  @override
  Widget build(BuildContext context) {
    final week = tracker.sumMl(7);
    final all = tracker.allTimeMl;
    final v = scaleVolume(all);
    final since = tracker.trackingSince;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    // Where it goes, over the week rather than today, so one heavy prompt does not define it.
    final days = tracker.lastDays(7);
    final s1 = days.fold(0.0, (a, d) => a + d.scope1Ml);
    final s2 = days.fold(0.0, (a, d) => a + d.scope2Ml);
    final p1 = (s1 + s2) > 0 ? s1 / (s1 + s2) : 0.15;
    final a = (p1 * 100).round();

    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 18),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          title: const _Eyebrow('Detailed analytics'),
          children: [
            Row(children: [
              Expanded(child: _Metric(value: '${tracker.today.promptCount}', label: 'Prompts today')),
              const SizedBox(width: 12),
              Expanded(child: _Metric(value: fmt(week), label: 'mL last 7 days')),
            ]),
            const SizedBox(height: 16),
            const _Eyebrow('All time'),
            const SizedBox(height: 6),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(v.value, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -1)),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(v.unit, style: const TextStyle(fontSize: 14, color: SipColors.muted, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              Text('Tracking since ${months[since.month - 1]} ${since.year}',
                  style: const TextStyle(color: SipColors.muted, fontSize: 11.5)),
            ]),
            const SizedBox(height: 4),
            Text(macroEquiv(all), style: const TextStyle(color: SipColors.muted, fontSize: 12.5)),
            const SizedBox(height: 16),
            const _Eyebrow('Where it goes'),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: SizedBox(
                height: 8,
                child: Row(children: [
                  Expanded(flex: a <= 0 ? 1 : a, child: Container(color: SipColors.good)),
                  Expanded(flex: (100 - a) <= 0 ? 1 : 100 - a, child: Container(color: SipColors.waterDeep)),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              _LegendDot(colour: SipColors.good, label: 'Server cooling', value: '$a%'),
              const SizedBox(width: 16),
              _LegendDot(colour: SipColors.waterDeep, label: 'Power plants', value: '${100 - a}%'),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -.8)),
        const SizedBox(height: 2),
        _Eyebrow(label),
      ]);
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.colour, required this.label, required this.value});
  final Color colour;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: colour, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text('$label $value', style: const TextStyle(color: SipColors.muted, fontSize: 11.5)),
      ]);
}

class _DemoRow extends StatelessWidget {
  const _DemoRow({required this.tracker});
  final Tracker tracker;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Try it (test build)', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Adds a fake prompt so you can see the counter move.',
                style: TextStyle(color: SipColors.muted, fontSize: 12)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton(onPressed: () => tracker.simulate(charCount: 400), child: const Text('Standard prompt')),
              OutlinedButton(onPressed: () => tracker.simulate(modelHint: 'o3', charCount: 400), child: const Text('Reasoning')),
              OutlinedButton(
                  onPressed: () => tracker.simulate(vendor: 'google', modelHint: 'flash', charCount: 400),
                  child: const Text('Lightweight')),
            ]),
          ]),
        ),
      );
}
