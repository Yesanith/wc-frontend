#!/usr/bin/env python3
"""Builds the pages of the site in every language.

The texts are in site_content/<language>.json. English is the first and has the
structure, the others give the same things in the same order. English pages are at
the root of the site, the others in a folder of their own: de/privacy.html. The app
that runs in the browser (app/) is not made here.

    python3 tools/build_site.py           writes the pages into site/
"""
import json
import os
import re
import sys
from html import escape

HERE = os.path.dirname(os.path.abspath(__file__))
CONTENT = os.path.join(HERE, "site_content")
SITE = os.path.normpath(os.path.join(HERE, "..", "site"))
SITE_URL = "https://yesanith.github.io/wc-frontend/"
# the picture that a chat shows with a link: made by tools/make_site_image.py
IMAGE = "og.png"
IMAGE_SIZE = (1200, 630)
REPO = "https://github.com/Yesanith/wc-frontend"
ISSUES = REPO + "/issues"
RELEASES = REPO + "/releases/latest"
LANGS = ["en", "de", "es", "fr", "tr", "pt", "ru", "ja", "zh"]
PAGES = ["index", "faq", "privacy", "terms", "delete-account"]
SUPABASE_SCRIPT = (
    '<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.117.2/dist/umd/supabase.js"\n'
    '    integrity="sha384-Rj26LVGvoeRVR6+mwQmFfcR3QOBEwT+ZmuCWpuiqeTzJpCs0ER4ITAWGb4Hiy3Ok" crossorigin="anonymous"></script>'
)
UI_KEYS = ["nav_home", "nav_faq", "nav_privacy", "nav_terms", "nav_delete", "nav_contact", "language", "note", "nav_features", "nav_app",
           "skip", "footer_product", "footer_legal", "footer_project", "nav_source", "nav_releases", "toc"]
INDEX_KEYS = ["tagline", "intro", "download", "browser_h", "browser_p", "open_button", "iphone", "limits", "fan", "eyebrow", "hero_h",
              "features_h", "features_p", "platforms_h", "android_h", "android_p", "discord_h", "discord_p", "discord_link",
              "privacy_h", "privacy_p", "privacy_link", "cta_h", "cta_p"]
FAQ_KEYS = ["title", "lead", "more", "more_btn"]
# what the front page lists: the chips under the buttons, and a card of the features, each with a heading and a text
CHIPS = 4
FEATURES = 8
FEATURE_ICONS = ["day", "user", "trend", "flask", "map", "trophy", "users", "search"]
# the question of the FAQ that tells how to add the bot, which the front page leads to (counting from 1)
BOT_QUESTION = 10
DELETE_KEYS = ["title", "intro", "signin_p", "signin_btn", "signed_prefix", "signed_suffix", "sure", "delete_btn",
               "signout_btn", "done", "app_note", "deleting", "failed", "fallback_name"]


def load(lang):
    with open(os.path.join(CONTENT, lang + ".json"), encoding="utf-8") as f:
        return json.load(f)


def blocks(content, english, page):
    """the blocks of a page with their types, which only English gives"""
    kinds = [b[0] for b in english[page]["blocks"]]
    if content is english:
        return [(b[0], b[1]) for b in english[page]["blocks"]]
    given = content[page]["blocks"]
    return list(zip(kinds, given))


def validate(lang, content, english):
    """the same pages with the same parts, so no language shows less than another"""
    problems = []
    if content["meta"].keys() != {"name", "html_lang"}:
        problems.append("meta")
    for section, keys in (("ui", UI_KEYS), ("index", INDEX_KEYS), ("delete", DELETE_KEYS)):
        missing = [k for k in keys if not isinstance(content[section].get(k), str)]
        if missing:
            problems.append("%s is missing %s" % (section, missing))
        for k in keys:
            if lang != "en" and k not in ("note", "signed_suffix") and not content[section].get(k):
                problems.append("%s.%s is empty" % (section, k))
    if lang != "en" and not content["ui"]["note"]:
        problems.append("ui.note (the note that English applies) is empty")
    chips = content["index"].get("chips")
    if not isinstance(chips, list) or len(chips) != CHIPS or not all(isinstance(c, str) and c.strip() for c in chips):
        problems.append("index.chips should be %d texts" % CHIPS)
    features = content["index"].get("features")
    if (not isinstance(features, list) or len(features) != FEATURES
            or not all(isinstance(f, list) and len(f) == 2 and all(isinstance(t, str) and t.strip() for t in f) for f in features)):
        problems.append("index.features should be %d pairs of a heading and a text" % FEATURES)
    for k in FAQ_KEYS:
        if not isinstance(content["faq"].get(k), str) or not content["faq"][k].strip():
            problems.append("faq.%s is empty" % k)
    for page in ("privacy", "terms"):
        given, want = content[page]["blocks"], english[page]["blocks"]
        if len(given) != len(want):
            problems.append("%s has %d blocks, English has %d" % (page, len(given), len(want)))
            continue
        for i, (g, w) in enumerate(zip(given, want)):
            wanted = w[1] if lang == "en" else w[1]
            g = g[1] if lang == "en" else g
            if w[0] == "ul":
                if not isinstance(g, list) or len(g) != len(wanted):
                    problems.append("%s block %d should be a list of %d" % (page, i, len(wanted)))
            elif not isinstance(g, str) or not g.strip():
                problems.append("%s block %d should be a text" % (page, i))
        for k in ("title", "updated"):
            if not content[page].get(k):
                problems.append("%s.%s is empty" % (page, k))
    if len(content["faq"]["items"]) != len(english["faq"]["items"]):
        problems.append("faq has %d questions, English has %d" % (len(content["faq"]["items"]), len(english["faq"]["items"])))
    return problems


def plain(text):
    return re.sub(r"<[^>]+>", "", text)


def page_file(lang, page):
    return "%s.html" % page if lang == "en" else "%s/%s.html" % (lang, page)


def link(from_lang, to_lang, page):
    """the address of a page in one language, seen from a page in another"""
    up = "" if from_lang == "en" else "../"
    return up + page_file(to_lang, page)


def picker(lang, page, contents):
    items = []
    for other in LANGS:
        current = ' aria-current="true"' if other == lang else ""
        name = contents[other]["meta"]["name"]
        items.append('<li><a href="%s" hreflang="%s" lang="%s"%s>%s</a></li>' % (
            link(lang, other, page), contents[other]["meta"]["html_lang"], contents[other]["meta"]["html_lang"], current, name))
    label = contents[lang]["ui"]["language"]
    return ('<div class="lang"><details><summary aria-label="%s">🌐 %s</summary><ul>%s</ul></details></div>'
            % (label, contents[lang]["meta"]["name"], "".join(items)))


# ---------------------------------------------------------------- the frame of every page

ICONS = {
    "day": '<rect x="3.5" y="5" width="17" height="15.5" rx="2.5"/><path d="M3.5 10h17M8 3v4M16 3v4M9 15l2 2 4-4"/>',
    "user": '<circle cx="12" cy="8" r="3.5"/><path d="M5 20c0-3.9 3.1-6.5 7-6.5s7 2.6 7 6.5"/>',
    "trend": '<path d="M3.5 17l5.5-5.5 4 4 7-8"/><path d="M15.5 7.5h5v5"/>',
    "flask": '<path d="M9 3.5h6M10 3.5v5.2L5 18a2 2 0 0 0 1.8 3h10.4a2 2 0 0 0 1.8-3l-5-9.3V3.5"/><path d="M7.5 15h9"/>',
    "map": '<path d="M9 4.5L3.5 6.5v13L9 17.5l6 2 5.5-2v-13l-5.5 2-6-2z"/><path d="M9 4.5v13M15 6.5v13"/>',
    "trophy": '<path d="M8 4h8v5a4 4 0 0 1-8 0V4z"/><path d="M8 6H4.5v1.5A3.5 3.5 0 0 0 8 11M16 6h3.5v1.5A3.5 3.5 0 0 1 16 11M12 13v4M8.5 20.5h7"/>',
    "users": '<circle cx="9" cy="8.5" r="3"/><path d="M3.5 19.5c0-3.2 2.4-5.2 5.5-5.2s5.5 2 5.5 5.2"/><circle cx="17" cy="9.5" r="2.4"/><path d="M16.5 14.5c2.6 0 4.5 1.7 4.5 4.5"/>',
    "search": '<circle cx="11" cy="11" r="6.5"/><path d="M20.5 20.5L16 16"/>',
}

# the mark of the app: a diamond in a diamond in a diamond, as its icon has it
BRAND = ('<svg viewBox="0 0 32 32" aria-hidden="true" focusable="false">'
         '<path d="M16 2.5L29.5 16 16 29.5 2.5 16z" fill="none" stroke="#dfc295" stroke-width="2" stroke-linejoin="round"/>'
         '<path d="M16 8L24 16 16 24 8 16z" fill="none" stroke="#dfc295" stroke-width="2" stroke-linejoin="round"/>'
         '<path d="M16 13.2L18.8 16 16 18.8 13.2 16z" fill="#dfc295"/></svg>')


def icon(name):
    # the line is in the picture and not only in the stylesheet, so that it is drawn whatever reads the page
    return ('<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" '
            'aria-hidden="true" focusable="false">%s</svg>' % ICONS[name])


def root_of(lang):
    return "" if lang == "en" else "../"


def header(lang, page, contents):
    ui, root = contents[lang]["ui"], root_of(lang)
    current = ' aria-current="page"' if page == "faq" else ""
    return ('<header class="top"><div class="top-in">\n'
            '  <a class="brand" href="index.html">%s<span>Wondrous Compass</span></a>\n'
            '  <nav aria-label="Wondrous Compass"><a href="index.html#features">%s</a><a href="faq.html"%s>%s</a></nav>\n'
            '  <div class="top-end">%s<a class="button small" href="%sapp/">%s</a></div>\n'
            '</div></header>') % (BRAND, ui["nav_features"], current, ui["nav_faq"],
                                  picker(lang, page, contents) if page else "", root, ui["nav_app"])


def footer(lang, contents):
    ui, c, root = contents[lang]["ui"], contents[lang]["index"], root_of(lang)
    return ('<footer class="foot">\n'
            '  <div class="foot-in">\n'
            '    <div class="foot-brand"><a class="brand" href="index.html"><span>Wondrous Compass</span></a><p>%s</p></div>\n'
            '    <div><h2>%s</h2><ul><li><a href="%sapp/">%s</a></li><li><a href="%s">%s</a></li><li><a href="index.html#features">%s</a></li>'
            '<li><a href="faq.html">%s</a></li></ul></div>\n'
            '    <div><h2>%s</h2><ul><li><a href="privacy.html">%s</a></li><li><a href="terms.html">%s</a></li>'
            '<li><a href="delete-account.html">%s</a></li></ul></div>\n'
            '    <div><h2>%s</h2><ul><li><a href="%s">%s</a></li><li><a href="%s">%s</a></li></ul></div>\n'
            '  </div>\n'
            '  <div class="fan"><p>%s</p></div>\n'
            '</footer>') % (c["tagline"],
                            ui["footer_product"], root, ui["nav_app"], RELEASES, ui["nav_releases"], ui["nav_features"], ui["nav_faq"],
                            ui["footer_legal"], ui["nav_privacy"], ui["nav_terms"], ui["nav_delete"],
                            ui["footer_project"], REPO, ui["nav_source"], ISSUES, ui["nav_contact"],
                            c["fan"])


def social_tags(lang, page, title, root, contents):
    """what a search engine and a chat that shows a link need to know of a page: what it says, where it is, what to call it and the
    picture to show, in the language of the page"""
    url = SITE_URL + page_file(lang, page)
    name = plain(title)
    headline = name if "Wondrous Compass" in name else "%s · Wondrous Compass" % name
    description = plain(contents[lang]["index"]["tagline"])
    image = SITE_URL + IMAGE
    tags = [
        '<meta name="description" content="%s">' % escape(description),
        '<link rel="canonical" href="%s">' % url,
        '<meta name="theme-color" content="#F4ECDA" media="(prefers-color-scheme: light)">',
        '<meta name="theme-color" content="#14100B" media="(prefers-color-scheme: dark)">',
        '<link rel="icon" href="%sapp/favicon.png">' % root,
        '<link rel="apple-touch-icon" href="%sapp/icons/Icon-192.png">' % root,
        '<meta property="og:type" content="website">',
        '<meta property="og:site_name" content="Wondrous Compass">',
        '<meta property="og:title" content="%s">' % escape(headline),
        '<meta property="og:description" content="%s">' % escape(description),
        '<meta property="og:url" content="%s">' % url,
        '<meta property="og:image" content="%s">' % image,
        '<meta property="og:image:width" content="%d">' % IMAGE_SIZE[0],
        '<meta property="og:image:height" content="%d">' % IMAGE_SIZE[1],
        '<meta property="og:image:alt" content="Wondrous Compass">',
        '<meta property="og:locale" content="%s">' % contents[lang]["meta"]["html_lang"].replace("-", "_"),
        '<meta name="twitter:card" content="summary_large_image">',
        '<meta name="twitter:image" content="%s">' % image,
    ]
    return "".join("\n  " + t for t in tags)


def json_ld(data):
    """structured data for a search engine, in a script that its own text cannot end"""
    return '\n  <script type="application/ld+json">%s</script>' % json.dumps(data, ensure_ascii=False).replace("</", "<\\/")


def shell(lang, page, title, body, contents, extra_head="", extra_end="", main_class="", indexable=True):
    root = root_of(lang)
    ui = contents[lang]["ui"]
    if indexable:
        alternates = "".join(
            '\n  <link rel="alternate" hreflang="%s" href="%s%s">' % (contents[o]["meta"]["html_lang"], SITE_URL, page_file(o, page))
            for o in LANGS)
        alternates += '\n  <link rel="alternate" hreflang="x-default" href="%s%s">' % (SITE_URL, page_file("en", page))
        social = social_tags(lang, page, title, root, contents)
    else:
        # a page that is not found has no address of its own, and is found from wherever it was asked for
        alternates = ('\n  <base href="%s">\n  <meta name="robots" content="noindex">\n  <link rel="icon" href="app/favicon.png">'
                      % SITE_URL)
        social = ""
    text = """<!doctype html>
<html lang="%s">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="light dark">
  <title>%s</title>
  <link rel="stylesheet" href="%sstyle.css">%s%s%s
</head>
<body>
<a class="skip" href="#main">%s</a>
%s
<main id="main"%s>
%s
</main>
%s
<script>document.addEventListener('click', (e) => { document.querySelectorAll('.lang details[open]').forEach((d) => { if (!d.contains(e.target)) d.open = false; }); });</script>%s
</body>
</html>
""" % (contents[lang]["meta"]["html_lang"], plain(title), root, alternates, social, extra_head, ui["skip"],
       header(lang, page if indexable else None, contents), (' class="%s"' % main_class) if main_class else "", body,
       footer(lang, contents), extra_end)
    return text.replace("{ROOT}", root)


# ---------------------------------------------------------------- the pages

def feature_cards(c):
    return "\n".join(
        '      <article class="feature"><div class="ico">%s</div><h3>%s</h3><p>%s</p></article>' % (icon(name), title, text)
        for name, (title, text) in zip(FEATURE_ICONS, c["features"]))


def software_ld(lang, contents):
    c = contents[lang]["index"]
    return json_ld({
        "@context": "https://schema.org",
        "@type": "SoftwareApplication",
        "name": "Wondrous Compass",
        "description": plain(c["tagline"]),
        "url": SITE_URL + page_file(lang, "index"),
        "image": SITE_URL + IMAGE,
        "applicationCategory": "UtilitiesApplication",
        "operatingSystem": "Android, Web",
        "isAccessibleForFree": True,
        "offers": {"@type": "Offer", "price": "0", "priceCurrency": "USD"},
        "downloadUrl": RELEASES,
        "codeRepository": REPO,
        "inLanguage": [contents[o]["meta"]["html_lang"] for o in LANGS],
    })


def render_index(lang, contents):
    c = contents[lang]["index"]
    chips = "".join("<li>%s</li>" % t for t in c["chips"])
    body = """<section class="hero"><div class="hero-in">
  <p class="eyebrow">%(eyebrow)s</p>
  <h1>%(hero_h)s</h1>
  <p class="lead">%(intro)s</p>
  <div class="cta"><a class="button" href="{ROOT}app/">%(open_button)s</a><a class="button ghost" href="%(releases)s">%(download)s</a></div>
  <ul class="chips">%(chips)s</ul>
</div></section>

<section class="section" id="features" aria-labelledby="features-h">
  <h2 id="features-h">%(features_h)s</h2>
  <p class="sub">%(features_p)s</p>
  <div class="grid">
%(cards)s
  </div>
</section>

<section class="section" aria-labelledby="platforms-h">
  <h2 id="platforms-h">%(platforms_h)s</h2>
  <div class="platforms">
    <article class="platform"><h3>%(android_h)s</h3><p>%(android_p)s</p><a class="button" href="%(releases)s">%(download)s</a></article>
    <article class="platform"><h3>%(browser_h)s</h3><p>%(browser_p)s</p><a class="button" href="{ROOT}app/">%(open_button)s</a></article>
  </div>
  <div class="notes"><p class="muted">%(iphone)s</p><p class="muted">%(limits)s</p></div>
</section>

<section class="section">
  <div class="bands">
    <article class="band discord-band"><h2>%(discord_h)s</h2><p>%(discord_p)s</p><a class="more" href="faq.html#q%(bot)d">%(discord_link)s →</a></article>
    <article class="band privacy-band"><h2>%(privacy_h)s</h2><p>%(privacy_p)s</p><a class="more" href="privacy.html">%(privacy_link)s →</a></article>
  </div>
</section>

<section class="final" aria-labelledby="cta-h"><div class="final-in">
  <h2 id="cta-h">%(cta_h)s</h2>
  <p>%(cta_p)s</p>
  <div class="cta"><a class="button" href="{ROOT}app/">%(open_button)s</a></div>
</div></section>""" % dict(c, chips=chips, cards=feature_cards(c), releases=RELEASES, bot=BOT_QUESTION)
    return shell(lang, "index", "Wondrous Compass", body, contents, extra_head=software_ld(lang, contents))


def render_faq(lang, contents):
    c = contents[lang]["faq"]
    items = "\n".join('  <details id="q%d"><summary>%s</summary><p>%s</p></details>' % (i, q, a)
                      for i, (q, a) in enumerate(c["items"], 1))
    body = ('  <h1>%s</h1>\n  <p class="lead">%s</p>\n%s\n  <div class="more-help"><p>%s</p>'
            '<a class="button ghost" href="%s">%s</a></div>') % (c["title"], c["lead"], items, c["more"], ISSUES, c["more_btn"])
    questions = json_ld({
        "@context": "https://schema.org",
        "@type": "FAQPage",
        "mainEntity": [{"@type": "Question", "name": plain(q),
                        "acceptedAnswer": {"@type": "Answer", "text": plain(a)}} for q, a in c["items"]],
    })
    return shell(lang, "faq", "%s · Wondrous Compass" % c["title"], body, contents, extra_head=questions, main_class="page")


def render_document(lang, page, contents, english):
    c = contents[lang][page]
    given = blocks(contents[lang], english, page)
    headings = [(i, plain(v)) for i, (kind, v) in enumerate(given) if kind == "h2"]
    out = ["  <h1>%s</h1>" % c["title"], '  <p class="muted">%s</p>' % c["updated"]]
    if lang != "en":
        out.append('  <p class="muted">%s</p>' % contents[lang]["ui"]["note"])
    # a long page begins with where its parts are
    if len(headings) >= 3:
        out.append('  <nav class="toc" aria-label="%s"><p>%s</p><ol>%s</ol></nav>' % (
            plain(contents[lang]["ui"]["toc"]), contents[lang]["ui"]["toc"],
            "".join('<li><a href="#s%d">%s</a></li>' % (n, t) for n, (_, t) in enumerate(headings, 1))))
    heading = 0
    for kind, value in given:
        if kind == "ul":
            out.append("  <ul>\n" + "\n".join("    <li>%s</li>" % li for li in value) + "\n  </ul>")
        elif kind == "h2":
            heading += 1
            out.append('  <h2 id="s%d">%s</h2>' % (heading, value))
        else:
            out.append("  <%s>%s</%s>" % (kind, value, kind))
    return shell(lang, page, "%s · Wondrous Compass" % c["title"], "\n".join(out), contents, main_class="page")


def render_delete(lang, contents):
    c = contents[lang]["delete"]
    root_url = "./" if lang == "en" else "../"
    text = {k: c[k] for k in ("deleting", "failed", "fallback_name")}
    script = """
<script>
(async () => {
  const TEXT = %s;
  const LANG = '%s';
  const LANGS = %s;
  // the site's root, from this page
  const site = new URL('%s', location.href);
  // discord sends the player back to one page whichever language they were reading, the English one,
  // and that page carries them on to the language they chose before signing in
  let stored = null;
  try { stored = localStorage.getItem('tc_lang'); } catch (_) {}
  const returning = location.search.includes('code=') || location.hash.includes('access_token');
  if (LANG === 'en' && returning && stored && stored !== 'en' && LANGS.includes(stored)) {
    location.replace(new URL(stored + '/delete-account.html', site).href + location.search + location.hash);
    return;
  }

  // filled in from the repository secrets when the site is published. both
  // are public by design, the database only lets a player delete themselves
  const client = supabase.createClient('__SUPABASE_URL__', '__SUPABASE_PUBLISHABLE_KEY__');
  const back = new URL('delete-account.html', site).href;
  const show = (id) => ['signed-out', 'signed-in', 'done'].forEach((s) => document.getElementById(s).hidden = s !== id);
  const status = (text) => document.getElementById('status').textContent = text;

  async function refresh() {
    const { data: { session } } = await client.auth.getSession();
    if (!session) return show('signed-out');
    const { data } = await client.from('profiles').select('display_name').eq('id', session.user.id).maybeSingle();
    document.getElementById('who').textContent = data?.display_name ?? session.user.email ?? TEXT.fallback_name;
    show('signed-in');
  }

  document.getElementById('sign-in').onclick = () => {
    try { localStorage.setItem('tc_lang', LANG); } catch (_) {}
    client.auth.signInWithOAuth({ provider: 'discord', options: { redirectTo: back } });
  };
  document.getElementById('sign-out').onclick = async () => { await client.auth.signOut(); refresh(); };
  document.getElementById('sure').onchange = (e) => document.getElementById('delete').disabled = !e.target.checked;
  document.getElementById('delete').onclick = async () => {
    const button = document.getElementById('delete');
    button.disabled = true;
    status(TEXT.deleting);
    const { error } = await client.rpc('delete_account');
    if (error) {
      status(TEXT.failed);
      button.disabled = false;
      return;
    }
    // the account is gone, the local session goes too
    await client.auth.signOut().catch(() => {});
    status('');
    show('done');
  };

  // coming back from discord, the session arrives in the address
  client.auth.onAuthStateChange(() => refresh());
  refresh();
})();
</script>""" % (json.dumps(text, ensure_ascii=False).replace("</", "<\\/"), lang, json.dumps(LANGS), root_url)
    body = """  <h1>%(title)s</h1>
  <p>%(intro)s</p>

  <div class="card" id="signed-out" hidden>
    <p>%(signin_p)s</p>
    <button class="discord" id="sign-in">%(signin_btn)s</button>
  </div>

  <div class="card" id="signed-in" hidden>
    <p>%(signed_prefix)s<strong id="who">…</strong>%(signed_suffix)s</p>
    <label><input type="checkbox" id="sure"> %(sure)s</label>
    <button class="danger" id="delete" disabled>%(delete_btn)s</button>
    <button class="plain" id="sign-out">%(signout_btn)s</button>
  </div>

  <div class="card" id="done" hidden>
    <p>%(done)s</p>
  </div>

  <p class="muted" id="status"></p>
  <p class="muted">%(app_note)s</p>""" % c
    return shell(lang, "delete-account", "%s · Wondrous Compass" % c["title"], body, contents,
                 extra_head="\n  " + SUPABASE_SCRIPT, extra_end=script, main_class="page")


def render_404(contents):
    """the page that GitHub Pages shows for an address that is not here: in English, with the ways to go on. it is shown at any
    address, so its links are made from the base of the site, which is said in its head"""
    ui = contents["en"]["ui"]
    body = ('  <div class="lost"><h1>404</h1><p>Page not found.</p>'
            '<div class="cta"><a class="button" href="index.html">%s</a><a class="button ghost" href="app/">%s</a></div></div>'
            % ("Wondrous Compass", ui["nav_app"]))
    return shell("en", "404", "Page not found · Wondrous Compass", body, contents, indexable=False)


def sitemap(contents):
    """every page in every language, each with the same page in the others, which is what a search engine looks for"""
    urls = []
    for page in PAGES:
        for lang in LANGS:
            alternates = "".join(
                '\n    <xhtml:link rel="alternate" hreflang="%s" href="%s%s"/>' % (contents[o]["meta"]["html_lang"], SITE_URL, page_file(o, page))
                for o in LANGS)
            alternates += '\n    <xhtml:link rel="alternate" hreflang="x-default" href="%s%s"/>' % (SITE_URL, page_file("en", page))
            urls.append("  <url>\n    <loc>%s%s</loc>%s\n  </url>" % (SITE_URL, page_file(lang, page), alternates))
    urls.append("  <url>\n    <loc>%sapp/</loc>\n  </url>" % SITE_URL)
    return ('<?xml version="1.0" encoding="UTF-8"?>\n'
            '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">\n%s\n</urlset>\n'
            % "\n".join(urls))


def extras():
    """what the site has beside its pages: the page for an address that is not here, and the map of the site"""
    contents = {lang: load(lang) for lang in LANGS}
    return {"404.html": render_404(contents), "sitemap.xml": sitemap(contents)}


def build():
    """every page of the site: {path relative to site/: text}"""
    contents = {lang: load(lang) for lang in LANGS}
    english = contents["en"]
    for lang in LANGS:
        problems = validate(lang, contents[lang], english)
        if problems:
            raise ValueError("%s: %s" % (lang, "; ".join(problems)))
    out = {}
    for lang in LANGS:
        out[page_file(lang, "index")] = render_index(lang, contents)
        out[page_file(lang, "faq")] = render_faq(lang, contents)
        out[page_file(lang, "privacy")] = render_document(lang, "privacy", contents, english)
        out[page_file(lang, "terms")] = render_document(lang, "terms", contents, english)
        out[page_file(lang, "delete-account")] = render_delete(lang, contents)
    return out


def main():
    pages = {**build(), **extras()}
    for path, text in pages.items():
        target = os.path.join(SITE, path)
        os.makedirs(os.path.dirname(target), exist_ok=True)
        with open(target, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
    print("%d files, the pages of %d languages among them" % (len(pages), len(LANGS)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
