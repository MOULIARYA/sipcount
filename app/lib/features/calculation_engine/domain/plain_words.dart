/// Turning millilitres into something a person can picture — ported from the prototype's
/// `fmt`, `opportunityCost`, `scaleLine`, `scaleVolume` and `macroEquiv`.
///
/// These are the lines Mouli wrote and signed off, so the wording here is copied exactly, down to
/// the curly apostrophes and the British spelling. The numbers come from the shared constants; the
/// sentences are the product. If one of these reads differently on the phone than it does in the
/// prototype, the phone is wrong.
library;

/// The prototype's `fmt(n, d)`: thousands separators, and by default one decimal under 10 and
/// none at or above it.
///
/// Hand-written rather than pulled from `intl`, which would add a package and its locale data to
/// an app whose whole pitch is that it is light, to get grouping commas. Fixed separators, not
/// locale-aware — a deliberate limit, recorded here rather than discovered later.
String fmt(num n, [int? decimals]) {
  final d = decimals ?? (n.abs() < 10 ? 1 : 0);
  final fixed = n.toStringAsFixed(d);
  final neg = fixed.startsWith('-');
  final body = neg ? fixed.substring(1) : fixed;
  final dot = body.indexOf('.');
  final whole = dot == -1 ? body : body.substring(0, dot);
  final rest = dot == -1 ? '' : body.substring(dot);
  final grouped = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) grouped.write(',');
    grouped.write(whole[i]);
  }
  return '${neg ? '-' : ''}$grouped$rest';
}

/// Everyday volumes, in millilitres. Mirrors `C.opp` in engine.js.
class Volumes {
  const Volumes({this.hydration = 2000, this.glass = 250, this.flush = 6000, this.showerMin = 9000});
  final double hydration;
  final double glass;
  final double flush;
  final double showerMin;
}

/// One line that makes the number mean something. Verbatim from the prototype.
///
/// `period` defaults to 'today', as it does on the dashboard; the weekly report passes
/// 'in the last 7 days'.
String opportunityCost(double ml, {String period = 'today', Volumes v = const Volumes()}) {
  if (ml <= 0) return 'Nothing yet $period.';
  if (ml < v.glass * 0.5) {
    final pct = ml / v.hydration * 100;
    if (pct < 1) {
      final drops = (ml / 0.05).round();
      return 'Your AI evaporated about ${drops < 1 ? 1 : drops} drops of water $period.';
    }
    return 'Your AI evaporated about ${pct.round()}% of a day’s drinking water $period.';
  }
  if (ml < v.flush) {
    final s = fmt(ml / v.glass, ml / v.glass < 10 ? 1 : 0);
    return 'Your AI evaporated enough water to fill $s standard drinking glass${s == '1' ? '' : 'es'} $period.';
  }
  if (ml < v.showerMin * 3) {
    final s = fmt(ml / v.flush, ml / v.flush < 10 ? 1 : 0);
    return 'Your AI evaporated enough water to flush a toilet $s time${s == '1' ? '' : 's'} $period.';
  }
  final s = fmt(ml / v.showerMin, ml / v.showerMin < 10 ? 1 : 0);
  return 'Your AI evaporated enough water for a $s-minute shower $period.';
}

const double _gpt3Litres = 700000;

/// The line that moves the number off the personal scale, because a few hundred millilitres argues
/// against caring on its own. Returns null when the day is too small for the comparison to be
/// honest (under about 1.9 mL), and the dashboard falls back to [opportunityCost].
String? scaleLine(double dayMl) {
  if (!(dayMl > 0)) return null;
  final litresPerYear = dayMl * 1e6 * 365 / 1000;   // a million people, one year
  final runs = litresPerYear / _gpt3Litres;
  if (runs < 1) return null;
  final d = 365 / runs;
  final every = d < 10
      ? '${d.round() < 1 ? 1 : d.round()} days'
      : d < 45
          ? '${(d / 7).round()} weeks'
          : '${(d / 30).round()} months';
  return 'A million people with your day would evaporate another GPT-3 training run '
      '— 700,000 litres — every $every.';
}

/// All-time totals get their own unit, so a year of use does not read as a six-digit millilitre
/// count. Mirrors `scaleVolume`.
class ScaledVolume {
  const ScaledVolume(this.value, this.unit);
  final String value;
  final String unit;
}

ScaledVolume scaleVolume(double ml) {
  if (ml < 1000) return ScaledVolume(fmt(ml, ml < 10 ? 1 : 0), 'mL');
  if (ml < 1e6) return ScaledVolume((ml / 1000).toStringAsFixed(ml < 1e4 ? 2 : 1), 'L');
  return ScaledVolume((ml / 1e6).toStringAsFixed(2), 'm³');
}

const List<(String, double)> _macro = [
  ('Olympic pools', 2.5e9),
  ('Fire trucks', 2.5e6),
  ('Bathtubs', 150000),
  ('Standard water bottles', 500),
];

/// The all-time figure in objects rather than units. Mirrors `macroEquiv`.
String macroEquiv(double ml) {
  if (ml <= 0) return 'Nothing tracked yet.';
  final pick = _macro.firstWhere((m) => m.$2 <= ml, orElse: () => _macro.last);
  final n = ml / pick.$2;
  final shown = n < 10 ? n.toStringAsFixed(n < 1 ? 2 : 1) : fmt(n, 0);
  return '≈ $shown ${pick.$1}';
}

/// Token counts are jargon, so the simulator talks in words. Mirrors `words()`/`lengthWord()`.
int wordsFromTokens(int tokens) => (tokens * 0.75).round();

String lengthWord(int words) {
  if (words <= 0) return 'nothing at all';
  if (words < 60) return 'a line or two';
  if (words < 200) return 'a short reply';
  if (words < 500) return 'a few paragraphs';
  if (words < 1200) return 'a long piece';
  return 'an essay';
}
