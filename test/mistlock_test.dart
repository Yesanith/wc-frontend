import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wondrous_compass/state/settings.dart';
import 'package:wondrous_compass/theme.dart';

void main() {
  group('the palette of a look', () {
    test('is the Mistlock palette whatever the phone is set to', () {
      expect(paletteFor(LookMode.mistlock, Brightness.light), same(AppPalette.mistlock));
      expect(paletteFor(LookMode.mistlock, Brightness.dark), same(AppPalette.mistlock));
    });

    test('is still parchment or candlelight for the others', () {
      expect(paletteFor(LookMode.light, Brightness.dark), same(AppPalette.light));
      expect(paletteFor(LookMode.dark, Brightness.light), same(AppPalette.night));
      expect(paletteFor(LookMode.system, Brightness.dark), same(AppPalette.night));
      expect(paletteFor(LookMode.system, Brightness.light), same(AppPalette.light));
    });
  });

  group('Mistlock', () {
    tearDown(() => AppColors.use(AppPalette.light));

    test('is dark, with an aqua accent, the emblem in gold and titles in Cinzel', () {
      AppColors.use(AppPalette.mistlock);
      expect(AppColors.isDark, isTrue);
      expect(AppColors.gold, const Color(0xFF6FE3FF));
      expect(AppColors.emblem, const Color(0xFFD8B25A));
      expect(AppColors.coinGold, const Color(0xFFF0CD7A));
      expect(AppColors.palette.cinzelTitles, isTrue);
    });

    test('leaves the other palettes as they were: the emblem and the coin are their gold', () {
      for (final p in [AppPalette.light, AppPalette.night]) {
        AppColors.use(p);
        expect(AppColors.coinGold, p.gold);
        expect(AppColors.palette.cinzelTitles, isFalse);
      }
    });

    test('is what the look is saved as', () {
      expect(LookMode.values.map((m) => m.name), contains('mistlock'));
    });
  });
}
