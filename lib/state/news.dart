import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../l10n/strings.dart';
import '../services/cache.dart';
import 'api.dart';
import 'settings.dart';

/// one article of the official news feed
class NewsItem {
  const NewsItem({required this.title, required this.link, this.date, this.excerpt = '', this.image});

  final String title;
  final String link;
  final DateTime? date;
  final String excerpt;
  final String? image;

  Map<String, dynamic> toJson() => {
        't': title,
        'l': link,
        if (date != null) 'd': date!.toIso8601String(),
        'e': excerpt,
        if (image != null) 'i': image,
      };

  static NewsItem fromJson(Map<String, dynamic> j) => NewsItem(
        title: '${j['t'] ?? ''}',
        link: '${j['l'] ?? ''}',
        date: DateTime.tryParse('${j['d'] ?? ''}'),
        excerpt: '${j['e'] ?? ''}',
        image: j['i'] as String?,
      );
}

/// the site publishes in these languages, everything else reads english
String newsLang(AppLang lang) => const {'de', 'fr', 'es'}.contains(lang.code) ? lang.code : 'en';

String newsFeedUrl(AppLang lang) => 'https://www.guildwars2.com/${newsLang(lang)}/feed/';

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};

/// "Tue, 22 Sep 2026 16:00:00 +0000", the rss date format, read as utc
DateTime? parseRssDate(String raw) {
  final m = RegExp(r'(\d{1,2})\s+([A-Za-z]{3})[a-z]*\s+(\d{4})\s+(\d{2}):(\d{2})(?::(\d{2}))?\s*([+-]\d{4}|GMT|UTC|Z)?')
      .firstMatch(raw);
  if (m == null) return null;
  final month = _months[m.group(2)!.toLowerCase()];
  if (month == null) return null;
  var at = DateTime.utc(int.parse(m.group(3)!), month, int.parse(m.group(1)!), int.parse(m.group(4)!),
      int.parse(m.group(5)!), int.parse(m.group(6) ?? '0'));
  final zone = m.group(7);
  if (zone != null && (zone.startsWith('+') || zone.startsWith('-'))) {
    final sign = zone.startsWith('-') ? -1 : 1;
    final offset = Duration(hours: int.parse(zone.substring(1, 3)), minutes: int.parse(zone.substring(3, 5)));
    at = sign > 0 ? at.subtract(offset) : at.add(offset);
  }
  return at;
}

/// html entities that show up in feed titles and excerpts
String decodeEntities(String text) {
  const named = {'amp': '&', 'lt': '<', 'gt': '>', 'quot': '"', 'apos': "'", 'nbsp': ' ', 'hellip': '…', 'ndash': '–', 'mdash': '—'};
  return text.replaceAllMapped(RegExp(r'&(#x[0-9a-fA-F]+|#\d+|[a-zA-Z]+);'), (m) {
    final code = m.group(1)!;
    if (code.startsWith('#x')) return String.fromCharCode(int.parse(code.substring(2), radix: 16));
    if (code.startsWith('#')) return String.fromCharCode(int.parse(code.substring(1)));
    return named[code] ?? m.group(0)!;
  });
}

String _stripCdata(String s) => s.replaceAllMapped(RegExp(r'<!\[CDATA\[(.*?)\]\]>', dotAll: true), (m) => m.group(1)!);

String? _tag(String block, String name) {
  final m = RegExp('<$name\\b[^>]*>(.*?)</$name>', dotAll: true).firstMatch(block);
  return m == null ? null : _stripCdata(m.group(1)!).trim();
}

/// a readable excerpt: tags and entities gone, whitespace collapsed, cut at
/// a word near [max] characters
String plainExcerpt(String html, {int max = 220}) {
  var text = decodeEntities(html.replaceAll(RegExp(r'<[^>]*>'), ' ')).replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.length <= max) return text;
  final cut = text.lastIndexOf(' ', max);
  text = text.substring(0, cut > max ~/ 2 ? cut : max).trimRight();
  return '$text…';
}

/// the items of an rss 2.0 feed. no xml package: wordpress feeds are regular
/// enough for a few patterns, and anything unreadable is skipped
List<NewsItem> parseRss(String xml) {
  final out = <NewsItem>[];
  for (final m in RegExp(r'<item\b[^>]*>(.*?)</item>', dotAll: true).allMatches(xml)) {
    final block = m.group(1)!;
    final title = decodeEntities(_tag(block, 'title') ?? '').trim();
    final link = (_tag(block, 'link') ?? '').trim();
    if (title.isEmpty || link.isEmpty) continue;
    final content = _tag(block, 'content:encoded') ?? '';
    final description = _tag(block, 'description') ?? '';
    final image = RegExp(r'''<media:(?:content|thumbnail)[^>]+url=["']([^"']+)''').firstMatch(block)?.group(1) ??
        RegExp(r'''<enclosure[^>]+url=["']([^"']+)''').firstMatch(block)?.group(1) ??
        RegExp(r'''<img[^>]+src=["']([^"']+)''').firstMatch(content)?.group(1) ??
        RegExp(r'''<img[^>]+src=["']([^"']+)''').firstMatch(description)?.group(1);
    out.add(NewsItem(
      title: title,
      link: link,
      date: parseRssDate(_tag(block, 'pubDate') ?? ''),
      excerpt: plainExcerpt(description.isNotEmpty ? description : content),
      image: image == null ? null : decodeEntities(image),
    ));
  }
  out.sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));
  return out;
}

final _client = http.Client();

/// the official news of the app's language, the last copy stays readable
/// offline
final newsProvider = FutureProvider<List<NewsItem>>((ref) async {
  final lang = ref.watch(langProvider);
  final cache = ref.watch(diskCacheProvider);
  final name = 'news_${newsLang(lang)}';
  try {
    final res = await _client.get(Uri.parse(newsFeedUrl(lang))).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw Exception('news feed answered ${res.statusCode}');
    final items = parseRss(utf8.decode(res.bodyBytes));
    if (items.isEmpty) throw Exception('news feed had no items');
    await cache?.write(name, {'items': items.map((i) => i.toJson()).toList()});
    return items;
  } catch (e) {
    final cached = await cache?.read(name, maxAge: const Duration(days: 60));
    final rows = cached?['items'];
    if (rows is List && rows.isNotEmpty) {
      return [for (final r in rows) if (r is Map) NewsItem.fromJson(Map<String, dynamic>.from(r))];
    }
    rethrow;
  }
});

/// one game update page of the english wiki
class PatchNote {
  const PatchNote(this.title, this.date);
  final String title;
  final DateTime? date;

  String get url => 'https://wiki.guildwars2.com/wiki/${Uri.encodeComponent(title.replaceAll(' ', '_')).replaceAll('%2F', '/')}';
}

/// "Game updates/2026-09-23" -> the date in its name
DateTime? patchDate(String title) {
  final m = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(title);
  return m == null ? null : DateTime.utc(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
}

/// the latest update notes. their page names sort by date, so the newest
/// come first when listed in reverse
final patchNotesProvider = FutureProvider<List<PatchNote>>((ref) async {
  final cache = ref.watch(diskCacheProvider);
  final uri = Uri.parse('https://wiki.guildwars2.com/api.php').replace(queryParameters: {
    'action': 'query',
    'list': 'allpages',
    'apprefix': 'Game updates/',
    'apnamespace': '0',
    'apdir': 'descending',
    'aplimit': '30',
    'format': 'json',
  });
  try {
    final res = await _client.get(uri).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw Exception('wiki answered ${res.statusCode}');
    final pages = ((jsonDecode(utf8.decode(res.bodyBytes)) as Map)['query']?['allpages'] as List?) ?? const [];
    final notes = [
      for (final p in pages)
        if (p is Map && patchDate('${p['title']}') != null) PatchNote('${p['title']}', patchDate('${p['title']}')),
    ];
    await cache?.write('patch_notes', {'titles': notes.map((n) => n.title).toList()});
    return notes;
  } catch (e) {
    final cached = await cache?.read('patch_notes', maxAge: const Duration(days: 60));
    final titles = cached?['titles'];
    if (titles is List && titles.isNotEmpty) return [for (final t in titles) PatchNote('$t', patchDate('$t'))];
    rethrow;
  }
});

/// the date of the newest article the user has seen
class NewsSeenNotifier extends Notifier<DateTime?> {
  static const _key = 'news_seen';

  @override
  DateTime? build() => DateTime.tryParse(ref.read(prefsProvider).getString(_key) ?? '');

  Future<void> markSeen(DateTime newest) async {
    final current = state;
    if (current != null && !newest.isAfter(current)) return;
    state = newest;
    await ref.read(prefsProvider).setString(_key, newest.toIso8601String());
  }
}

final newsSeenProvider = NotifierProvider<NewsSeenNotifier, DateTime?>(NewsSeenNotifier.new);

/// articles newer than the last one seen. on first use nothing counts as
/// new, the whole feed would otherwise shout at a fresh install
final unseenNewsProvider = Provider<int>((ref) {
  final items = ref.watch(newsProvider).valueOrNull ?? const <NewsItem>[];
  final seen = ref.watch(newsSeenProvider);
  if (seen == null) return 0;
  return items.where((i) => i.date != null && i.date!.isAfter(seen)).length;
});
