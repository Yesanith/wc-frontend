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


def deplural(name):
    """rough plural stripper, good enough for english and french"""
    return " ".join(w[:-1] if len(w) > 3 and w.endswith("s") else w for w in name.lower().split())


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


# "* 250 Globs of Ectoplasm" or "* 1 Gift of Might"
BULLET = re.compile(r"[\u2022\*]\s*(\d[\d,]*)\s+([^\u2022\*\n]+)")
# "combine 9 Mystic Clovers, a Gift of Research, and a Gift of Craftmanship to create"
COMBINE = re.compile(r"combine (.+?) to create", re.IGNORECASE | re.DOTALL)
PIECE = re.compile(r"(?:(\d[\d,]*)|an?)\s+(.+)")


def parse_ingredients(description):
    if not description:
        return []
    text = TAGS.sub(" ", description).replace("\n", " ")
    out = []
    # bullet lists look the same in every language, so no keyword check here
    for qty, name in BULLET.findall(text):
        out.append((int(qty.replace(",", "")), name.strip(" .,")))
    if not out:
        m = COMBINE.search(text)
        if m:
            body = m.group(1).replace(" and ", ", ")
            for piece in body.split(","):
                piece = piece.strip(" .")
                if not piece:
                    continue
                pm = PIECE.match(piece)
                if not pm:
                    continue
                qty = pm.group(1)
                out.append((int(qty.replace(",", "")) if qty else 1, pm.group(2).strip(" .")))
    return [(q, n) for q, n in out if n.lower() not in SKIP]


def build_tree(item, items, by_name, loose, depth, seen, unresolved):
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
        child_id = None
        for candidate in singular_candidates(raw):
            child_id = by_name.get(candidate.lower())
            if child_id:
                break
        if not child_id:
            child_id = loose.get(deplural(raw))
        if not child_id:
            unresolved.add(raw)
            children.append({"id": None, "name": raw, "count": qty})
            continue
        child = build_tree(items[child_id], items, by_name, loose, depth + 1, seen | {item["id"]}, unresolved)
        child["count"] = qty
        children.append(child)
    if children:
        node["children"] = children
    return node


def main():
    langs = sys.argv[1:] or ["en"]
    result = {"generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "languages": {}}

    for lang in langs:
        items = fetch_all_items(lang)
        by_name = {}
        loose = {}
        for row in items.values():
            by_name.setdefault(row["name"].lower(), row["id"])
            loose.setdefault(deplural(row["name"]), row["id"])

        # roots are the things worth showing as a goal: legendary gear and
        # every gift/tribute that has a forge recipe of its own
        roots = []
        for row in items.values():
            if not row.get("description"):
                continue
            ingredients = parse_ingredients(row["description"])
            if len(ingredients) < 2:
                continue
            legendary = row.get("rarity") == "Legendary"
            if not legendary and row.get("rarity") not in ("Exotic", "Ascended"):
                continue
            roots.append((row, legendary))
        roots.sort(key=lambda r: (not r[1], r[0]["name"]))

        unresolved = set()
        trees = []
        for row, legendary in roots:
            tree = build_tree(row, items, by_name, loose, 0, set(), unresolved)
            if not tree.get("children"):
                continue
            tree["type"] = row.get("type")
            tree["kind"] = "legendary" if legendary else "gift"
            trees.append(tree)
        print("%s: %d recipes (%d legendary), %d unresolved names"
              % (lang, len(trees), sum(1 for t in trees if t["kind"] == "legendary"), len(unresolved)),
              flush=True)
        for name in sorted(unresolved)[:30]:
            print("  unresolved: " + name, flush=True)
        result["languages"][lang] = {"roots": trees, "unresolved": sorted(unresolved)}

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, separators=(",", ":"))
    print("wrote %s (%d bytes)" % (OUT, os.path.getsize(OUT)))


if __name__ == "__main__":
    main()
