/// "Try a prompt" — the prototype's `#s-log`, ported at contract 15.
///
/// It is a what-if and nothing else. **Nothing on this screen can reach today's total**: the one
/// number the app exists to keep honest is never editable by hand, so there is no Log button and
/// no write path, not even a disabled one.
///
/// The effort control is the reason this screen is worth having. Without it the simulator said a
/// heavy prompt cost about 6 mL when the extension measured the same behaviour at 176 — it was
/// quietly describing a different product from the one people install (I-49).
library;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../calculation_engine/domain/model_profile.dart';
import '../../calculation_engine/domain/plain_words.dart';
import '../../tracking/application/tracker.dart';

class SimulatePage extends StatefulWidget {
  const SimulatePage({super.key, required this.tracker});
  final Tracker tracker;

  @override
  State<SimulatePage> createState() => _SimulatePageState();
}

class _SimulatePageState extends State<SimulatePage> {
  String _vendor = 'openai';
  ModelTier _tier = ModelTier.standard;
  TaskType _task = TaskType.text;

  /// Seconds of work before the answer appeared. Three plain choices, no numbers, no jargon.
  int _effortSecs = 0;

  double _questionChars = 400;
  double _answerTokens = 300;

  static const _effort = [('Straight away', 0), ('Thought a bit', 25), ('Did research', 270)];

  static const _tiersByVendor = {
    'openai': [('GPT-5', ModelTier.standard), ('GPT-5 mini', ModelTier.lightweight), ('o3', ModelTier.reasoning)],
    'anthropic': [('Claude Sonnet', ModelTier.standard), ('Claude Haiku', ModelTier.lightweight),
                  ('Claude Opus (extended thinking)', ModelTier.reasoning)],
    'google': [('Gemini Pro', ModelTier.standard), ('Gemini Flash', ModelTier.lightweight),
               ('Gemini Pro (Deep Think)', ModelTier.reasoning)],
  };

  @override
  Widget build(BuildContext context) {
    final t = widget.tracker;
    final models = _tiersByVendor[_vendor]!;
    final est = t.estimateFor(
      tier: _tier,
      task: _task,
      inputChars: _questionChars.round(),
      outputTokens: _answerTokens.round(),
      effortSeconds: _effortSecs,
    );
    final ml = est.totalMl;
    final answerWords = wordsFromTokens(_answerTokens.round());
    final questionWords = wordsFromTokens((_questionChars / 4).round());

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        children: [
          Text('Try a prompt',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.5)),
          const SizedBox(height: 4),
          const Text('Images run the servers hotter than text, and long answers cost far more than your question.',
              style: TextStyle(color: SipColors.muted, fontSize: 12.5, height: 1.45)),
          const SizedBox(height: 18),

          _Segmented(
            label: 'AI tool',
            options: const ['ChatGPT', 'Claude', 'Gemini'],
            selected: {'openai': 0, 'anthropic': 1, 'google': 2}[_vendor]!,
            onSelect: (i) => setState(() {
              _vendor = ['openai', 'anthropic', 'google'][i];
              _tier = _tiersByVendor[_vendor]!.first.$2;
            }),
          ),
          const SizedBox(height: 12),

          _Segmented(
            label: 'Model',
            options: [for (final m in models) m.$1],
            selected: models.indexWhere((m) => m.$2 == _tier).clamp(0, models.length - 1),
            onSelect: (i) => setState(() => _tier = models[i].$2),
          ),
          const SizedBox(height: 12),

          _Segmented(
            label: 'Task type',
            options: const ['Text', 'Code', 'Long doc', 'Image'],
            selected: [TaskType.text, TaskType.code, TaskType.longContext, TaskType.image].indexOf(_task),
            onSelect: (i) => setState(() =>
                _task = [TaskType.text, TaskType.code, TaskType.longContext, TaskType.image][i]),
          ),
          const SizedBox(height: 12),

          _Segmented(
            label: 'How long it worked before answering',
            options: [for (final e in _effort) e.$1],
            selected: _effort.indexWhere((e) => e.$2 == _effortSecs).clamp(0, 2),
            onSelect: (i) => setState(() => _effortSecs = _effort[i].$2),
          ),

          if (_task != TaskType.image) ...[
            const SizedBox(height: 18),
            _SliderRow(
              caption: 'Your question',
              value: '$questionWords words',
              slider: Slider(
                value: _questionChars,
                min: 20,
                max: 6000,
                divisions: 299,
                onChanged: (v) => setState(() => _questionChars = v),
              ),
            ),
            _SliderRow(
              caption: 'The answer',
              value: '$answerWords words · ${lengthWord(answerWords)}',
              slider: Slider(
                value: _answerTokens,
                min: 20,
                max: 4000,
                divisions: 199,
                onChanged: (v) => setState(() => _answerTokens = v),
              ),
            ),
          ],

          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic, children: [
                  Text(fmt(ml, ml < 10 ? 2 : 1),
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1.6)),
                  const SizedBox(width: 5),
                  const Text('mL', style: TextStyle(fontSize: 16, color: SipColors.muted, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 4),
                Text('Somewhere between ${fmt(ml * 0.2, 2)} and ${fmt(ml * 3.9, 1)} mL.',
                    style: const TextStyle(color: SipColors.muted, fontSize: 12.5)),
                if (_task != TaskType.image && ml > 0) ...[
                  const SizedBox(height: 12),
                  _SplitBar(inputShare: est.inputShare),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 12),
          _Nudge(text: t.simulateNudge(est, _tier, _task)),
          const SizedBox(height: 14),
          const Text('Nothing here touches today’s total — it’s a sandbox.',
              style: TextStyle(color: SipColors.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.label, required this.options, required this.selected, required this.onSelect});
  final String label;
  final List<String> options;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(),
            style: const TextStyle(color: SipColors.muted, fontSize: 10.5,
                fontWeight: FontWeight.w700, letterSpacing: 1.1)),
        const SizedBox(height: 7),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (var i = 0; i < options.length; i++)
              _Chip(label: options[i], on: i == selected, onTap: () => onSelect(i)),
          ],
        ),
      ]);
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: on,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(99),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: on ? SipColors.good : Colors.transparent,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: on ? SipColors.good : SipColors.line),
            ),
            child: Text(label,
                style: TextStyle(
                    color: on ? Colors.black : SipColors.text,
                    fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 12.5)),
          ),
        ),
      );
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({required this.caption, required this.value, required this.slider});
  final String caption;
  final String value;
  final Widget slider;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(caption.toUpperCase(),
              style: const TextStyle(color: SipColors.muted, fontSize: 10.5,
                  fontWeight: FontWeight.w700, letterSpacing: 1.1)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
        slider,
      ]);
}

/// The question against the answer. Most of the water goes into the reply, and this is the one
/// picture that makes that obvious.
class _SplitBar extends StatelessWidget {
  const _SplitBar({required this.inputShare});
  final double inputShare;

  @override
  Widget build(BuildContext context) {
    final inPct = (inputShare * 100).round();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: SizedBox(
          height: 8,
          child: Row(children: [
            Expanded(flex: inPct <= 0 ? 1 : inPct, child: Container(color: SipColors.muted)),
            Expanded(flex: (100 - inPct) <= 0 ? 1 : 100 - inPct, child: Container(color: SipColors.good)),
          ]),
        ),
      ),
      const SizedBox(height: 6),
      Text('Your question · $inPct%   ·   The answer · ${100 - inPct}%',
          style: const TextStyle(color: SipColors.muted, fontSize: 11.5)),
    ]);
  }
}

class _Nudge extends StatelessWidget {
  const _Nudge({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: SipColors.good.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SipColors.good.withValues(alpha: .18)),
        ),
        child: Text(text, style: const TextStyle(fontSize: 12.5, height: 1.5)),
      );
}
