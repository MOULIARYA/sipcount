/// Sipcount design tokens — mirrors prototype/sipcount.html. Dark by default
/// (OLED-friendly, lower display energy).
library;

import 'package:flutter/material.dart';

/// Every value here is checked against `sipcount.html`'s `:root` by `parity.js`. Change one without
/// changing the prototype (or the other way round) and the build fails — the navy-and-blue palette
/// this used to hold survived three weeks after the prototype went true-black and green, because
/// nothing compared them.
abstract final class SipColors {
  static const bg = Color(0xFF000000); // --ink
  static const surface = Color(0xFF141414); // --surface
  static const surface2 = Color(0xFF1E1E1E); // --surface-2
  static const line = Color(0xFF262626); // --line
  static const text = Color(0xFFFFFFFF); // --text
  static const muted = Color(0xFFA6A6A6); // --muted
  static const water = Color(0xFF00F076); // --green — the brand accent
  static const waterDeep = Color(0xFF00B85A); // --green-deep
  static const warn = Color(0xFFFFB800); // --amber
  static const danger = Color(0xFFFF3B30); // --red
  static const good = Color(0xFF00F076); // --green
}

ThemeData sipcountTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: SipColors.water,
    onPrimary: SipColors.bg,
    secondary: SipColors.good,
    onSecondary: SipColors.bg,
    error: SipColors.warn,
    onError: SipColors.bg,
    surface: SipColors.surface,
    onSurface: SipColors.text,
    surfaceContainerHighest: SipColors.surface2,
    outline: SipColors.line,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, scaffoldBackgroundColor: SipColors.bg);
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: SipColors.text, displayColor: SipColors.text),
    cardTheme: const CardThemeData(
      color: SipColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20)), side: BorderSide(color: SipColors.line)),
    ),
    appBarTheme: const AppBarThemeData(backgroundColor: SipColors.bg, foregroundColor: SipColors.text, elevation: 0, centerTitle: false),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: SipColors.surface,
      indicatorColor: SipColors.water.withValues(alpha: .18),
      labelTextStyle: WidgetStatePropertyAll(base.textTheme.labelMedium?.copyWith(color: SipColors.text)),
      iconTheme: const WidgetStatePropertyAll(IconThemeData(color: SipColors.text)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: SipColors.water,
        foregroundColor: SipColors.bg,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(foregroundColor: SipColors.text, side: const BorderSide(color: SipColors.line), shape: const StadiumBorder()),
    ),
    inputDecorationTheme: const InputDecorationThemeData(
      filled: true,
      fillColor: SipColors.surface2,
      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: SipColors.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: SipColors.line)),
    ),
    dividerColor: SipColors.line,
  );
}
