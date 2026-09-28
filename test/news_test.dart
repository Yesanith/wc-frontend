import 'package:flutter_test/flutter_test.dart';
import 'package:tyria_codex/l10n/strings.dart';
import 'package:tyria_codex/state/news.dart';

const _feed = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/">
<channel>
  <title>GuildWars2.com</title>
  <item>
    <title>Older post &#8211; part one</title>
    <link>https://www.guildwars2.com/en/news/older/</link>
    <pubDate>Mon, 14 Sep 2026 16:00:00 +0000</pubDate>
    <description><![CDATA[<p>Short &amp; sweet.</p>]]></description>
  </item>
  <item>
    <title><![CDATA[Castora Awaits]]></title>
    <link>https://www.guildwars2.com/en/news/castora/</link>
    <pubDate>Tue, 22 Sep 2026 16:00:00 +0000</pubDate>
    <description><![CDATA[<img src="https://example.com/castora.jpg" /><p>Explore the depths of Castora,&nbsp;face new raid encounters.</p>]]></description>
    <content:encoded><![CDATA[<p>Full text</p>]]></content:encoded>
  </item>
  <item>
    <title>No link, skipped</title>
  </item>
</channel>
</rss>''';

void main() {
  test('reads items newest first and skips broken ones', () {
    final items = parseRss(_feed);
    expect(items.map((i) => i.title), ['Castora Awaits', 'Older post – part one']);
    final first = items.first;
    expect(first.link, 'https://www.guildwars2.com/en/news/castora/');
    expect(first.date, DateTime.utc(2026, 9, 22, 16));
    expect(first.image, 'https://example.com/castora.jpg');
    expect(first.excerpt, 'Explore the depths of Castora, face new raid encounters.');
    expect(items.last.excerpt, 'Short & sweet.');
  });

  test('rss dates honour their offset', () {
    expect(parseRssDate('Tue, 22 Sep 2026 18:30:00 +0200'), DateTime.utc(2026, 9, 22, 16, 30));
    expect(parseRssDate('Tue, 22 Sep 2026 16:00:00 GMT'), DateTime.utc(2026, 9, 22, 16));
    expect(parseRssDate('not a date'), isNull);
  });

  test('long excerpts are cut at a word', () {
    final text = List.filled(80, 'word').join(' ');
    final cut = plainExcerpt(text, max: 50);
    expect(cut.endsWith('…'), isTrue);
    expect(cut.length, lessThanOrEqualTo(51));
    expect(cut.contains('wor…'), isFalse);
  });

  test('the feed language follows the app where the site has it', () {
    expect(newsLang(AppLang.de), 'de');
    expect(newsLang(AppLang.tr), 'en');
    expect(newsLang(AppLang.zh), 'en');
    expect(newsFeedUrl(AppLang.fr), 'https://www.guildwars2.com/fr/feed/');
  });

  test('patch note dates come from the page name', () {
    expect(patchDate('Game updates/2026-09-23'), DateTime.utc(2026, 9, 23));
    expect(patchDate('Game updates'), isNull);
    expect(const PatchNote('Game updates/2026-09-23', null).url, 'https://wiki.guildwars2.com/wiki/Game_updates/2026-09-23');
  });
}
