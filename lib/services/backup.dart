import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/strings.dart';
import '../state/price_history.dart';
import '../state/progression.dart';
import '../state/settings.dart';
import 'cache.dart';

/// everything the app keeps locally, minus the api key. plain json so it
/// can be moved between phones or kept as a backup
Map<String, dynamic> buildBackup(WidgetRef ref) {
  return {
    'version': 1,
    'exported_at': DateTime.now().toIso8601String(),
    'lang': ref.read(langProvider).code,
    'watchlist': ref.read(watchlistProvider),
    'pinned_events': ref.read(pinnedEventsProvider).toList(),
    'pinned_achievements': ref.read(pinnedAchievementsProvider),
    'price_history': {
      for (final e in ref.read(priceHistoryProvider).entries) '${e.key}': e.value.map((p) => p.toJson()).toList(),
    },
  };
}

Future<void> shareBackup(WidgetRef ref) async {
  final text = const JsonEncoder.withIndent('  ').convert(buildBackup(ref));
  if (kIsWeb) {
    // a browser has no temporary directory, the file is made from the bytes
    final bytes = Uint8List.fromList(utf8.encode(text));
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'application/json', name: 'wondrous-compass-backup.json')],
        text: 'Wondrous Compass backup',
      ),
    );
    return;
  }
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/wondrous-compass-backup.json');
  await file.writeAsString(text);
  await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: 'Wondrous Compass backup'));
}

/// throws when the text is not a backup we understand
Future<void> restoreBackup(WidgetRef ref, String text) async {
  final raw = jsonDecode(text);
  if (raw is! Map) throw const FormatException('not a backup');

  final lang = raw['lang'];
  if (lang is String) await ref.read(langProvider.notifier).set(AppLang.fromCode(lang));

  final watchlist = raw['watchlist'];
  if (watchlist is List) {
    await ref
        .read(watchlistProvider.notifier)
        .replaceAll(watchlist.map((e) => int.tryParse('$e') ?? 0).where((e) => e > 0).toList());
  }

  final pinned = raw['pinned_events'];
  if (pinned is List) {
    await ref.read(pinnedEventsProvider.notifier).replaceAll(pinned.map((e) => '$e').toSet());
  }

  final achievements = raw['pinned_achievements'];
  if (achievements is List) {
    await ref
        .read(pinnedAchievementsProvider.notifier)
        .replaceAll(achievements.map((e) => int.tryParse('$e') ?? 0).where((e) => e > 0).toList());
  }

  final history = raw['price_history'];
  if (history is Map) {
    await ref.read(priceHistoryProvider.notifier).replaceAll({
      for (final e in history.entries)
        if (int.tryParse('${e.key}') != null && e.value is List)
          int.parse('${e.key}'): [
            for (final p in e.value as List)
              if (p is Map) PricePoint.fromJson(Map<String, dynamic>.from(p)),
          ],
    });
  }
}

Future<void> clearCache(DiskCache? cache) async => cache?.clear();
