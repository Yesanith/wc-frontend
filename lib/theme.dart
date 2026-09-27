import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// the palette of Regions of XIV 1.0, gold on warm black after its icon,
/// so the two projects read as one family. names stay what the screens
/// already use
class AppColors {
  /// the window itself, and the darkest surface
  static const bg = Color(0xFF0D0B09);

  /// the drawer and other chrome one step above the window
  static const navBg = Color(0xFF151210);

  /// cards and panels
  static const surface = Color(0xFF1C1814);

  /// raised controls, hover and pressed states
  static const surface2 = Color(0xFF25201B);
  static const surface3 = Color(0xFF302A23);

  /// card borders
  static const line = Color(0xFF3A332A);

  /// empty bars and slider tracks
  static const track = Color(0xFF2B2620);

  /// the faint rule between rows of a card
  static const hairline = Color(0x0EFFFFFF);

  static const text = Color(0xFFF6F1E8);
  static const textSoft = Color(0xFFD1C9BD);
  static const muted = Color(0xFF9E9586);
  static const hint = Color(0xFF807767);

  /// trailing chevrons and other quiet row decorations
  static const chevron = Color(0xFF6B6254);

  static const gold = Color(0xFFDFC295);
  static const goldSoft = Color(0xFFF6E3C2);
  static const onGold = Color(0xFF251C12);
  static const ember = Color(0xFFDE783D);
  static const amber = Color(0xFFF0BD57);
  static const blue = Color(0xFF6BA8F5);
  static const green = Color(0xFF75DBA8);
  static const red = Color(0xFFED6B7A);

  /// brand colours, for tiles people should recognise at a glance
  static const coffee = Color(0xFFFFDD00);
  static const onCoffee = Color(0xFF251C12);

  /// the night sky behind the hero, as behind the plugin's live preview
  static const skyTop = Color(0xFF141825);
  static const skyBottom = Color(0xFF07070A);

  static const silver = Color(0xFFC9CED6);
  static const copper = Color(0xFFD69B6B);
}

/// corner radii shared by every surface
class AppRadius {
  static const window = 14.0;
  static const card = 10.0;
  static const frame = 7.0;
}

/// headlines and titles. one face for the whole app, Noto Sans as the plugin
/// uses, a weight heavier than the body
TextStyle display(double size, {Color color = AppColors.text}) =>
    GoogleFonts.notoSans(fontSize: size, fontWeight: FontWeight.w600, color: color, letterSpacing: 0.1);

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
      surfaceContainerHighest: AppColors.surface2,
      outline: AppColors.line,
      outlineVariant: AppColors.track,
      error: AppColors.red,
    ),
  );
  const stadium = StadiumBorder();
  const frame = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AppRadius.frame)));
  const card = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)));
  const window = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AppRadius.window)));
  return base.copyWith(
    textTheme: GoogleFonts.notoSansTextTheme(base.textTheme).apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.text,
      titleTextStyle: display(19),
      shape: const Border(bottom: BorderSide(color: AppColors.hairline)),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.hairline, thickness: 1, space: 1),
    // gold track and a dark knob when on, a quiet grey knob when off
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.gold : AppColors.surface2),
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.onGold : AppColors.textSoft),
      trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.goldSoft.withValues(alpha: 0.6) : AppColors.line),
    ),
    // pills: gold tinted with a gold rim when picked, quiet otherwise
    chipTheme: ChipThemeData(
      shape: stadium,
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.gold.withValues(alpha: 0.18),
      side: WidgetStateBorderSide.resolveWith((s) =>
          BorderSide(color: s.contains(WidgetState.selected) ? AppColors.gold.withValues(alpha: 0.6) : AppColors.line)),
      labelStyle: const TextStyle(color: AppColors.textSoft, fontWeight: FontWeight.w600),
      secondaryLabelStyle: const TextStyle(color: AppColors.goldSoft, fontWeight: FontWeight.w700),
      checkmarkColor: AppColors.goldSoft,
      showCheckmark: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.onGold,
        shape: stadium,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.goldSoft,
        backgroundColor: AppColors.gold.withValues(alpha: 0.08),
        side: BorderSide(color: AppColors.gold.withValues(alpha: 0.45)),
        shape: stadium,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.gold, shape: stadium),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: AppColors.textSoft)),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.gold, linearTrackColor: AppColors.track),
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.gold,
      inactiveTrackColor: AppColors.track,
      thumbColor: AppColors.goldSoft,
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: AppColors.surface2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
        side: BorderSide(color: AppColors.line),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: window,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.window))),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.surface2,
      contentTextStyle: TextStyle(color: AppColors.text),
      behavior: SnackBarBehavior.floating,
      shape: card,
    ),
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.surface3,
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.frame)),
      ),
      textStyle: TextStyle(color: AppColors.text, fontSize: 12),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.text,
      unselectedLabelColor: AppColors.muted,
      dividerColor: AppColors.hairline,
      indicatorColor: AppColors.gold,
    ),
    navigationDrawerTheme: NavigationDrawerThemeData(
      backgroundColor: AppColors.navBg,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.gold.withValues(alpha: 0.16),
      indicatorShape: frame,
      iconTheme: WidgetStateProperty.resolveWith((s) =>
          IconThemeData(color: s.contains(WidgetState.selected) ? AppColors.goldSoft : AppColors.muted, size: 22)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
          fontSize: 14,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? AppColors.text : AppColors.textSoft)),
    ),
    listTileTheme: const ListTileThemeData(iconColor: AppColors.muted),
    cardTheme: const CardThemeData(color: AppColors.surface, surfaceTintColor: Colors.transparent, shape: card),
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
      borderRadius: BorderRadius.circular(AppRadius.card),
      borderSide: const BorderSide(color: AppColors.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
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
