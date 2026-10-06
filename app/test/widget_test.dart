import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_water/app/theme.dart';
import 'package:ai_water/app/ui_contract.dart';
import 'package:ai_water/features/calculation_engine/domain/plain_words.dart';
import 'package:ai_water/features/tracking/domain/character.dart';

void main() {
  test('theme is dark by default (energy-saving requirement)', () {
    final t = sipcountTheme();
    expect(t.brightness, Brightness.dark);
    expect(t.scaffoldBackgroundColor, SipColors.bg);
  });

  test('true black, not nearly black — the OLED saving is the reason for the palette', () {
    expect(SipColors.bg, const Color(0xFF000000));
  });

  group('the contract this app claims', () {
    test('what is implemented is not claimed to be ahead of the prototype', () {
      expect(implementedUiContract, lessThanOrEqualTo(acknowledgedPrototypeContract));
    });
  });

  group('the character copy survives the port', () {
    test('every character has five states and five lines', () {
      for (final c in kCharacters) {
        expect(c.states.length, 5, reason: c.id);
        expect(c.lines.length, 5, reason: c.id);
      }
    });

    test('a name replaces the placeholder everywhere one appears', () {
      for (final c in kCharacters) {
        for (var s = 0; s < 5; s++) {
          expect(c.lineAt(s, 'Pip'), isNot(contains('{n}')), reason: '${c.id} stage $s');
        }
      }
    });

    test('the snow leopard keeps the one line written without a name in it', () {
      // Not an oversight in the copy — it reads better that way, and a well-meaning "fix" would
      // quietly change the product owner's words.
      final leopard = characterById('leopard');
      expect(leopard.lines[2], 'Bare rock is showing through the snow.');
    });

    test('under 13 the character never reaches its worst state', () {
      // A plant may be drooping; it may not be dead.
      expect(stageOf(1.0, worstStage: 3), 3);
      expect(stageOf(1.0), 4);
    });

    test('an empty day is stage zero even if the budget is zero', () {
      expect(stageOf(0), 0);
      expect(stageOf(double.nan), 0);
    });
  });

  group('the plain-language lines', () {
    test('a quiet day says so rather than printing a zero', () {
      expect(opportunityCost(0), 'Nothing yet today.');
    });

    test('a few millilitres are drops, not a percentage of nothing', () {
      expect(opportunityCost(1), contains('drops of water today'));
    });

    test('a working day is glasses', () {
      expect(opportunityCost(500), contains('standard drinking glass'));
    });

    test('singular and plural are not mangled', () {
      expect(opportunityCost(250), contains('1 standard drinking glass today'));
      expect(opportunityCost(250), isNot(contains('glasses')));
    });

    test('the period is substituted, for the weekly report', () {
      expect(opportunityCost(500, period: 'in the last 7 days'), endsWith('in the last 7 days.'));
    });

    test('the scale line stays silent when the day is too small to compare honestly', () {
      expect(scaleLine(0), isNull);
      expect(scaleLine(1), isNull);
    });

    test('and appears once the comparison means something', () {
      expect(scaleLine(500), contains('700,000 litres'));
    });

    test('all-time volume changes unit rather than printing six digits of millilitres', () {
      expect(scaleVolume(500).unit, 'mL');
      expect(scaleVolume(5000).unit, 'L');
      expect(scaleVolume(5e6).unit, 'm³');
    });

    test('thousands are grouped without pulling in a localisation package', () {
      expect(fmt(1204, 0), '1,204');
      expect(fmt(9.5), '9.5');
      expect(fmt(-1204, 0), '-1,204');
    });

    test('nothing tracked says nothing tracked', () {
      expect(macroEquiv(0), 'Nothing tracked yet.');
    });

    test('answer length is described, never counted in tokens', () {
      expect(lengthWord(0), 'nothing at all');
      expect(lengthWord(225), 'a few paragraphs');
      expect(lengthWord(5000), 'an essay');
    });
  });
}
