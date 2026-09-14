import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_water/app/theme.dart';

void main() {
  test('theme is dark by default (energy-saving requirement)', () {
    final t = sipcountTheme();
    expect(t.brightness, Brightness.dark);
    expect(t.scaffoldBackgroundColor, SipColors.bg);
  });
}
