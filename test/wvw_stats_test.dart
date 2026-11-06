import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wondrous_compass/api/gw2_api.dart';
import 'package:wondrous_compass/state/wvw.dart';

// answers of the game as they were on 2026-10-19, cut down
const _scores = {
  'id': '2-1',
  'scores': {'red': 122642, 'blue': 160706, 'green': 201803},
  'victory_points': {'red': 625, 'blue': 656, 'green': 873},
  'skirmishes': [
    {
      'id': 1,
      'scores': {'red': 5280, 'blue': 4334, 'green': 10146},
      'map_scores': [
        {
          'type': 'Center',
          'scores': {'red': 556, 'blue': 685, 'green': 3624},
        },
      ],
    },
    {
      'id': 3,
      'scores': {'red': 10, 'blue': 20, 'green': 30},
      'map_scores': <Map>[],
    },
    {
      'id': 2,
      'scores': {'red': 1, 'blue': 2},
      'map_scores': <Map>[],
    },
  ],
};

Gw2Api _api(http.Response Function(http.Request) answer, [List<Uri>? seen]) =>
    Gw2Api('key', client: MockClient((req) async {
      seen?.add(req.url);
      return answer(req);
    }));

void main() {
  group('wvw statistics', () {
    test('kills per death is the kills while nobody died', () {
      expect(wvwKdr(10, 4), 2.5);
      expect(wvwKdr(7, 0), 7);
      expect(wvwKdr(0, 0), 0);
    });

    test('the skirmishes come newest first, a colour without points has none', () {
      final list = wvwSkirmishes(_scores);
      expect(list.map((s) => s.id), [3, 2, 1]);
      expect(list.first.scores, {'red': 10, 'blue': 20, 'green': 30});
      expect(list[1].scores['green'], 0);
      expect(wvwSkirmishes(null), isEmpty);
      expect(wvwSkirmishes({'skirmishes': 'no'}), isEmpty);
    });

    test('a row of a top list carries a guild and the number it is ranked by', () {
      final named = wvwTopRow({'id': 'ABC', 'name': 'Mistwalkers', 'tag': 'MIST', 'kdr': 2.75});
      expect([named.guildId, named.name, named.tag, named.value], ['ABC', 'Mistwalkers', 'MIST', 2.75]);
      final bare = wvwTopRow({'guild_id': 'DEF', 'kills': 1200});
      expect([bare.guildId, bare.name, bare.value], ['DEF', '', 1200]);
      expect(wvwTopRow({'id': 'X'}).value, isNull);
    });

    test('the lighter views of a match ask by match id', () async {
      final seen = <Uri>[];
      final api = _api((req) => http.Response(jsonEncode({'id': '2-1', 'kills': {}}), 200), seen);
      expect((await api.wvwMatchPart('stats', '2-1'))?['id'], '2-1');
      expect(seen.single.path, '/v2/wvw/matches/stats');
      expect(seen.single.queryParameters['id'], '2-1');
    });

    test('a match that is gone is no match, not an error', () async {
      final api = _api((_) => http.Response('{"text":"no such id"}', 404));
      expect(await api.wvwMatchPart('scores', '9-9'), isNull);
    });

    test('the top lists are empty while the game has nothing to rank', () async {
      final seen = <Uri>[];
      final empty = _api((_) => http.Response('[]', 200), seen);
      expect(await empty.wvwTopGuilds('2-1', 12013, 'kdr'), isEmpty);
      expect(seen.single.path, '/v2/wvw/matches/stats/2-1/teams/12013/top/kdr');
      final missing = _api((_) => http.Response('{"text":"no data"}', 404));
      expect(await missing.wvwTopGuilds('2-1', 12013, 'kills'), isEmpty);
      final some = _api((_) => http.Response('[{"id":"A","name":"Guild","kills":5}]', 200));
      expect((await some.wvwTopGuilds('2-1', 12013, 'kills')).single['name'], 'Guild');
    });

    test('a guild the game has no data for has no stats', () async {
      final seen = <Uri>[];
      final nothing = _api((_) => http.Response('{"text":"no data for guild"}', 200), seen);
      expect(await nothing.wvwGuildStats('2-1', 'AAAA'), isNull);
      expect(seen.single.path, '/v2/wvw/matches/stats/2-1/guilds/AAAA');
      final gone = _api((_) => http.Response('{"text":"no data for guild"}', 404));
      expect(await gone.wvwGuildStats('2-1', 'AAAA'), isNull);
      final data = _api((_) => http.Response('{"kills":10,"deaths":4}', 200));
      expect((await data.wvwGuildStats('2-1', 'AAAA'))?['kills'], 10);
    });
  });
}
