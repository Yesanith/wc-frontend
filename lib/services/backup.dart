import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/strings.dart';
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
    'goals': ref.read(goalsProvider).map((g) => g.toJson()).toList(),
  };
}

Future<void> shareBackup(WidgetRef ref) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/tyria-codex-backup.json');
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(buildBackup(ref)));
  await Share.shareXFiles([XFile(file.path)], text: 'Tyria Codex backup');
}

/// throws when the text is not a backup we understand
Future<void> restoreBackup(WidgetRef ref, String text) async {
  final raw = jsonDecode(text);
  if (raw is! Map) throw const FormatException('not a backup');

  final lang = raw['lang'];
  if (lang is String) await ref.read(langProvider.notifier).set(AppLang.fromCode(lang));

  final watchlist = raw['watchlist'];
  if (watchlist is List) {
    await ref.read(watchlistProvider.notifier).replaceAll(
          watchlist.map((e) => int.tryParse('$e') ?? 0).where((e) => e > 0).toList(),
        );
  }

  final pinned = raw['pinned_events'];
  if (pinned is List) {
    await ref.read(pinnedEventsProvider.notifier).replaceAll(pinned.map((e) => '$e').toSet());
  }

  final goals = raw['goals'];
  if (goals is List) {
    await ref.read(goalsProvider.notifier).replaceAll(
          goals.whereType<Map>().map((e) => Goal.fromJson(Map<String, dynamic>.from(e))).toList(),
        );
  }
}

Future<void> clearCache(DiskCache? cache) async => cache?.clear();
