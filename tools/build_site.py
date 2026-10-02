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
SITE_URL = "https://yesanith.github.io/tyria-companion/"
ISSUES = "https://github.com/Yesanith/tyria-companion/issues"
LANGS = ["en", "de", "es", "fr", "tr", "pt", "ru", "ja", "zh"]
PAGES = ["index", "faq", "privacy", "terms", "delete-account"]
SUPABASE_SCRIPT = (
    '<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.117.2/dist/umd/supabase.js"\n'
    '    integrity="sha384-Rj26LVGvoeRVR6+mwQmFfcR3QOBEwT+ZmuCWpuiqeTzJpCs0ER4ITAWGb4Hiy3Ok" crossorigin="anonymous"></script>'
)
UI_KEYS = ["nav_home", "nav_faq", "nav_privacy", "nav_terms", "nav_delete", "nav_contact", "language", "note"]
INDEX_KEYS = ["tagline", "intro", "download", "browser_h", "browser_p", "open_button", "iphone", "limits", "fan"]
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
    if not content["faq"].get("title"):
        problems.append("faq.title is empty")
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


def nav(lang, ui):
    return ('<nav><a href="index.html">%s</a><a href="faq.html">%s</a><a href="privacy.html">%s</a>'
            '<a href="terms.html">%s</a><a href="delete-account.html">%s</a><a href="%s">%s</a></nav>'
            % (ui["nav_home"], ui["nav_faq"], ui["nav_privacy"], ui["nav_terms"], ui["nav_delete"], ISSUES, ui["nav_contact"]))


def social_tags(lang, page, title, root, contents):
    """what a search engine and a chat that shows a link need to know of a page: what it says, where it is, what to call it and the
    picture to show, in the language of the page"""
    url = SITE_URL + page_file(lang, page)
    name = plain(title)
    headline = name if "Tyria Codex" in name else "%s · Tyria Codex" % name
    description = plain(contents[lang]["index"]["tagline"])
    image = SITE_URL + "app/icons/Icon-512.png"
    tags = [
        '<meta name="description" content="%s">' % escape(description),
        '<link rel="canonical" href="%s">' % url,
        '<meta name="theme-color" content="#0D0B09">',
        '<link rel="icon" href="%sapp/favicon.png">' % root,
        '<meta property="og:type" content="website">',
        '<meta property="og:site_name" content="Tyria Codex">',
        '<meta property="og:title" content="%s">' % escape(headline),
        '<meta property="og:description" content="%s">' % escape(description),
        '<meta property="og:url" content="%s">' % url,
        '<meta property="og:image" content="%s">' % image,
        '<meta property="og:locale" content="%s">' % contents[lang]["meta"]["html_lang"].replace("-", "_"),
        '<meta name="twitter:card" content="summary">',
    ]
    return "".join("\n  " + t for t in tags)


def shell(lang, page, title, body, contents, extra_head="", extra_end=""):
    root = "" if lang == "en" else "../"
    alternates = "".join(
        '\n  <link rel="alternate" hreflang="%s" href="%s%s">' % (contents[o]["meta"]["html_lang"], SITE_URL, page_file(o, page))
        for o in LANGS)
    alternates += '\n  <link rel="alternate" hreflang="x-default" href="%s%s">' % (SITE_URL, page_file("en", page))
    ui = contents[lang]["ui"]
    text = """<!doctype html>
<html lang="%s">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>%s</title>
  <link rel="stylesheet" href="%sstyle.css">%s%s%s
</head>
<body>
%s
<main>
  %s
%s
</main>
<script>document.addEventListener('click', (e) => { document.querySelectorAll('.lang details[open]').forEach((d) => { if (!d.contains(e.target)) d.open = false; }); });</script>%s
</body>
</html>
""" % (contents[lang]["meta"]["html_lang"], plain(title), root, alternates, social_tags(lang, page, title, root, contents), extra_head,
       picker(lang, page, contents), nav(lang, ui), body, extra_end)
    return text.replace("{ROOT}", root)


def render_index(lang, contents):
    c, ui = contents[lang]["index"], contents[lang]["ui"]
    body = """  <h1>Tyria Codex</h1>
  <p class="muted">%(tagline)s</p>
  <div class="card">
    <p>%(intro)s</p>
    <p><a href="https://github.com/Yesanith/tyria-companion/releases/latest">%(download)s</a></p>
  </div>
  <div class="card">
    <h2>%(browser_h)s</h2>
    <p>%(browser_p)s</p>
    <p><a class="button" href="{ROOT}app/">%(open_button)s</a></p>
    <p class="muted">%(iphone)s</p>
    <p class="muted">%(limits)s</p>
  </div>
  <p class="muted">%(fan)s</p>""" % c
    return shell(lang, "index", "Tyria Codex", body, contents)


def render_faq(lang, contents):
    c = contents[lang]["faq"]
    items = "\n".join("  <details><summary>%s</summary><p>%s</p></details>" % (q, a) for q, a in c["items"])
    return shell(lang, "faq", "%s · Tyria Codex" % c["title"], "  <h1>%s</h1>\n%s" % (c["title"], items), contents)


def render_document(lang, page, contents, english):
    c = contents[lang][page]
    out = ["  <h1>%s</h1>" % c["title"], '  <p class="muted">%s</p>' % c["updated"]]
    if lang != "en":
        out.append('  <p class="muted">%s</p>' % contents[lang]["ui"]["note"])
    for kind, value in blocks(contents[lang], english, page):
        if kind == "ul":
            out.append("  <ul>\n" + "\n".join("    <li>%s</li>" % li for li in value) + "\n  </ul>")
        else:
            out.append("  <%s>%s</%s>" % (kind, value, kind))
    return shell(lang, page, "%s · Tyria Codex" % c["title"], "\n".join(out), contents)


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
    return shell(lang, "delete-account", "%s · Tyria Codex" % c["title"], body, contents,
                 extra_head="\n  " + SUPABASE_SCRIPT, extra_end=script)


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
    pages = build()
    for path, text in pages.items():
        target = os.path.join(SITE, path)
        os.makedirs(os.path.dirname(target), exist_ok=True)
        with open(target, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
    print("%d pages in %d languages" % (len(pages), len(LANGS)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
