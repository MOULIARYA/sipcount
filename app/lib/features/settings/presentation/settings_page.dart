import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../tracking/application/tracker.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.tracker});
  final Tracker tracker;

  // Stamped by CI via --dart-define; 'dev' when built locally.
  static const _build = String.fromEnvironment('SIPCOUNT_BUILD', defaultValue: 'dev');
  static const _sha = String.fromEnvironment('SIPCOUNT_SHA', defaultValue: 'local');

  static const _regionLabels = {'us_default': 'US hyperscale (default)', 'colo_average': 'Industry-average colocation'};

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: tracker,
        builder: (context, _) => SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Text('Settings', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.5)),
              const SizedBox(height: 20),
              _Section(title: 'Daily water budget', children: [
                Row(children: [
                  Expanded(
                    child: Slider(
                      value: tracker.budgetMl.clamp(10, 500).toDouble(),
                      min: 10,
                      max: 500,
                      divisions: 49,
                      label: '${tracker.budgetMl} mL',
                      onChanged: (v) => tracker.setBudgetMl(v.round()),
                    ),
                  ),
                  SizedBox(width: 72, child: Text('${tracker.budgetMl} mL', textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700))),
                ]),
                const Text('100 mL ≈ 80 standard prompts a day. Lower it to challenge yourself.', style: TextStyle(color: SipColors.muted, fontSize: 12)),
              ]),
              const SizedBox(height: 12),
              _Section(title: 'Data-centre assumptions', children: [
                DropdownButtonFormField<String>(
                  initialValue: tracker.regionId,
                  items: [for (final r in tracker.selectableRegions) DropdownMenuItem(value: r, child: Text(_regionLabels[r] ?? r))],
                  onChanged: (v) => v == null ? null : tracker.setRegionId(v),
                ),
                const SizedBox(height: 8),
                Text('Constants version ${tracker.constantsVersion}. Regions without sourced water-intensity data are hidden until cited.',
                    style: const TextStyle(color: SipColors.muted, fontSize: 12)),
              ]),
              const SizedBox(height: 12),
              _Section(title: 'Counting', children: [
                Row(children: [
                  Icon(tracker.listenerEnabled ? Icons.check_circle : Icons.pause_circle_outline, color: tracker.listenerEnabled ? SipColors.good : SipColors.muted),
                  const SizedBox(width: 10),
                  Expanded(child: Text(tracker.listenerEnabled ? 'Accessibility service is on' : 'Accessibility service is off')),
                  TextButton(onPressed: tracker.openEnableSettings, child: const Text('Change')),
                ]),
                const Text('Watches ChatGPT, Claude, Gemini and Chrome for a Send tap. Reads the length of what you typed, then forgets it.',
                    style: TextStyle(color: SipColors.muted, fontSize: 12)),
              ]),
              const SizedBox(height: 12),
              _Section(title: 'How we calculate', children: const [
                Text(
                  'water (mL) = energy per prompt (Wh) × data-centre overhead (PUE) × water per Wh (on-site cooling + power generation).\n\n'
                  'Energy per prompt is estimated from the length of your prompt and the model class you picked (lightweight / standard / reasoning). '
                  'Every constant is cited in models.json and shown with a confidence level. These are estimates, not meter readings.',
                  style: TextStyle(color: SipColors.muted, height: 1.4, fontSize: 13),
                ),
              ]),
              const SizedBox(height: 12),
              _Section(title: 'Privacy', children: [
                const Text(
                  'Sipcount has no internet permission. It never stores what you type, which model you used, or when — only millilitre totals per calendar day, on this phone.',
                  style: TextStyle(color: SipColors.muted, height: 1.4, fontSize: 13),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline, color: SipColors.warn),
                  label: const Text('Delete all totals on this device'),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Delete all totals?'),
                        content: const Text('This removes every daily total stored on this phone. It cannot be undone.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (ok == true) await tracker.wipe();
                  },
                ),
              ]),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'Sipcount 0.3 · build $_build · $_sha\nopen source · no ads, no accounts',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: SipColors.muted, fontSize: 12, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 10),
            ...children,
          ]),
        ),
      );
}
