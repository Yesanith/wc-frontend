import 'package:flutter_test/flutter_test.dart';
import 'package:wondrous_compass/l10n/strings.dart';
import 'package:wondrous_compass/state/news.dart';

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
    expect(const PatchNote('Game updates/2026-09-23', null).url,
        'https://wiki.guildwars2.com/wiki/Game_updates/2026-09-23');
  });

  test('images from the real feed shape: no scheme, a srcset, or only a video', () {
    const block = '''
<item>
  <title>WvW map beta</title>
  <link>https://www.guildwars2.com/en/news/wvw-map/?utm_source=rss&#038;utm_medium=news&#038;utm_campaign=rss</link>
  <pubDate>Tue, 22 Sep 2026 16:00:21 +0000</pubDate>
  <description><![CDATA[Learn how we'll be developing this map!</p><p class="more"><a href="https://x">Read More</a></p>]]></description>
  <content:encoded><![CDATA[<p class="screenshot"><img src="//cdn.example.net/uploads/2026/09/map-1920x1080.jpg" srcset="https://cdn.example.net/uploads/2026/09/map-1920x1080.jpg 1920w, https://cdn.example.net/uploads/2026/09/map-1920x1080-768x432.jpg 768w" /></p>]]></content:encoded>
</item>
<item>
  <title>Video only</title>
  <link>https://www.guildwars2.com/en/news/video/</link>
  <pubDate>Wed, 15 Jul 2026 16:00:28 +0000</pubDate>
  <description><![CDATA[Playstyles.</p><p class="more"><a href="https://x">Read More</a></p>]]></description>
  <content:encoded><![CDATA[<p><iframe src="//www.youtube.com/embed/Trq7RIS0Eoo?rel=0"></iframe></p>]]></content:encoded>
</item>
<item>
  <title>Bare image</title>
  <link>https://www.guildwars2.com/en/news/bare/</link>
  <pubDate>Mon, 13 Jul 2026 16:00:00 +0000</pubDate>
  <description><![CDATA[Text.]]></description>
  <content:encoded><![CDATA[<img src="//cdn.example.net/a.jpg" />]]></content:encoded>
</item>''';
    final items = parseRss('<rss><channel>$block</channel></rss>');
    expect(items[0].image, 'https://cdn.example.net/uploads/2026/09/map-1920x1080-768x432.jpg');
    expect(items[0].link, 'https://www.guildwars2.com/en/news/wvw-map/');
    expect(items[0].excerpt, "Learn how we'll be developing this map!");
    expect(items[1].image, 'https://img.youtube.com/vi/Trq7RIS0Eoo/hqdefault.jpg');
    expect(items[1].excerpt, 'Playstyles.');
    expect(items[2].image, 'https://cdn.example.net/a.jpg');
  });
}
