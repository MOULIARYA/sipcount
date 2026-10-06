/// The ecosystem characters — what they are called, what state they are in, and what they say.
///
/// Ported from `ECO` in the prototype. Every string here is Mouli's copy, verbatim, including the
/// curly apostrophes. The art is hers too: five `.webp` frames per character, synced into the app
/// bundle by `tools/build-shared.js` from the same `assets/` folder the prototype reads, so the
/// phone shows the same pictures rather than a re-creation of them.
///
/// The character is the whole argument of the product: a few hundred millilitres is a small number
/// and a small number shown alone argues against caring. Something visibly worse off does not.
library;

class Character {
  const Character({
    required this.id,
    required this.label,
    required this.emoji,
    required this.subject,
    required this.states,
    required this.lines,
    required this.unlockDays,
  });

  final String id;

  /// What it is called when no name has been given: 'Polar bear'.
  final String label;
  final String emoji;

  /// How it is referred to inside a sentence when unnamed: 'The bear'.
  final String subject;

  /// Five state words, 0 = pristine → 4 = at the limit.
  final List<String> states;

  /// Five lines. `{n}` is where the character's name goes — note the snow leopard's third line
  /// has no name in it, exactly as written.
  final List<String> lines;

  /// Consecutive days under budget, with prompts, before this one becomes available.
  final int unlockDays;

  String stateAt(int stage) => states[stage.clamp(0, 4)];
  String lineAt(int stage, String name) => lines[stage.clamp(0, 4)].replaceAll('{n}', name);
}

/// In unlock order. The prototype also draws an axolotl, but it is not in the roster and has no
/// artwork, so it is unreachable there and deliberately absent here.
const List<Character> kCharacters = [
  Character(
    id: 'plant',
    label: 'Plant',
    emoji: '🪴',
    subject: 'Your plant',
    unlockDays: 0,
    states: ['Thriving', 'Thirsty', 'Wilting', 'Drying out', 'Parched'],
    lines: [
      '{n} is plump and green.',
      '{n} is looking a little thirsty.',
      '{n} is starting to wilt.',
      '{n} is drooping and turning brown.',
      '{n} has dried out and is dropping leaves.',
    ],
  ),
  Character(
    id: 'bear',
    label: 'Polar bear',
    emoji: '🐻‍❄️',
    subject: 'The bear',
    unlockDays: 3,
    states: ['Comfortable', 'Uneasy', 'Restless', 'Balancing', 'Stranded'],
    lines: [
      '{n} has plenty of ice to sit on.',
      'The ice under {n} has started to melt.',
      'The ice is shrinking under {n}.',
      '{n} is balancing on what is left of the ice.',
      '{n} is down to the last sliver of ice.',
    ],
  ),
  Character(
    id: 'leopard',
    label: 'Snow leopard',
    emoji: '🐆',
    subject: 'The leopard',
    unlockDays: 7,
    states: ['Resting easy', 'Warming up', 'Restless', 'Too warm', 'Nowhere cool'],
    lines: [
      '{n} is resting on deep snow.',
      'The snow under {n} is thinning.',
      'Bare rock is showing through the snow.',
      '{n} is too warm on the bare rock.',
      '{n} has nowhere cool left to lie.',
    ],
  ),
  Character(
    id: 'glacier',
    label: 'Glacier',
    emoji: '🧊',
    subject: 'The glacier',
    unlockDays: 14,
    states: ['Solid', 'Dripping', 'Melting', 'Cracking', 'Breaking apart'],
    lines: [
      '{n} is holding solid.',
      '{n} has started to drip.',
      '{n} is melting and cracking.',
      '{n} is breaking into pieces.',
      '{n} has melted down to a small mound.',
    ],
  ),
];

Character characterById(String? id) =>
    kCharacters.firstWhere((c) => c.id == id, orElse: () => kCharacters.first);

/// Which of the five stages a fraction of the budget lands on.
///
/// `worstStage` is 3 rather than 4 for under-13s: a plant may be drooping, never dead. The
/// prototype applies that cap to the words but not to the picture; here it caps both, because a
/// child seeing stage-4 art beside stage-3 words is the bug, not the design.
int stageOf(double pct, {int worstStage = 4}) {
  final clamped = pct.isNaN ? 0.0 : pct.clamp(0.0, 1.0);
  final raw = (clamped * 4).round();
  return raw.clamp(0, worstStage);
}
