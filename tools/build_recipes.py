#!/usr/bin/env python3
"""Builds legendary crafting trees from the official GW2 API.

Mystic Forge recipes are missing from /v2/recipes, but the in-game item
description of every gift lists its ingredients, for example:

    Made by combining these items in the Mystic Forge:
    * 1 Gift of Metal * 1 Gift of Darkness * 100 Icy Runestones
    * 1 Superior Sigil of Blood

So we pull every item once, parse those descriptions and expand them into a
tree. Output goes to assets/data/legendary_recipes.json and is committed by
the data workflow, the app only reads the generated file.
"""

import json
import os
import re
import sys
import time
import unicodedata
import urllib.error
import urllib.request

API = "https://api.guildwars2.com/v2"
OUT = os.path.join("assets", "data", "legendary_recipes.json")
BATCH = 200
MAX_DEPTH = 6

# these read like ingredients but are not items we can track
SKIP = {"mystic forge", "the mystic forge"}

# descriptions carry markup like <c=@reminder>...</c>
TAGS = re.compile(r"<[^>]*>")


def get(path, params=None):
    url = API + path
    if params:
        url += "?" + "&".join("%s=%s" % kv for kv in params.items())
    for attempt in range(5):
        try:
            with urllib.request.urlopen(url, timeout=60) as r:
                return json.loads(r.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return []
            if e.code in (429, 502, 503):
                time.sleep(5 * (attempt + 1))
                continue
            raise
        except Exception:
            time.sleep(3 * (attempt + 1))
    raise RuntimeError("giving up on " + url)


def fetch_all_items(lang):
    ids = get("/items")
    print("%s: %d items" % (lang, len(ids)), flush=True)
    items = {}
    for i in range(0, len(ids), BATCH):
        chunk = ids[i:i + BATCH]
        for row in get("/items", {"ids": ",".join(str(x) for x in chunk), "lang": lang}):
            items[row["id"]] = row
        if i % (BATCH * 25) == 0:
            print("  %d/%d" % (i, len(ids)), flush=True)
    return items


def strip_accents(text):
    return "".join(c for c in unicodedata.normalize("NFKD", text) if not unicodedata.combining(c))


# words that only glue a sentence together
LEADING = {"de", "du", "des", "la", "le", "les", "un", "une", "of", "the", "a", "an",
           "unites", "unite", "d", "and", "with"}

# descriptions often continue after the item name
CUTS = [" in the mystic forge", " in der mystischen", " dans la forge", " with ", " and ",
        " from ", " to create", " for ", " at ", " dropped ", "\u2014", " \u2013 "]


def clean_name(raw):
    name = TAGS.sub(" ", raw)
    name = re.sub(r"\([^)]*\)", " ", name)
    lowered = name.lower()
    for cut in CUTS:
        idx = lowered.find(cut)
        if idx > 0:
            name = name[:idx]
            lowered = name.lower()
    name = re.sub(r"^\s*\d[\d,]*\s+", "", name)
    words = name.strip(" .,:;\u2022*").split()
    while words and strip_accents(words[0].lower()).strip("'") in LEADING:
        words.pop(0)
    return " ".join(words)


def deplural(name):
    """rough plural stripper, good enough for english and french"""
    return " ".join(w[:-1] if len(w) > 3 and w.endswith("s") else w for w in name.lower().split())


def fuzzy(name):
    """last resort key: no accents, no case, no plural endings.
    turns 'Gaben der Kondensierten Macht' and 'Gabe der kondensierten Macht'
    into the same string"""
    out = []
    for word in strip_accents(name.lower()).replace("'", " ").split():
        while len(word) > 3 and word[-1] in "neris":
            word = word[:-1]
        out.append(word)
    return " ".join(out)


def singular_candidates(name):
    """Item names in descriptions are plural: 'Globs of Ectoplasm'."""
    out = [name]
    if " of " in name:
        head, rest = name.split(" of ", 1)
        if head.endswith("s"):
            out.append(head[:-1] + " of " + rest)
    if name.endswith("s"):
        out.append(name[:-1])
    if name.endswith("es"):
        out.append(name[:-2])
    return out


def index_items(items):
    exact, loose, rough = {}, {}, {}
    for row in items.values():
        name = row["name"]
        exact.setdefault(name.lower(), row["id"])
        loose.setdefault(deplural(name), row["id"])
        key = fuzzy(name)
        if key in rough and rough[key] != row["id"]:
            rough[key] = None  # ambiguous, do not guess
        else:
            rough.setdefault(key, row["id"])
    return exact, loose, rough


def resolve(raw, exact, loose, rough):
    name = clean_name(raw)
    if not name:
        return None, name
    for candidate in singular_candidates(name):
        found = exact.get(candidate.lower())
        if found:
            return found, name
    found = loose.get(deplural(name)) or rough.get(fuzzy(name))
    return found, name


def build_tree(item, items, index, depth, seen, unresolved):
    node = {
        "id": item["id"],
        "name": item["name"],
        "icon": item.get("icon"),
        "rarity": item.get("rarity"),
    }
    if depth >= MAX_DEPTH or item["id"] in seen:
        return node
    children = []
    for qty, raw in parse_ingredients(item.get("description")):
        child_id, name = resolve(raw, *index)
        if not child_id:
            if name:
                unresolved.add(name)
                children.append({"id": None, "name": name, "count": qty})
            continue
        child = build_tree(items[child_id], items, index, depth + 1, seen | {item["id"]}, unresolved)
        child["count"] = qty
        children.append(child)
    if children:
        node["children"] = children
    return node


def collect_ids(node, out):
    if node.get("id"):
        out.add(node["id"])
    for child in node.get("children", []):
        collect_ids(child, out)


def main():
    langs = sys.argv[1:] or ["en"]
    items = fetch_all_items("en")
    index = index_items(items)

    # roots are the things worth showing as a goal: legendary gear and every
    # gift or tribute that has a forge recipe of its own
    roots = []
    for row in items.values():
        if not row.get("description"):
            continue
        if len(parse_ingredients(row["description"])) < 2:
            continue
        legendary = row.get("rarity") == "Legendary"
        if not legendary and row.get("rarity") not in ("Exotic", "Ascended"):
            continue
        roots.append((row, legendary))
    roots.sort(key=lambda r: (not r[1], r[0]["name"]))

    unresolved = set()
    trees = []
    for row, legendary in roots:
        tree = build_tree(row, items, index, 0, set(), unresolved)
        if not tree.get("children"):
            continue
        tree["type"] = row.get("type")
        tree["kind"] = "legendary" if legendary else "gift"
        trees.append(tree)

    print("%d recipes (%d legendary), %d unresolved names"
          % (len(trees), sum(1 for t in trees if t["kind"] == "legendary"), len(unresolved)), flush=True)
    for name in sorted(unresolved):
        print("  unresolved: " + name, flush=True)

    # every id the trees touch, so the other languages only need these
    used = set()
    for tree in trees:
        collect_ids(tree, used)
    used_ids = sorted(used)
    print("%d items used by the trees" % len(used_ids), flush=True)

    names = {}
    for lang in langs:
        if lang == "en":
            continue
        rows = {}
        for i in range(0, len(used_ids), BATCH):
            chunk = used_ids[i:i + BATCH]
            for row in get("/items", {"ids": ",".join(str(x) for x in chunk), "lang": lang}):
                rows[str(row["id"])] = row["name"]
        names[lang] = rows
        print("%s: %d names" % (lang, len(rows)), flush=True)

    result = {
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "roots": trees,
        "names": names,
        "unresolved": sorted(unresolved),
    }

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, separators=(",", ":"))
    print("wrote %s (%d bytes)" % (OUT, os.path.getsize(OUT)))


if __name__ == "__main__":
    main()
