"""Build the world map data the app ships with.

Two things make the first open of the map slow: every floor is several
megabytes of json, and the overview tiles have to be downloaded before
anything shows. This script fetches both once a month so the app opens the
map instantly.

  * markers: waypoints, points of interest, vistas, hearts, hero challenges,
    mastery points and the region, map and area labels of the embedded
    floors, one gzipped file per floor and language, in the same compact
    row format the app caches: [kind, x, y, name, chat_link, map_name]
  * tiles: floor 0 from zoom 0 to 2, which is everything the map shows
    before you zoom in on a region

Usage: python tools/build_worldmap.py en de es fr
"""

import gzip
import json
import os
import sys
import time
import urllib.error
import urllib.request

API = "https://api.guildwars2.com/v2"
TILES = "https://tiles.guildwars2.com"
CONTINENT = 1
FLOORS = [0, 1]
TILE_FLOOR = 0
TILE_MAX_LEVEL = 2
# the api says max_zoom 8 for tyria, but continent_dims are pixels at zoom 7
# and zoom 8 answers 404. the app uses the same constant
TILE_SCALE_ZOOM = 7
TILE = 256
DATA_DIR = os.path.join("assets", "data")
TILE_DIR = os.path.join("assets", "tiles")


def fetch(url, retries=4):
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(url, timeout=120) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            if attempt == retries - 1:
                raise
        except Exception:
            if attempt == retries - 1:
                raise
        time.sleep(2 * (attempt + 1))
    return None


def get(path, params=""):
    body = fetch("%s%s?v=latest%s" % (API, path, params))
    return json.loads(body.decode("utf-8")) if body else None


def extract(floor):
    """same rules as extractMarkers in lib/state/world_map.dart"""
    out = []

    def add(kind, coord, name, chat, map_name):
        if not (isinstance(coord, list) and len(coord) >= 2):
            return
        out.append([kind, float(coord[0]), float(coord[1]), name or "", chat or "", map_name])

    for region in (floor.get("regions") or {}).values():
        add("region", region.get("label_coord"), region.get("name"), "", "")
        for m in (region.get("maps") or {}).values():
            map_name = m.get("name") or ""
            if not map_name:
                continue
            add("map", m.get("label_coord"), map_name, "", map_name)
            for p in (m.get("points_of_interest") or {}).values():
                if p.get("type") in ("waypoint", "landmark", "vista", "unlock"):
                    add(p["type"], p.get("coord"), p.get("name"), p.get("chat_link"), map_name)
            for t in (m.get("tasks") or {}).values():
                add("heart", t.get("coord"), t.get("objective"), t.get("chat_link"), map_name)
            for h in m.get("skill_challenges") or []:
                add("hero", h.get("coord"), "", "", map_name)
            for mp in m.get("mastery_points") or []:
                add("mastery", mp.get("coord"), mp.get("region"), "", map_name)
            for sct in (m.get("sectors") or {}).values():
                add("sector", sct.get("coord"), sct.get("name"), sct.get("chat_link"), map_name)
    return out


def write_gz(path, data):
    with open(path, "wb") as raw:
        with gzip.GzipFile(fileobj=raw, mode="wb", compresslevel=9, mtime=0) as f:
            f.write(json.dumps(data, ensure_ascii=False, separators=(",", ":")).encode("utf-8"))


def build_markers(langs):
    os.makedirs(DATA_DIR, exist_ok=True)
    for floor in FLOORS:
        for lang in langs:
            data = get("/continents/%d/floors/%d" % (CONTINENT, floor), "&lang=" + lang)
            if not data:
                print("floor %d %s: nothing" % (floor, lang), flush=True)
                continue
            rows = extract(data)
            # rounded coordinates keep the file small, a unit is far below a pixel
            for r in rows:
                r[1] = round(r[1], 1)
                r[2] = round(r[2], 1)
            path = os.path.join(DATA_DIR, "worldmap_%d_%d_%s.json.gz" % (CONTINENT, floor, lang))
            write_gz(path, {"rows": rows})
            print("floor %d %s: %d markers, %d bytes" % (floor, lang, len(rows), os.path.getsize(path)), flush=True)


def build_tiles():
    continent = get("/continents/%d" % CONTINENT) or {}
    width, height = (continent.get("continent_dims") or [81920, 114688])[:2]
    max_zoom = TILE_SCALE_ZOOM
    total = 0
    for level in range(0, TILE_MAX_LEVEL + 1):
        span = TILE * 2 ** (max_zoom - level)
        cols = -(-width // span)
        rows = -(-height // span)
        folder = os.path.join(TILE_DIR, str(TILE_FLOOR), str(level))
        os.makedirs(folder, exist_ok=True)
        for x in range(cols):
            for y in range(rows):
                path = os.path.join(folder, "%d_%d.jpg" % (x, y))
                body = fetch("%s/%d/%d/%d/%d/%d.jpg" % (TILES, CONTINENT, TILE_FLOOR, level, x, y))
                if not body:
                    continue
                with open(path, "wb") as f:
                    f.write(body)
                total += len(body)
        print("tiles level %d: %dx%d" % (level, cols, rows), flush=True)
    print("tiles: %d bytes" % total, flush=True)


if __name__ == "__main__":
    build_markers(sys.argv[1:] or ["en"])
    build_tiles()
