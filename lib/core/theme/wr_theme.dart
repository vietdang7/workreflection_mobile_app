import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'wr_colors.dart';

/// Build the app's [ColorScheme]. Pure function — no font loading.
ColorScheme wrColorScheme() {
  return ColorScheme.fromSeed(
    seedColor: WrColors.navy,
    primary: WrColors.navy,
    secondary: WrColors.coral,
    tertiary: WrColors.teal,
    surface: WrColors.white,
  );
}

/// Full app theme including Be Vietnam Pro font. Requires Flutter binding
/// (call after [WidgetsFlutterBinding.ensureInitialized]).
ThemeData wrTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: wrColorScheme(),
    // Spec §01: nền toàn màn hình là Cream BG, không phải trắng thuần — thẻ
    // trắng nổi lên được là nhờ nền này.
    scaffoldBackgroundColor: WrColors.pageBg,
    textTheme: GoogleFonts.beVietnamProTextTheme(),
  );
}

abstract final class WrTextStyles {
  static TextStyle get eyebrow => const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.55,
        // Spec §01b: eyebrow/tiny dùng text-3, không phải text-2.
        color: WrColors.text3,
      );

  static TextStyle get hLarge => const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: WrColors.navy,
      );

  static TextStyle get hMedium => const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: WrColors.dark,
      );

  static TextStyle get body => TextStyle(
        fontSize: 15.5,
        color: WrColors.dark.withValues(alpha: 0.8),
        height: 1.5,
      );

  static TextStyle get insightQuote => const TextStyle(
        fontSize: 20,
        fontStyle: FontStyle.italic,
        color: WrColors.navy,
        height: 1.45,
      );

  static TextStyle get dateTitle => const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: WrColors.navy,
      );

  static TextStyle get greeting => const TextStyle(
        fontSize: 15.5,
        color: WrColors.muted,
      );
}
