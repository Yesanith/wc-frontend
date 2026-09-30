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
    for section in ("ui", "index", "delete"):
        for k in ENGLISH[section]:
            pairs.append(("%s.%s" % (section, k), ENGLISH[section][k], content[section][k]))
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
        self.hrefs, self.stack, self.bad, self.lang_links, self.in_lang = [], [], [], [], False

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == "div" and a.get("class") == "lang":
            self.in_lang = True
        if tag not in ("meta", "link", "br", "hr", "input", "img"):
            self.stack.append(tag)
        if tag == "a" and "href" in a:
            self.hrefs.append(a["href"])
            if self.in_lang:
                self.lang_links.append(a)

    def handle_endtag(self, tag):
        if tag in ("meta", "link", "br", "hr", "input", "img"):
            return
        if not self.stack or self.stack[-1] != tag:
            self.bad.append(tag)
        else:
            self.stack.pop()
        if tag == "div" and self.in_lang and "div" not in self.stack:
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
            self.assertNotIn("translation", self.pages[site.page_file("en", page)].split("<h1>")[1].split("<h2>")[0].lower())

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


if __name__ == "__main__":
    unittest.main()
