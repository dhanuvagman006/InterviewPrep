import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';

// "Evaluation dossier" palette — pure-black AMOLED edition.
// Semantics kept from the light theme: ink = primary text & filled accents,
// paper = app background, panel = card surface, line = borders, steel = muted.
class AppColors {
  static const ink = Color(0xFFECF1F4); // primary text / filled accents
  static const onInk = Color(0xFF0B0D0F); // text drawn on ink-filled surfaces
  static const inkSoft = Color(0xFFB4BEC6);
  static const paper = Color(0xFF000000); // true black — AMOLED pixels off
  static const panel = Color(0xFF000000); // cards stay pure black, bordered
  static const line = Color(0xFF23282D);
  static const steel = Color(0xFF7E8A93);
  static const green = Color(0xFF4CC38A);
  static const amber = Color(0xFFE8A33D);
  static const red = Color(0xFFE5624C);
  static const codeBg = Color(0xFF0E1114); // code panels, slightly lifted
  static const codeText = Color(0xFFD7E0E6);
  static const field = Color(0xFF0A0C0E); // input fill
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Pure-black system bars so the whole screen is AMOLED-off black.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const InterviewPrepApp());
}

class InterviewPrepApp extends StatelessWidget {
  const InterviewPrepApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.ink,
        brightness: Brightness.dark,
        primary: AppColors.ink,
        onPrimary: AppColors.onInk,
        surface: AppColors.paper,
        onSurface: AppColors.ink,
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
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.jetBrainsMono(
              color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 1),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.ink,
            foregroundColor: AppColors.onInk,
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
          fillColor: AppColors.field,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: AppColors.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: AppColors.line),
          ),
        ),
        // M3 elevation tint would wash pure black into grey — disable it.
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.paper,
          surfaceTintColor: Colors.transparent,
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: AppColors.paper,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: AppColors.panel,
          surfaceTintColor: Colors.transparent,
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
