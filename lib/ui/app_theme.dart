import 'package:flutter/material.dart';

class AppTheme {
  static const Color blue = Color(0xff1976d2);
  static const Color selectedBlue = Color(0xff4b7bec);
  static const Color errorRed = Color(0xffd52835);

  static ThemeData light() {
    return _base(Brightness.light).copyWith(
      scaffoldBackgroundColor: const Color(0xfff7f8fb),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff17181c),
        brightness: Brightness.light,
        primary: const Color(0xff17181c),
        secondary: blue,
        error: errorRed,
        surface: Colors.white,
      ),
      dividerColor: const Color(0xffe5e7ed),
    );
  }

  static ThemeData dark() {
    return _base(Brightness.dark).copyWith(
      scaffoldBackgroundColor: const Color(0xff0f1013),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xfff4f5f7),
        brightness: Brightness.dark,
        primary: const Color(0xfff4f5f7),
        secondary: const Color(0xff7aa2ff),
        error: const Color(0xffff6673),
        surface: const Color(0xff17181c),
      ),
      dividerColor: const Color(0xff2b2d33),
    );
  }

  static ThemeData _base(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      visualDensity: VisualDensity.standard,
      fontFamily: 'MobileTina',
      fontFamilyFallback: const <String>['Segoe UI', 'Tahoma'],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: brightness == Brightness.light
            ? const Color(0xfff7f8fb)
            : const Color(0xff0f1013),
        foregroundColor: brightness == Brightness.light
            ? const Color(0xff1c1b1f)
            : const Color(0xfff4eff4),
        titleTextStyle: TextStyle(
          fontFamily: 'MobileTina',
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: brightness == Brightness.light
              ? const Color(0xff1c1b1f)
              : const Color(0xfff4eff4),
        ),
      ),
      splashFactory: InkSparkle.splashFactory,
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: brightness == Brightness.light
                ? const Color(0xffe2e5ec)
                : const Color(0xff30333a),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: selectedBlue, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(120, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
