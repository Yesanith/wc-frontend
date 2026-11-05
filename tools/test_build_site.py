import json
import os
import posixpath
import re
import unittest
from collections import Counter
from html.parser import HTMLParser

import build_site as site

ENGLISH = site.load("en")


def strings(content):
    """every text of a language paired with the same one in English: (where, english, other)"""
    pairs = []
    def flat(where, english, other):
        if isinstance(english, list):
            for i, (e, o) in enumerate(zip(english, other)):
                flat("%s[%d]" % (where, i), e, o)
        else:
            pairs.append((where, english, other))

    for section in ("ui", "index", "delete"):
        for k in ENGLISH[section]:
            flat("%s.%s" % (section, k), ENGLISH[section][k], content[section][k])
    for k in ("lead", "more", "more_btn"):
        pairs.append(("faq.%s" % k, ENGLISH["faq"][k], content["faq"][k]))
    for (q, a), (q2, a2) in zip(ENGLISH["faq"]["items"], content["faq"]["items"]):
        pairs.append(("faq question", q, q2))
        pairs.append(("faq answer", a, a2))
    for page in ("privacy", "terms"):
        for i, (kind, value) in enumerate(ENGLISH[page]["blocks"]):
            other = content[page]["blocks"][i]
            if kind == "ul":
                for j, item in enumerate(value):
                    pairs.append(("%s[%d][%d]" % (page, i, j), item, other[j]))
            else:
                pairs.append(("%s[%d]" % (page, i), value, other))
    return pairs


def structure(text):
    """the tags of a text and where its links go and which commands it names: what a
    translation must keep exactly as it is"""
    return (
        Counter(re.findall(r"<(?:a|code|strong|em)\b[^>]*>", text)),
        sorted(re.findall(r"<code>(.*?)</code>", text)),
    )


class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.hrefs, self.stack, self.bad, self.lang_links, self.in_lang, self.lang_depth = [], [], [], [], False, 0

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag not in ("meta", "link", "br", "hr", "input", "img", "base"):
            self.stack.append(tag)
        if tag == "div" and a.get("class") == "lang":
            # the picker is in the top of the page, among other things: it ends where the part of the page it began in goes on
            self.in_lang, self.lang_depth = True, len(self.stack)
        if tag == "a" and "href" in a:
            self.hrefs.append(a["href"])
            if self.in_lang:
                self.lang_links.append(a)

    def handle_endtag(self, tag):
        if tag in ("meta", "link", "br", "hr", "input", "img", "base"):
            return
        if not self.stack or self.stack[-1] != tag:
            self.bad.append(tag)
        else:
            self.stack.pop()
        if tag == "div" and self.in_lang and len(self.stack) < self.lang_depth:
            self.in_lang = False


class SiteTest(unittest.TestCase):
    pages = site.build()

    def test_every_language_has_every_page(self):
        self.assertEqual(len(self.pages), len(site.LANGS) * len(site.PAGES))
        for lang in site.LANGS:
            for page in site.PAGES:
                self.assertIn(site.page_file(lang, page), self.pages)

    def test_english_is_at_the_root_and_the_others_in_folders(self):
        self.assertIn("privacy.html", self.pages)
        self.assertIn("de/privacy.html", self.pages)
        self.assertNotIn("en/privacy.html", self.pages)

    def test_a_translation_keeps_the_links_the_commands_and_the_emphasis(self):
        for lang in site.LANGS[1:]:
            for where, english, other in strings(site.load(lang)):
                self.assertEqual(structure(english), structure(other), "%s: %s" % (lang, where))

    def test_a_translation_is_not_the_english_left_in_place(self):
        # a text that was never translated: the same as English, and long enough to be a sentence
        for lang in site.LANGS[1:]:
            same = [w for w, e, o in strings(site.load(lang)) if e == o and len(plain(e)) > 40]
            self.assertEqual(same, [], lang)

    def test_every_page_is_well_formed_and_its_links_lead_somewhere(self):
        for path, text in self.pages.items():
            parser = Links()
            parser.feed(text)
            self.assertEqual(parser.bad, [], path)
            self.assertEqual(parser.stack, [], path)
            for href in parser.hrefs:
                if re.match(r"^(https?:|mailto:|#)", href):
                    continue
                target = posixpath.normpath(posixpath.join(posixpath.dirname(path), href.split("#")[0]))
                if target.startswith("app"):
                    continue  # the app is built when the site is published
                self.assertIn(target, self.pages, "%s links to %s" % (path, href))

    def test_every_page_has_a_picker_with_all_languages_and_marks_its_own(self):
        for path, text in self.pages.items():
            parser = Links()
            parser.feed(text)
            self.assertEqual(len(parser.lang_links), len(site.LANGS), path)
            self.assertEqual(sum(1 for a in parser.lang_links if a.get("aria-current")), 1, path)
            self.assertEqual(sorted(a["hreflang"] for a in parser.lang_links), sorted(site.load(l)["meta"]["html_lang"] for l in site.LANGS))
            # each leads to the same page in its language
            page = os.path.basename(path)
            for a in parser.lang_links:
                self.assertTrue(a["href"].endswith(page), (path, a["href"]))

    def test_every_page_says_what_it_is_for_a_search_engine_and_a_chat_that_shows_a_link(self):
        for path, html in self.pages.items():
            if not path.endswith(".html"):
                continue
            for needle in ('<meta name="description" content="', '<link rel="canonical" href="', 'property="og:title"',
                           'property="og:description"', 'property="og:url"', 'property="og:image"', 'name="twitter:card"',
                           'name="theme-color"', '<link rel="icon"'):
                self.assertIn(needle, html, "%s lacks %s" % (path, needle))
            self.assertIn('og:image" content="https://yesanith.github.io/wc-frontend/og.png"', html, path)
            self.assertIn('twitter:card" content="summary_large_image"', html, path)

    def test_a_page_is_its_own_canonical_address_and_says_it_in_its_language(self):
        privacy = self.pages["tr/privacy.html"]
        self.assertIn('<link rel="canonical" href="https://yesanith.github.io/wc-frontend/tr/privacy.html">', privacy)
        self.assertIn('property="og:url" content="https://yesanith.github.io/wc-frontend/tr/privacy.html"', privacy)
        self.assertIn('property="og:locale" content="tr"', privacy)
        self.assertIn("Android, iPhone ve tarayıcı için", privacy, "the description is in the language of the page")
        self.assertIn('content="https://yesanith.github.io/wc-frontend/privacy.html"', self.pages["privacy.html"])
        # the icon is the app's, found from a folder of a language too
        self.assertIn('<link rel="icon" href="../app/favicon.png">', privacy)
        self.assertIn('<link rel="icon" href="app/favicon.png">', self.pages["privacy.html"])

    def test_the_title_of_a_link_has_the_name_of_the_site_and_is_not_made_of_markup(self):
        for path, html in self.pages.items():
            if not path.endswith(".html"):
                continue
            title = re.search(r'property="og:title" content="([^"]*)"', html).group(1)
            self.assertIn("Wondrous Compass", title, path)
            self.assertNotIn("<", title, path)
            self.assertNotIn("&lt;", title, path)

    def test_what_is_put_in_a_tag_cannot_end_it(self):
        contents = {lang: site.load(lang) for lang in site.LANGS}
        tags = site.social_tags("en", "index", 'A "quoted" <b>title</b>', "", contents)
        self.assertIn('content="A &quot;quoted&quot; title · Wondrous Compass"', tags)
        self.assertNotIn('"quoted"', tags)

    def test_the_page_says_its_language_and_offers_the_others_to_search_engines(self):
        for lang in site.LANGS:
            text = self.pages[site.page_file(lang, "faq")]
            self.assertIn('<html lang="%s">' % site.load(lang)["meta"]["html_lang"], text)
            self.assertEqual(text.count('rel="alternate"'), len(site.LANGS) + 1)
            self.assertIn('hreflang="x-default" href="%sfaq.html"' % site.SITE_URL, text)

    def test_the_translations_say_that_english_applies(self):
        for lang in site.LANGS[1:]:
            note = site.load(lang)["ui"]["note"]
            for page in ("privacy", "terms"):
                self.assertIn(note, self.pages[site.page_file(lang, page)], (lang, page))
        for page in ("privacy", "terms"):
            self.assertNotIn("translation", self.pages[site.page_file("en", page)].split("<h1>")[1].split("<h2")[0].lower())

    def test_nothing_is_left_of_the_templates(self):
        for path, text in self.pages.items():
            self.assertNotIn("{ROOT}", text, path)
            self.assertEqual("__SUPABASE_URL__" in text, path.endswith("delete-account.html"), path)

    def test_the_app_is_linked_from_the_right_place_in_every_language(self):
        self.assertIn("href=\"app/\"", self.pages["index.html"])
        for lang in site.LANGS[1:]:
            self.assertIn("href=\"../app/\"", self.pages["%s/index.html" % lang])
            self.assertIn("href='../app/'", self.pages["%s/faq.html" % lang])

    def test_the_delete_page_returns_from_discord_to_one_page_and_on_to_the_language(self):
        for lang in site.LANGS:
            text = self.pages[site.page_file(lang, "delete-account")]
            self.assertIn("const LANG = '%s';" % lang, text)
            self.assertIn("redirectTo: back", text)
            self.assertIn("new URL('delete-account.html', site)", text)
            self.assertEqual(text.count("localStorage.setItem('tc_lang', LANG)"), 1)
            texts = json.loads(re.search(r"const TEXT = (\{.*?\});", text, re.S).group(1))
            self.assertEqual(sorted(texts), ["deleting", "failed", "fallback_name"])
            self.assertTrue(all(texts.values()), lang)
            # what the player is told is the language they chose
            self.assertEqual(texts["deleting"], site.load(lang)["delete"]["deleting"])

    def test_the_language_names_are_written_in_the_language(self):
        names = {l: site.load(l)["meta"]["name"] for l in site.LANGS}
        self.assertEqual(names, {"en": "English", "de": "Deutsch", "es": "Español", "fr": "Français", "tr": "Türkçe",
                                 "pt": "Português", "ru": "Русский", "ja": "日本語", "zh": "中文"})


def plain(text):
    return re.sub(r"<[^>]+>", "", text)


class FrameTest(unittest.TestCase):
    """what every page has round it, the front page, the questions, the long pages, and what the site has beside its pages"""
    pages = site.build()
    extra = site.extras()
    english = site.load("en")

    def test_every_page_has_a_way_past_the_top_a_main_part_a_top_and_a_bottom(self):
        for path, html in self.pages.items():
            self.assertIn('<a class="skip" href="#main">', html, path)
            self.assertEqual(html.count('<main id="main"'), 1, path)
            self.assertEqual(html.count('<header class="top">'), 1, path)
            self.assertEqual(html.count('<footer class="foot">'), 1, path)
            self.assertEqual(html.count("<h1"), 1, "%s has one main heading" % path)

    def test_the_bottom_of_a_page_has_the_other_pages_the_source_the_contact_and_what_the_site_is_not(self):
        for lang in site.LANGS:
            html = self.pages[site.page_file(lang, "index")]
            foot = html.split('<footer class="foot">')[1]
            for target in ("privacy.html", "terms.html", "delete-account.html", "faq.html", site.REPO, site.ISSUES, site.RELEASES):
                self.assertIn('href="%s"' % target, foot, (lang, target))
            self.assertIn(site.load(lang)["index"]["fan"], foot, lang)

    def test_the_top_has_the_app_in_every_language_and_marks_the_page_of_the_questions(self):
        for lang in site.LANGS:
            root = "" if lang == "en" else "../"
            top = self.pages[site.page_file(lang, "index")].split("</header>")[0]
            self.assertIn('href="%sapp/"' % root, top)
            faq = self.pages[site.page_file(lang, "faq")].split("</header>")[0]
            self.assertEqual(faq.count('aria-current="page"'), 1, lang)
            self.assertEqual(top.count('aria-current="page"'), 0, lang)

    def test_the_front_page_has_its_features_in_every_language_each_with_a_picture_and_a_text(self):
        for lang in site.LANGS:
            html = self.pages[site.page_file(lang, "index")]
            self.assertEqual(html.count('<article class="feature">'), site.FEATURES, lang)
            self.assertEqual(html.count('<div class="ico"><svg'), site.FEATURES, lang)
            self.assertIn('id="features"', html, lang)
            self.assertEqual(html.count('<ul class="chips">'), 1, lang)
            chips = html.split('<ul class="chips">')[1].split("</ul>")[0]
            self.assertEqual(chips.count("<li>"), site.CHIPS, lang)
            for chip in site.load(lang)["index"]["chips"]:
                self.assertIn("<li>%s</li>" % chip, chips, lang)
            for title, text in site.load(lang)["index"]["features"]:
                self.assertIn("<h3>%s</h3><p>%s</p>" % (title, text), html, lang)
        self.assertEqual(len(site.FEATURE_ICONS), site.FEATURES)
        self.assertEqual(set(site.FEATURE_ICONS), set(site.ICONS))

    def test_a_picture_is_drawn_by_what_it_says_and_not_by_the_stylesheet(self):
        for name in site.ICONS:
            svg = site.icon(name)
            for needle in ('stroke="currentColor"', 'fill="none"', 'aria-hidden="true"'):
                self.assertIn(needle, svg, name)

    def test_the_front_page_leads_to_the_question_about_the_bot_and_the_privacy_policy(self):
        question = self.english["faq"]["items"][site.BOT_QUESTION - 1][0]
        self.assertIn("bot", question.lower())
        for lang in site.LANGS:
            html = self.pages[site.page_file(lang, "index")]
            self.assertIn('href="faq.html#q%d"' % site.BOT_QUESTION, html, lang)
            self.assertIn('href="privacy.html"', html, lang)
            self.assertIn('id="q%d"' % site.BOT_QUESTION, self.pages[site.page_file(lang, "faq")], lang)

    def test_the_front_page_says_what_it_is_to_a_search_engine_as_a_program(self):
        for lang in site.LANGS:
            html = self.pages[site.page_file(lang, "index")]
            data = json.loads(re.search(r'<script type="application/ld\+json">(.*?)</script>', html, re.S).group(1))
            self.assertEqual(data["@type"], "SoftwareApplication")
            self.assertEqual(data["name"], "Wondrous Compass")
            self.assertEqual(data["url"], site.SITE_URL + site.page_file(lang, "index"))
            self.assertEqual(data["offers"]["price"], "0")
            self.assertEqual(data["inLanguage"], [site.load(l)["meta"]["html_lang"] for l in site.LANGS])

    def test_the_questions_have_each_an_address_and_are_told_to_a_search_engine(self):
        for lang in site.LANGS:
            html = self.pages[site.page_file(lang, "faq")]
            items = site.load(lang)["faq"]["items"]
            ids = re.findall(r'<details id="(q\d+)">', html)
            self.assertEqual(ids, ["q%d" % i for i in range(1, len(items) + 1)], lang)
            data = json.loads(re.search(r'<script type="application/ld\+json">(.*?)</script>', html, re.S).group(1))
            self.assertEqual(data["@type"], "FAQPage")
            self.assertEqual(len(data["mainEntity"]), len(items), lang)
            self.assertEqual(data["mainEntity"][0]["name"], plain(items[0][0]))
            self.assertNotIn("<", data["mainEntity"][0]["acceptedAnswer"]["text"], "an answer is told as text")
            self.assertIn("Question", data["mainEntity"][0]["@type"])

    def test_a_script_cannot_be_ended_by_what_it_carries(self):
        out = site.json_ld({"a": "</script><b>"})
        self.assertEqual(out.count("</script>"), 1)
        self.assertIn("<\\/script>", out)

    def test_a_long_page_begins_with_where_its_parts_are_and_each_leads_to_its_part(self):
        for lang in site.LANGS:
            for page in ("privacy", "terms"):
                html = self.pages[site.page_file(lang, page)]
                toc = re.search(r'<nav class="toc"[^>]*>(.*?)</nav>', html, re.S).group(1)
                targets = re.findall(r'href="#(s\d+)"', toc)
                self.assertGreaterEqual(len(targets), 3, (lang, page))
                for target in targets:
                    self.assertEqual(html.count('<h2 id="%s">' % target), 1, (lang, page, target))
                self.assertEqual(len(targets), html.count("<h2 id="), "every heading is in it: %s %s" % (lang, page))
                self.assertIn(site.load(lang)["ui"]["toc"], toc)

    def test_a_page_that_is_not_long_has_no_table_of_contents(self):
        for lang in site.LANGS:
            self.assertNotIn('class="toc"', self.pages[site.page_file(lang, "faq")], lang)
            self.assertNotIn('class="toc"', self.pages[site.page_file(lang, "index")], lang)

    def test_the_site_has_a_page_for_an_address_that_is_not_here_and_a_map_of_itself(self):
        self.assertEqual(sorted(self.extra), ["404.html", "sitemap.xml"])
        lost = self.extra["404.html"]
        self.assertIn('<base href="%s">' % site.SITE_URL, lost, "it is shown at any address, so its links are from the base of the site")
        self.assertIn('<meta name="robots" content="noindex">', lost)
        self.assertNotIn('rel="canonical"', lost)
        self.assertNotIn('rel="alternate"', lost)
        self.assertNotIn('class="lang"', lost, "there is no page of it in the other languages")
        parser = Links()
        parser.feed(lost)
        self.assertEqual(parser.bad, [])
        self.assertEqual(parser.stack, [])
        self.assertIn("404", lost)

    def test_the_map_of_the_site_has_every_page_of_every_language_each_with_its_others(self):
        import xml.dom.minidom
        text = self.extra["sitemap.xml"]
        xml.dom.minidom.parseString(text)  # well formed
        locs = re.findall(r"<loc>(.*?)</loc>", text)
        wanted = [site.SITE_URL + site.page_file(l, p) for p in site.PAGES for l in site.LANGS] + [site.SITE_URL + "app/"]
        self.assertEqual(sorted(locs), sorted(wanted))
        self.assertEqual(len(set(locs)), len(locs), "each once")
        # each page offers itself and the others, and the page to show when nothing says which
        first = text.split("<url>")[1]
        self.assertEqual(first.count("hreflang="), len(site.LANGS) + 1)
        self.assertIn('hreflang="x-default"', first)

    def test_the_picture_of_a_link_is_there_and_is_the_size_that_is_said(self):
        path = os.path.join(site.SITE, site.IMAGE)
        self.assertTrue(os.path.exists(path), "run tools/make_site_image.py")
        with open(path, "rb") as f:
            head = f.read(24)
        self.assertEqual(head[:8], b"\x89PNG\r\n\x1a\n")
        width, height = int.from_bytes(head[16:20], "big"), int.from_bytes(head[20:24], "big")
        self.assertEqual((width, height), site.IMAGE_SIZE)
        html = self.pages["index.html"]
        self.assertIn('og:image:width" content="%d"' % width, html)
        self.assertIn('og:image:height" content="%d"' % height, html)

    def test_a_language_that_lacks_what_the_front_page_lists_is_refused(self):
        english = self.english
        for key, broken in (("chips", ["only", "three", "texts"]), ("features", english["index"]["features"][:7]),
                            ("features", [["a heading"]] * site.FEATURES)):
            content = json.loads(json.dumps(site.load("de")))
            content["index"][key] = broken
            problems = site.validate("de", content, english)
            self.assertTrue(any(key in p for p in problems), (key, problems))
        content = json.loads(json.dumps(site.load("de")))
        content["faq"]["lead"] = ""
        self.assertTrue(any("faq.lead" in p for p in site.validate("de", content, english)))
        content = json.loads(json.dumps(site.load("de")))
        del content["ui"]["skip"]
        self.assertTrue(any("ui is missing" in p for p in site.validate("de", content, english)))

    def test_what_the_stylesheet_has_to_do_for_the_pages_it_is_said_by(self):
        with open(os.path.join(site.SITE, "style.css"), encoding="utf-8") as f:
            css = f.read()
        for needle in (".skip", ".top", ".hero", ".feature", ".platform", ".band", ".final", ".toc", ".foot", ".fan", ".lost",
                       "prefers-reduced-motion", "@media print", ":focus-visible", "[hidden]"):
            self.assertIn(needle, css, needle)
        # nothing is loaded from elsewhere
        self.assertNotIn("@import", css)
        self.assertNotIn("url(http", css)


if __name__ == "__main__":
    unittest.main()
