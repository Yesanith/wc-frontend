import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wondrous_compass/api/gw2_api.dart';
import 'package:wondrous_compass/state/navigation.dart';
import 'package:wondrous_compass/state/settings.dart';
import 'package:wondrous_compass/widgets/common.dart';

const _guild = '4BBB52AA-D768-4FC6-8EDE-C299F2822F0F';

void main() {
  test('account data needs a key, public data does not', () {
    for (final path in [
      '/account',
      '/v2/account/wallet',
      '/account/wizardsvault/daily',
      '/characters',
      '/characters/Name%20Here/equipment',
      '/tokeninfo',
      '/createsubtoken',
      '/commerce/transactions/current/buys',
      '/commerce/delivery',
      '/pvp/stats',
      '/pvp/games',
      '/pvp/standings',
      '/guild/$_guild/members',
      '/guild/$_guild/treasury',
      '/guild/$_guild/upgrades',
    ]) {
      expect(pathNeedsKey(path), isTrue, reason: path);
    }
    for (final path in [
      '/items',
      '/commerce/prices',
      '/commerce/listings',
      '/commerce/exchange/gems',
      '/recipes',
      '/maps',
      '/continents/1/floors/0',
      '/wizardsvault',
      '/wizardsvault/listings',
      '/achievements/categories',
      '/pvp/seasons',
      '/wvw/matches',
      '/guild/$_guild',
      '/guild/emblem/backgrounds',
      '/guild/search',
      '/guild/upgrades',
      '/guild/permissions',
      '/accounts',
      '/build',
    ]) {
      expect(pathNeedsKey(path), isFalse, reason: path);
    }
  });

  test('a guest asking for account data gets its answer without a request', () async {
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response('{"id": 1}', 200);
    });
    final guest = Gw2Api(null, client: client);
    expect(guest.hasKey, isFalse);
    await expectLater(
      guest.get('/account'),
      throwsA(isA<Gw2ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.noKey)),
    );
    await expectLater(
      guest.get('/characters'),
      throwsA(isA<Gw2ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.noKey)),
    );
    expect(requests, 0);
    // public data goes out as usual
    await guest.get('/build');
    expect(requests, 1);
    // an empty key is no key
    expect(Gw2Api('', client: client).hasKey, isFalse);
  });

  test('with a key the same request goes out', () async {
    var requests = 0;
    final keyed = Gw2Api(
      'ABCD-1234',
      client: MockClient((request) async {
        requests++;
        expect(request.headers['Authorization'], 'Bearer ABCD-1234');
        return http.Response('{"name": "Leo.1234"}', 200);
      }),
    );
    expect(keyed.hasKey, isTrue);
    expect((await keyed.get('/account') as Map)['name'], 'Leo.1234');
    expect(requests, 1);
  });

  test('only the sections about the account are held back from a guest', () {
    for (final s in [
      AppSection.daily,
      AppSection.weekly,
      AppSection.characters,
      AppSection.collections,
      AppSection.progression,
      AppSection.wvw,
      AppSection.account,
      AppSection.guilds,
    ]) {
      expect(sectionNeedsKey(s), isTrue, reason: '$s');
    }
    for (final s in [
      AppSection.home,
      AppSection.bosses,
      AppSection.maps,
      AppSection.recipes,
      AppSection.trading,
      AppSection.professions,
      AppSection.wiki,
      AppSection.news,
      AppSection.settings,
      AppSection.about,
      AppSection.guildEvents,
      AppSection.publicEvents,
      AppSection.recruitment,
    ]) {
      expect(sectionNeedsKey(s), isFalse, reason: '$s');
    }
  });

  test('the guest choice is remembered and can be cleared', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    ProviderContainer container() => ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);

    final first = container();
    expect(first.read(guestModeProvider), isFalse);
    await first.read(guestModeProvider.notifier).set(true);
    first.dispose();

    final second = container();
    expect(second.read(guestModeProvider), isTrue, reason: 'kept between launches');
    await second.read(guestModeProvider.notifier).set(false);
    expect(second.read(guestModeProvider), isFalse);
    second.dispose();
  });
}
