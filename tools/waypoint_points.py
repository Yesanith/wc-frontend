#!/usr/bin/env python3
"""Writes lib/data/waypoint_points.dart: where each waypoint of lib/data/waypoints.dart is on the world map, read from the bundled
markers (assets/data/worldmap_1_en.json.gz). The home page and the event panel need only these few points, not the whole map.

    python3 tools/waypoint_points.py
"""
import gzip
import json
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))


def main():
    with gzip.open(os.path.join(ROOT, "assets/data/worldmap_1_en.json.gz")) as f:
        rows = json.load(f)["rows"]
    points = {r[4]: (r[1], r[2]) for r in rows if r[0] == "waypoint" and r[4]}
    with open(os.path.join(ROOT, "lib/data/waypoints.dart"), encoding="utf-8") as f:
        codes = sorted(set(re.findall(r"Waypoint\([^,]+, '(\[&[^']+\])'\)", f.read())))
    missing = [c for c in codes if c not in points]
    if missing:
        print("not on the bundled map:", ", ".join(missing))
        return 1
    lines = [
        "// made from the bundled world map (assets/data/worldmap_1_en.json.gz) by tools/waypoint_points.py: where each waypoint of",
        "// lib/data/waypoints.dart is on the world map, in the map's own units. a waypoint does not move, so this is not made again",
        "// when the map data is, only when a waypoint is added there",
        "",
        "/// the place of a waypoint on the world map by its chat code",
        "const waypointPoints = <String, (double, double)>{",
    ]
    lines += [f"  '{c}': ({points[c][0]}, {points[c][1]})," for c in codes]
    lines.append("};")
    with open(os.path.join(ROOT, "lib/data/waypoint_points.dart"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print(len(codes), "waypoints written")
    return 0


if __name__ == "__main__":
    sys.exit(main())
