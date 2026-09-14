/// Micro-metric display: converts mL into tangible equivalents.
library;

class Equivalence {
  const Equivalence(this.label, this.count);
  final String label;
  final double count;
}

class EquivalenceFormatter {
  const EquivalenceFormatter(this.equivalentsMl);

  /// e.g. {'sip': 15, 'coffee_cup': 240, 'water_bottle': 500}
  final Map<String, num> equivalentsMl;

  /// Picks the largest unit for which count >= 1, else the smallest unit.
  Equivalence best(double ml) {
    final sorted = equivalentsMl.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sorted) {
      if (ml >= e.value) return Equivalence(e.key, ml / e.value);
    }
    final smallest = sorted.last;
    return Equivalence(smallest.key, ml / smallest.value);
  }
}
