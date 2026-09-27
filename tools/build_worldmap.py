"""Build the world map data the app ships with.

Two things make the first open of the map slow: every floor is several
megabytes of json, and the overview tiles have to be downloaded before
anything shows. This script fetches both once a month so the app opens the
map instantly.

  * markers: waypoints, points of interest, vistas, hearts, hero challenges,
    mastery points and the region, map and area labels of every open world
    map, one gzipped file per language, in the same compact row format the
    app caches: [kind, x, y, name, chat_link, map_name]
  * tiles: floor 1 from zoom 0 to 2, which is everything the map shows
    before you zoom in on a region

No single floor holds every map. The Path of Fire and Elona maps, for one,
are on none of floors 0 and 1, so reading one floor left them without a
single marker. Every public map is taken from its own default floor instead,
or from the next floor it lists when the default one does not carry it.

Usage: python tools/build_worldmap.py en de es fr
"""

import glob
import gzip
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

API = "https://api.guildwars2.com/v2"
TILES = "https://tiles.guildwars2.com"
CONTINENT = 1
# a run that finds fewer than this is broken, the old files are kept
MIN_MAPS = 100
MIN_WAYPOINTS = 600
# the floor the app opens on, the default floor of most maps
TILE_FLOOR = 1
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


def extract_map(m, map_name, out):
    """the rows of one map, same rules as extractMarkers in lib/state/world_map.dart"""

    def add(kind, coord, name, chat):
        if not (isinstance(coord, list) and len(coord) >= 2):
            return
        out.append([kind, float(coord[0]), float(coord[1]), name or "", chat or "", map_name])

    add("map", m.get("label_coord"), map_name, "")
    for p in (m.get("points_of_interest") or {}).values():
        if p.get("type") in ("waypoint", "landmark", "vista", "unlock"):
            add(p["type"], p.get("coord"), p.get("name"), p.get("chat_link"))
    for t in (m.get("tasks") or {}).values():
        add("heart", t.get("coord"), t.get("objective"), t.get("chat_link"))
    for h in m.get("skill_challenges") or []:
        add("hero", h.get("coord"), "", "")
    for mp in m.get("mastery_points") or []:
        add("mastery", mp.get("coord"), mp.get("region"), "")
    for sct in (m.get("sectors") or {}).values():
        add("sector", sct.get("coord"), sct.get("name"), sct.get("chat_link"))


def collect(maps, get_floor):
    """rows for every public map of the continent, each read from one floor.

    maps is the /v2/maps list, get_floor(floor) returns a floor response or
    None. a map is taken from its default floor, else from the next floor it
    lists that carries it, so it shows up exactly once."""
    wanted = {}
    for m in maps:
        if m.get("type") != "Public" or m.get("continent_id") != CONTINENT or not m.get("name"):
            continue
        default = m.get("default_floor")
        floors = [default] + [f for f in (m.get("floors") or []) if f != default]
        wanted[m["id"]] = [f for f in floors if isinstance(f, int)]

    rows = []
    regions = {}
    found = set()
    fetched = {}

    def floor(f):
        if f not in fetched:
            fetched[f] = get_floor(f)
        return fetched[f]

    # every candidate in turn: first all default floors, then the second
    # floor of whatever is still missing, and so on
    depth = 0
    while True:
        todo = {}
        for map_id, floors in wanted.items():
            if map_id not in found and depth < len(floors):
                todo.setdefault(floors[depth], set()).add(map_id)
        if not todo:
            break
        for f in sorted(todo):
            data = floor(f)
            if not data:
                continue
            for region_id, region in (data.get("regions") or {}).items():
                for map_id, m in (region.get("maps") or {}).items():
                    map_id = int(map_id)
                    if map_id not in todo[f] or map_id in found:
                        continue
                    found.add(map_id)
                    extract_map(m, m.get("name") or "", rows)
                    if region_id not in regions and isinstance(region.get("label_coord"), list):
                        coord = region["label_coord"]
                        regions[region_id] = ["region", float(coord[0]), float(coord[1]), region.get("name") or "", "", ""]
        depth += 1

    missing = sorted(set(wanted) - found)
    return list(regions.values()) + rows, missing


def write_gz(path, data):
    with open(path, "wb") as raw:
        with gzip.GzipFile(fileobj=raw, mode="wb", compresslevel=9, mtime=0) as f:
            f.write(json.dumps(data, ensure_ascii=False, separators=(",", ":")).encode("utf-8"))


def build_markers(langs):
    os.makedirs(DATA_DIR, exist_ok=True)
    for lang in langs:
        maps = get("/maps", "&ids=all&lang=" + lang) or []
        rows, missing = collect(
            maps,
            lambda f: get("/continents/%d/floors/%d" % (CONTINENT, f), "&lang=" + lang),
        )
        map_count = sum(1 for r in rows if r[0] == "map")
        waypoints = sum(1 for r in rows if r[0] == "waypoint")
        if map_count < MIN_MAPS or waypoints < MIN_WAYPOINTS:
            sys.exit("%s: only %d maps and %d waypoints, keeping the old data" % (lang, map_count, waypoints))
        # rounded coordinates keep the file small, a unit is far below a pixel
        for r in rows:
            r[1] = round(r[1], 1)
            r[2] = round(r[2], 1)
        path = os.path.join(DATA_DIR, "worldmap_%d_%s.json.gz" % (CONTINENT, lang))
        write_gz(path, {"rows": rows})
        # the per floor files of older runs are replaced by this one
        for old in glob.glob(os.path.join(DATA_DIR, "worldmap_%d_*_%s.json.gz" % (CONTINENT, lang))):
            if re.search(r"worldmap_%d_-?\d+_%s\.json\.gz$" % (CONTINENT, lang), old):
                os.remove(old)
        print(
            "%s: %d maps, %d waypoints, %d rows, %d bytes, %d maps on no floor %s"
            % (lang, map_count, waypoints, len(rows), os.path.getsize(path), len(missing), missing),
            flush=True,
        )


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
