import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tyria_codex/api/gw2_api.dart';
import 'package:tyria_codex/services/gunzip.dart';
import 'package:tyria_codex/state/community.dart';

void main() {
  group('the game\'s api in a browser', () {
    const base = 'https://api.guildwars2.com/v2';
    const key = 'ABCD-1234';

    test('the key goes in the address, because the api answers no CORS preflight', () {
      final uri = gw2Uri(base, '/account', lang: 'en', key: key, web: true);
      expect(uri.queryParameters['access_token'], key);
      expect(gw2Headers(key, web: true), isNull, reason: 'a header would ask for a preflight');
    });

    test('anywhere else the key stays out of the address, in a header', () {
      final uri = gw2Uri(base, '/account', lang: 'en', key: key);
      expect(uri.toString().contains(key), isFalse);
      expect(uri.queryParameters.containsKey('access_token'), isFalse);
      expect(gw2Headers(key), {'Authorization': 'Bearer $key'});
    });

    test('a request without a key carries none, in a browser or not', () {
      for (final web in [true, false]) {
        for (final none in [null, '']) {
          final uri = gw2Uri(base, '/items', lang: 'de', key: none, web: web);
          expect(uri.queryParameters.containsKey('access_token'), isFalse, reason: 'web $web');
          expect(gw2Headers(none, web: web), isNull);
        }
      }
    });

    test('the rest of the request is the same', () {
      final uri = gw2Uri(base, '/items', query: {'ids': '1,2'}, lang: 'fr', key: key, web: true);
      expect(uri.path, '/v2/items');
      expect(uri.queryParameters['ids'], '1,2');
      expect(uri.queryParameters['lang'], 'fr');
      expect(uri.queryParameters['v'], 'latest');
    });
  });

  group('bundled data in a browser', () {
    test('gzip data unpacks to what was packed', () {
      final packed = gzip.encode(utf8.encode('{"items":[1,2,3],"name":"Tyria"}'));
      expect(utf8.decode(gunzip(packed)), '{"items":[1,2,3],"name":"Tyria"}');
    });

    test('a larger text, and text that is not ascii, survive too', () {
      final text = List.generate(2000, (i) => 'Küçük Ejderha $i · 龙 ').join();
      expect(utf8.decode(gunzip(gzip.encode(utf8.encode(text)))), text);
    });
  });

  group('signing in from a browser', () {
    test('the page the player comes back to is the app\'s address as configured', () {
      expect(webAuthRedirect('https://yesanith.github.io/tyria-companion/app/', Uri.parse('http://localhost:8080/')),
          'https://yesanith.github.io/tyria-companion/app/');
    });

    test('without one, the address of the page, with no query, fragment or index file', () {
      expect(webAuthRedirect('', Uri.parse('https://example.com/app/?code=abc#/home')), 'https://example.com/app/');
      expect(webAuthRedirect('', Uri.parse('https://example.com/app/index.html')), 'https://example.com/app/');
      expect(webAuthRedirect('', Uri.parse('https://example.com/app/')), 'https://example.com/app/');
    });

    test('the phone\'s app keeps its own address', () {
      expect(authRedirect, 'tyriacodex://login-callback');
    });
  });
}
