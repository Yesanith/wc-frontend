import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const bg = Color(0xFF0E1014);
  static const surface = Color(0xFF171A21);
  static const surface2 = Color(0xFF1F232C);
  static const line = Color(0xFF2A2F3A);
  static const track = Color(0xFF262B35);
  static const navBg = Color(0xFF12151B);
  static const text = Color(0xFFEDE7D9);
  static const textSoft = Color(0xFFD9D2C3);
  static const muted = Color(0xFFA7A092);
  static const hint = Color(0xFF8C8577);
  /// trailing chevrons and other quiet row decorations
  static const chevron = Color(0xFF6E6859);
  static const gold = Color(0xFFE3B55B);
  static const onGold = Color(0xFF1A1408);
  static const green = Color(0xFF7BD389);
  static const red = Color(0xFFF07A6A);
  static const silver = Color(0xFFC9CED6);
  static const copper = Color(0xFFD69B6B);
}

TextStyle display(double size, {Color color = AppColors.text}) =>
    GoogleFonts.cinzel(fontSize: size, fontWeight: FontWeight.w700, color: color);

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.gold,
      onPrimary: AppColors.onGold,
      secondary: AppColors.gold,
      onSecondary: AppColors.onGold,
      surface: AppColors.bg,
      onSurface: AppColors.text,
    ),
  );
  return base.copyWith(
    textTheme: GoogleFonts.manropeTextTheme(base.textTheme).apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
  );
}

InputDecoration fieldDecoration(String hint, {Widget? prefixIcon, Widget? suffixIcon}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.hint),
    filled: true,
    fillColor: AppColors.surface,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.gold),
    ),
  );
}

const _professionColors = <String, Color>{
  'Guardian': Color(0xFF72C1D9),
  'Warrior': Color(0xFFF2C65B),
  'Engineer': Color(0xFFD09C59),
  'Ranger': Color(0xFF9BD86F),
  'Thief': Color(0xFFC08F95),
  'Elementalist': Color(0xFFF68A87),
  'Mesmer': Color(0xFFC08BE0),
  'Necromancer': Color(0xFF5FC07F),
  'Revenant': Color(0xFFD16E5A),
};

Color professionColor(String? p) => _professionColors[p] ?? AppColors.gold;

const _rarityColors = <String, Color>{
  'Junk': Color(0xFF8C8577),
  'Basic': Color(0xFFB5B0A5),
  'Fine': Color(0xFF5AA2E6),
  'Masterwork': Color(0xFF5FC07F),
  'Rare': Color(0xFFF2D14B),
  'Exotic': Color(0xFFF5A524),
  'Ascended': Color(0xFFF0508C),
  'Legendary': Color(0xFFB57BF2),
};

Color rarityColor(String? r) => _rarityColors[r] ?? AppColors.line;
