import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const ink = Color(0xFF201A1B);
  static const cocoa = Color(0xFF513335);
  static const plum = Color(0xFF7E5360);
  static const accent = Color(0xFF5A4BDE);
  static const accentSoft = Color(0xFFEDEBFF);
  static const mint = Color(0xFFE5F5EF);
  static const peach = Color(0xFFFFEEE5);
  static const canvas = Color(0xFFF8F7F5);
  static const white = Color(0xFFFFFFFF);
  static const line = Color(0xFFE8E2DF);
  static const muted = Color(0xFF7D7374);
  static const darkBrown = cocoa;
  static const mediumBrown = plum;

  static ThemeData get light {
    final base = GoogleFonts.interTextTheme();
    final text = base.apply(bodyColor: ink, displayColor: ink);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: canvas,
      colorScheme: const ColorScheme.light(
          primary: accent,
          onPrimary: white,
          secondary: plum,
          onSecondary: white,
          surface: white,
          onSurface: ink,
          error: Color(0xFFB33A45)),
      textTheme: text.copyWith(
        headlineLarge: text.headlineLarge
            ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -1.2),
        headlineMedium: text.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -.8),
        titleLarge: text.titleLarge
            ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -.2),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        bodyMedium: text.bodyMedium?.copyWith(fontSize: 14, height: 1.35),
      ),
      dividerColor: line,
      appBarTheme: AppBarTheme(
          backgroundColor: canvas,
          foregroundColor: ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: text.titleLarge
              ?.copyWith(color: ink, fontWeight: FontWeight.w700)),
      cardTheme: CardThemeData(
          color: white,
          elevation: 0,
          margin: EdgeInsets.zero,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: line))),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: white,
              elevation: 0,
              minimumSize: const Size(0, 50),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              textStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              foregroundColor: ink,
              minimumSize: const Size(0, 50),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              side: const BorderSide(color: line),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              textStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: line)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: line)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: accent, width: 1.5))),
      snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: ink,
          contentTextStyle: const TextStyle(
              color: white, fontSize: 13, fontWeight: FontWeight.w600),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 92)),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: white,
          selectedItemColor: accent,
          unselectedItemColor: muted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle:
              TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          unselectedLabelStyle:
              TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  static void notify(BuildContext context, String message,
      {bool isError = false, String? actionLabel, VoidCallback? onAction}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
        content: Row(children: [
          Icon(
              isError
                  ? Icons.info_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color:
                  isError ? const Color(0xFFFFB5B5) : const Color(0xFFA7E7CC),
              size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message))
        ]),
        action: actionLabel == null
            ? null
            : SnackBarAction(
                label: actionLabel,
                textColor: accentSoft,
                onPressed: onAction ?? () {})));
  }
}
