import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wondrous_compass/l10n/strings.dart';

/// run before every test file: the words of every language are loaded, as the app loads the one it shows before showing it,
/// and the fonts that come with the app, so that one arriving in the middle of a test does not lay its page out again after it
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  await loadAllLanguages();
  for (final weight in [FontWeight.w400, FontWeight.w500, FontWeight.w600, FontWeight.w700, FontWeight.w800]) {
    GoogleFonts.sourceSans3(fontWeight: weight);
  }
  GoogleFonts.sourceSans3(fontStyle: FontStyle.italic);
  GoogleFonts.sourceSans3(fontWeight: FontWeight.w500, fontStyle: FontStyle.italic);
  GoogleFonts.marcellus();
  GoogleFonts.cinzel(fontWeight: FontWeight.w600);
  await GoogleFonts.pendingFonts();
  await testMain();
}
