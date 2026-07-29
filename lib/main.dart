import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';

// "Evaluation dossier" palette
class AppColors {
  static const ink = Color(0xFF171D22);
  static const inkSoft = Color(0xFF3C464E);
  static const paper = Color(0xFFEEF1F2);
  static const panel = Colors.white;
  static const line = Color(0xFFD3D9DC);
  static const steel = Color(0xFF8A97A0);
  static const green = Color(0xFF1F7A4D);
  static const amber = Color(0xFFC77E1F);
  static const red = Color(0xFFB3402E);
}

void main() {
  runApp(const InterviewPrepApp());
}

class InterviewPrepApp extends StatelessWidget {
  const InterviewPrepApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.ink,
        primary: AppColors.ink,
        surface: AppColors.panel,
        error: AppColors.red,
      ),
    );
    return MaterialApp(
      title: 'InterviewPrep',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
          headlineMedium: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w700, color: AppColors.ink, fontSize: 28, height: 1.15),
          headlineSmall: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w600, color: AppColors.ink, fontSize: 20),
          titleMedium: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w600, color: AppColors.ink, fontSize: 16),
          labelSmall: GoogleFonts.jetBrainsMono(
              color: AppColors.steel, fontSize: 10.5, letterSpacing: 1.4),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.paper,
          foregroundColor: AppColors.ink,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.jetBrainsMono(
              color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 1),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.ink,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.inkSoft,
            side: const BorderSide(color: AppColors.line),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFBFCFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: AppColors.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: AppColors.line),
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.panel,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.line),
          ),
          margin: EdgeInsets.zero,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

/// Small mono eyebrow label used across screens.
class Eyebrow extends StatelessWidget {
  final String text;
  const Eyebrow(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: GoogleFonts.jetBrainsMono(color: AppColors.steel, fontSize: 10.5, letterSpacing: 1.4),
      );
}
