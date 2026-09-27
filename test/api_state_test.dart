import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tyria_codex/api/gw2_api.dart';
import 'package:tyria_codex/services/cache.dart';
import 'package:tyria_codex/services/icon_cache.dart';
import 'package:tyria_codex/services/item_index.dart';
import 'package:tyria_codex/state/api.dart';
import 'package:tyria_codex/state/settings.dart';
import 'package:tyria_codex/state/wealth.dart';
import 'package:tyria_codex/util.dart';

/// secure storage backed by a map, the plugin needs a device
class _MemoryStorage implements FlutterSecureStorage {
  final Map<String, String> values = {};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final key = invocation.namedArguments[#key] as String?;
    switch (invocation.memberName) {
      case #read:
        return Future.value(values[key]);
      case #write:
        final value = invocation.namedArguments[#value] as String?;
        if (value == null) {
          values.remove(key);
        } else {
          values[key!] = value;
        }
        return Future<void>.value();
      case #delete:
        values.remove(key);
        return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

Future<ProviderContainer> _container({Map<String, Object> prefs = const {}, _MemoryStorage? storage}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final container = ProviderContainer(overrides: [
    prefsProvider.overrideWithValue(await SharedPreferences.getInstance()),
    storageProvider.overrideWithValue(storage ?? _MemoryStorage()),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('saved keys', () {
    Future<ProviderContainer> withKeys(List<String> keys, int active) async {
      final storage = _MemoryStorage();
      storage.values['gw2_api_keys'] = jsonEncode([
        for (final k in keys) {'name': k, 'key': k},
      ]);
      final container = await _container(prefs: {'active_key': active}, storage: storage);
      await container.read(keysProvider.future);
      return container;
    }

    test('removing a key before the active one keeps the same account', () async {
      final c = await withKeys(['A', 'B', 'C'], 1);
      await c.read(keysProvider.notifier).removeAt(0);
      expect(c.read(apiKeyProvider).valueOrNull, 'B');
      expect(c.read(activeKeyProvider), 0);
    });

    test('removing a key after the active one changes nothing', () async {
      final c = await withKeys(['A', 'B', 'C'], 0);
      await c.read(keysProvider.notifier).removeAt(2);
      expect(c.read(apiKeyProvider).valueOrNull, 'A');
      expect(c.read(activeKeyProvider), 0);
    });

    test('removing the last key while it is active falls back to the new last', () async {
      final c = await withKeys(['A', 'B', 'C'], 2);
      await c.read(keysProvider.notifier).removeAt(2);
      expect(c.read(apiKeyProvider).valueOrNull, 'B');
    });

    test('removing every key leaves no key', () async {
      final c = await withKeys(['A'], 0);
      await c.read(keysProvider.notifier).removeAt(0);
      expect(c.read(apiKeyProvider).valueOrNull, isNull);
      expect(c.read(activeKeyProvider), 0);
    });
  });

  group('Gw2Api', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('tyria_cache_test');
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('the key goes in a header, never in the url', () async {
      late http.Request seen;
      final api = Gw2Api('SECRET', client: MockClient((req) async {
        seen = req;
        return http.Response('{"name":"x"}', 200);
      }));
      await api.get('/account');
      expect(seen.headers['Authorization'], 'Bearer SECRET');
      expect(seen.url.toString(), isNot(contains('SECRET')));
    });

    test('cachedGet answers from disk and refreshes stale entries behind the scenes', () async {
      var calls = 0;
      var revalidated = 0;
      // completes once the background refresh has fetched and written the
      // new copy, a fixed delay is too short on a slow machine
      final refreshed = Completer<void>();
      final cache = DiskCache(dir);
      final api = Gw2Api(
        'key',
        cache: cache,
        onRevalidated: () {
          revalidated++;
          if (!refreshed.isCompleted) refreshed.complete();
        },
        client: MockClient((req) async {
          calls++;
          return http.Response(jsonEncode({'n': calls}), 200);
        }),
      );

      // empty cache: waits on the network
      expect(await api.cachedGet('/account'), {'n': 1});
      // fresh copy: no request at all
      expect(await api.cachedGet('/account'), {'n': 1});
      expect(calls, 1);

      // stale copy: served at once, refreshed in the background
      expect(await api.cachedGet('/account', ttl: Duration.zero), {'n': 1});
      await refreshed.future.timeout(const Duration(seconds: 10));
      expect(calls, 2);
      expect(revalidated, 1);
      expect(await api.cachedGet('/account'), {'n': 2});
    });

    test('clearStaticCaches makes the next lookup ask the api again', () async {
      var calls = 0;
      final api = Gw2Api('key', client: MockClient((req) async {
        calls++;
        return http.Response(
            jsonEncode([
              {'id': 1, 'name': 'Name $calls'},
            ]),
            200);
      }));
      expect((await api.items([1]))[1]?['name'], 'Name 1');
      expect((await api.items([1]))[1]?['name'], 'Name 1');
      expect(calls, 1);

      api.clearStaticCaches();
      expect((await api.items([1]))[1]?['name'], 'Name 2');
      expect(calls, 2);
    });
  });

  group('wealth history', () {
    test('a second snapshot on the same day replaces the first', () async {
      final c = await _container();
      final notifier = c.read(wealthProvider.notifier);
      final day = DateTime(2026, 9, 27, 10);
      await notifier.record('Acc.1234', const [WalletEntry(1, 100, 'Coin', null, 0)], now: day);
      await notifier.record('Acc.1234', const [WalletEntry(1, 250, 'Coin', null, 0)], now: day);
      await notifier.record(
        'Acc.1234',
        const [WalletEntry(1, 300, 'Coin', null, 0)],
        now: day.add(const Duration(days: 1)),
      );
      final points = c.read(wealthProvider)['Acc.1234']!;
      expect(points.map((p) => p.coins), [250, 300]);
    });

    test('accounts keep separate histories', () async {
      final c = await _container();
      final notifier = c.read(wealthProvider.notifier);
      await notifier.record('A.1', const [WalletEntry(1, 1, 'Coin', null, 0)]);
      await notifier.record('B.2', const [WalletEntry(1, 2, 'Coin', null, 0)]);
      expect(c.read(wealthProvider)['A.1']!.single.coins, 1);
      expect(c.read(wealthProvider)['B.2']!.single.coins, 2);
    });
  });

  test('item search keeps an exact match that comes after many prefix matches', () {
    final index = ItemIndex([
      for (var i = 0; i < 100; i++) IndexedItem(i, 'Mithril Ore $i'),
      IndexedItem(500, 'Mithril Ore'),
    ]);
    final hits = index.search('mithril ore', limit: 10);
    expect(hits.first.id, 500);
    expect(hits, hasLength(10));
  });

  test('the icon cache does not ask again for a url that was missing', () async {
    final dir = await Directory.systemTemp.createTemp('tyria_icon_test');
    addTearDown(() => dir.delete(recursive: true));
    var calls = 0;
    final cache = IconCache(
      dir,
      null,
      MockClient((req) async {
        calls++;
        return http.Response('', 404);
      }),
    );
    const url = 'https://tiles.guildwars2.com/1/0/2/0/0.jpg';
    expect(await cache.fetch(url), isNull);
    await Future<void>.delayed(Duration.zero);
    expect(await cache.fetch(url), isNull);
    expect(calls, 1);
  });
}
