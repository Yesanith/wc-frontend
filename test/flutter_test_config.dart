import 'dart:async';

import 'package:wondrous_compass/l10n/strings.dart';

/// run before every test file: the words of every language are loaded, as the app loads the one it shows before showing it
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await loadAllLanguages();
  await testMain();
}
