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
    text = description.replace("\n", " ")
    out = []
    if "Mystic Forge" in text or "Mystic Toilet" in text:
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


def build_tree(item, items, by_name, depth, seen, unresolved):
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
            unresolved.add(raw)
            children.append({"id": None, "name": raw, "count": qty})
            continue
        child = build_tree(items[child_id], items, by_name, depth + 1, seen | {item["id"]}, unresolved)
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
        for row in items.values():
            by_name.setdefault(row["name"].lower(), row["id"])

        legendaries = [
            row for row in items.values()
            if row.get("rarity") == "Legendary" and row.get("type") in ("Weapon", "Armor", "Back", "Trinket")
            and row.get("description")
        ]
        legendaries.sort(key=lambda r: r["name"])

        unresolved = set()
        trees = []
        for row in legendaries:
            tree = build_tree(row, items, by_name, 0, set(), unresolved)
            # only keep things that actually have a forge recipe
            if tree.get("children"):
                tree["type"] = row.get("type")
                trees.append(tree)
        print("%s: %d legendaries with a recipe, %d unresolved names"
              % (lang, len(trees), len(unresolved)), flush=True)
        for name in sorted(unresolved)[:20]:
            print("  unresolved: " + name, flush=True)
        result["languages"][lang] = trees

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, separators=(",", ":"))
    print("wrote %s (%d bytes)" % (OUT, os.path.getsize(OUT)))


if __name__ == "__main__":
    main()
