import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:google_fonts/google_fonts.dart';

/// every colour a screen uses, as one set. the app has two: parchment by day
/// and the same parchment by candlelight
class AppPalette {
  const AppPalette({
    required this.dark,
    required this.bg,
    required this.navBg,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.line,
    required this.track,
    required this.hairline,
    required this.text,
    required this.textSoft,
    required this.muted,
    required this.hint,
    required this.chevron,
    required this.gold,
    required this.goldSoft,
    required this.onGold,
    required this.ember,
    required this.amber,
    required this.blue,
    required this.green,
    required this.red,
    required this.silver,
    required this.copper,
    required this.header,
    required this.onHeader,
    required this.accent,
  });

  final bool dark;
  final Color bg, navBg, surface, surface2, surface3, line, track, hairline;
  final Color text, textSoft, muted, hint, chevron;
  final Color gold, goldSoft, onGold, ember, amber, blue, green, red, silver, copper;

  /// the dark bar across the top, in both palettes, and what is written on it
  final Color header, onHeader;

  /// the bright gold of the header's own marks
  final Color accent;

  /// paper, ink, a crimson for what needs the eye and gold for the rules
  static const light = AppPalette(
    dark: false,
    bg: Color(0xFFF4ECDA),
    navBg: Color(0xFFEBE0C8),
    surface: Color(0xFFFBF6EA),
    surface2: Color(0xFFEBE0C8),
    surface3: Color(0xFFDFD0AE),
    line: Color(0xFFC9B88F),
    track: Color(0xFFE0D3B4),
    hairline: Color(0x1F2A2017),
    text: Color(0xFF2A2017),
    textSoft: Color(0xFF52432F),
    muted: Color(0xFF6F5F45),
    hint: Color(0xFF857559),
    chevron: Color(0xFFA8987A),
    gold: Color(0xFF8A5F14),
    goldSoft: Color(0xFF6B470A),
    onGold: Color(0xFFFFF8E6),
    ember: Color(0xFFB4531C),
    amber: Color(0xFF9A6A08),
    blue: Color(0xFF2A5B8C),
    green: Color(0xFF2F6B44),
    red: Color(0xFF8D1F1F),
    silver: Color(0xFF6B7480),
    copper: Color(0xFF9A5A2A),
    header: Color(0xFF2A2017),
    onHeader: Color(0xFFD9CCB0),
    accent: Color(0xFFE8CF93),
  );

  static const night = AppPalette(
    dark: true,
    bg: Color(0xFF14100B),
    navBg: Color(0xFF0B0804),
    surface: Color(0xFF1A140D),
    surface2: Color(0xFF261D12),
    surface3: Color(0xFF30251A),
    line: Color(0xFF4A3C27),
    track: Color(0xFF2E2415),
    hairline: Color(0x14FFFFFF),
    text: Color(0xFFEFE3C8),
    textSoft: Color(0xFFCDBF9F),
    muted: Color(0xFF9C8C6E),
    hint: Color(0xFF7E705A),
    chevron: Color(0xFF6B5B42),
    gold: Color(0xFFD9A84E),
    goldSoft: Color(0xFFF0D08A),
    onGold: Color(0xFF251C12),
    ember: Color(0xFFE0803F),
    amber: Color(0xFFF0BD57),
    blue: Color(0xFF78AEE6),
    green: Color(0xFF6FD09A),
    red: Color(0xFFEC8A82),
    silver: Color(0xFFC9CED6),
    copper: Color(0xFFD69B6B),
    header: Color(0xFF0B0804),
    onHeader: Color(0xFFCDBF9F),
    accent: Color(0xFFE8CF93),
  );
}

/// the colours of the screen in front of the player. they are read when a
/// widget is built, so changing the palette is followed by building the
/// whole app again (see [AppColors.use])
class AppColors {
  static AppPalette _p = AppPalette.light;

  static AppPalette get palette => _p;
  static bool get isDark => _p.dark;

  /// switches the palette. nothing repaints by itself, the caller builds the app again
  static void use(AppPalette palette) => _p = palette;

  /// the window itself, and the darkest surface
  static Color get bg => _p.bg;

  /// the drawer and other chrome one step above the window
  static Color get navBg => _p.navBg;

  /// cards and panels
  static Color get surface => _p.surface;

  /// raised controls, hover and pressed states
  static Color get surface2 => _p.surface2;
  static Color get surface3 => _p.surface3;

  /// card borders
  static Color get line => _p.line;

  /// empty bars and slider tracks
  static Color get track => _p.track;

  /// the faint rule between rows of a card
  static Color get hairline => _p.hairline;

  static Color get text => _p.text;
  static Color get textSoft => _p.textSoft;
  static Color get muted => _p.muted;
  static Color get hint => _p.hint;

  /// trailing chevrons and other quiet row decorations
  static Color get chevron => _p.chevron;

  static Color get gold => _p.gold;
  static Color get goldSoft => _p.goldSoft;
  static Color get onGold => _p.onGold;
  static Color get ember => _p.ember;
  static Color get amber => _p.amber;
  static Color get blue => _p.blue;
  static Color get green => _p.green;
  static Color get red => _p.red;

  static Color get silver => _p.silver;
  static Color get copper => _p.copper;

  /// the bar across the top and what is written on it
  static Color get header => _p.header;
  static Color get onHeader => _p.onHeader;
  static Color get accent => _p.accent;

  /// brand colours, for tiles people should recognise at a glance
  static const coffee = Color(0xFFFFDD00);
  static const onCoffee = Color(0xFF251C12);

  /// the night sky behind the hero, as behind the plugin's live preview.
  /// night in both palettes, so what is written over it uses [skyText]
  static const skyTop = Color(0xFF141825);
  static const skyBottom = Color(0xFF07070A);
  static const skyText = Color(0xFFF6F1E8);
}

/// corner radii shared by every surface
class AppRadius {
  static const window = 10.0;
  static const card = 6.0;
  static const frame = 4.0;
}

/// headlines and titles, in the serif of the journal: Marcellus, which has one
/// weight. scripts it lacks fall back to Noto Sans
TextStyle display(double size, {Color? color}) => GoogleFonts.marcellus(
      fontSize: size,
      fontWeight: FontWeight.w400,
      color: color ?? AppColors.text,
      letterSpacing: 0.3,
    ).copyWith(fontFamilyFallback: const ['Noto Sans']);

/// the theme of the palette in use. build it again after [AppColors.use]
ThemeData buildTheme() {
  final dark = AppColors.isDark;
  final scheme = (dark ? ColorScheme.dark : ColorScheme.light)(
    primary: AppColors.gold,
    onPrimary: AppColors.onGold,
    secondary: AppColors.gold,
    onSecondary: AppColors.onGold,
    surface: AppColors.bg,
    onSurface: AppColors.text,
    onSurfaceVariant: AppColors.textSoft,
    surfaceContainerHighest: AppColors.surface2,
    outline: AppColors.line,
    outlineVariant: AppColors.track,
    error: AppColors.red,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: scheme,
  );
  const stadium = StadiumBorder();
  const frame = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AppRadius.frame)));
  const card = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)));
  const window = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AppRadius.window)));
  return base.copyWith(
    textTheme: GoogleFonts.sourceSans3TextTheme(base.textTheme).apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    // the bar across the top is dark ink in both palettes, over a gold rule
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.header,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.onHeader,
      iconTheme: IconThemeData(color: AppColors.onHeader),
      actionsIconTheme: IconThemeData(color: AppColors.onHeader),
      titleTextStyle: display(19, color: AppColors.accent),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      shape: Border(bottom: BorderSide(color: AppColors.gold, width: 2)),
    ),
    dividerTheme: DividerThemeData(color: AppColors.hairline, thickness: 1, space: 1),
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
      labelStyle: TextStyle(color: AppColors.textSoft, fontWeight: FontWeight.w600),
      secondaryLabelStyle: TextStyle(color: AppColors.goldSoft, fontWeight: FontWeight.w700),
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
    progressIndicatorTheme: ProgressIndicatorThemeData(color: AppColors.gold, linearTrackColor: AppColors.track),
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.gold,
      inactiveTrackColor: AppColors.track,
      thumbColor: AppColors.goldSoft,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surface2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.card)),
        side: BorderSide(color: AppColors.line),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: window,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: const BorderRadius.vertical(top: const Radius.circular(AppRadius.window))),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surface2,
      contentTextStyle: TextStyle(color: AppColors.text),
      behavior: SnackBarBehavior.floating,
      shape: card,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.surface3,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.frame)),
      ),
      textStyle: TextStyle(color: AppColors.text, fontSize: 12),
    ),
    tabBarTheme: TabBarThemeData(
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
    listTileTheme: ListTileThemeData(iconColor: AppColors.muted),
    cardTheme: CardThemeData(color: AppColors.surface, surfaceTintColor: Colors.transparent, shape: card),
  );
}

InputDecoration fieldDecoration(String hint, {Widget? prefixIcon, Widget? suffixIcon}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: AppColors.hint),
    filled: true,
    fillColor: AppColors.surface,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
      borderSide: BorderSide(color: AppColors.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
      borderSide: BorderSide(color: AppColors.gold),
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

/// a bright hue made dark enough to read on paper. in the dark palette it is left as it is
Color legible(Color c) {
  if (AppColors.isDark) return c;
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness(hsl.lightness.clamp(0.0, 0.36)).toColor();
}

Color professionColor(String? p) {
  final c = _professionColors[p];
  return c == null ? AppColors.gold : legible(c);
}

const _rarityColors = <String, Color>{
  'Junk': Color(0xFF8C8577),
  'Basic': Color(0xFFE6E0D6),
  'Fine': Color(0xFF5FA2E0),
  'Masterwork': Color(0xFF32A852),
  'Rare': Color(0xFFE6C20E),
  'Exotic': Color(0xFFF59E0B),
  'Ascended': Color(0xFFF0508F),
  'Legendary': Color(0xFFA15CFF),
};

Color rarityColor(String? r) {
  final c = _rarityColors[r];
  return c == null ? AppColors.line : legible(c);
}
