import 'dart:convert';

import 'package:http/http.dart' as http;

class WikiResult {
  const WikiResult(this.title, this.url);
  final String title;
  final String url;
}

/// Search via the MediaWiki API of the official Guild Wars 2 Wiki.
class WikiApi {
  static const base = 'https://wiki.guildwars2.com';

  static String pageUrl(String title) =>
      '$base/wiki/${Uri.encodeComponent(title.replaceAll(' ', '_'))}';

  Future<List<WikiResult>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final uri = Uri.parse('$base/api.php').replace(queryParameters: {
      'action': 'opensearch',
      'search': q,
      'limit': '20',
      'namespace': '0',
      'format': 'json',
    });
    final res = await http
        .get(uri, headers: {'User-Agent': 'TyriaCodex/0.1 (Flutter GW2 companion app)'})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Wiki hatası (${res.statusCode})');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (data is! List || data.length < 4) return const [];
    final titles = (data[1] as List).map((e) => '$e').toList();
    final urls = (data[3] as List).map((e) => '$e').toList();
    return [
      for (var i = 0; i < titles.length; i++)
        WikiResult(titles[i], i < urls.length ? urls[i] : pageUrl(titles[i])),
    ];
  }
}
