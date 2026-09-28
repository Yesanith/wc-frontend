"""Record the gem exchange so the app can chart it.

The api only answers with the current rate. Every few hours this adds one
point to gems.json on the gem-history branch: the gold one hundred gems
cost, and the gold one hundred gems sell for, both in copper. Forty days
are kept, the app charts the last thirty.

Usage: python tools/record_gems.py path/to/gems.json
"""

import json
import os
import sys
import time
import urllib.request

API = "https://api.guildwars2.com/v2"
KEEP_DAYS = 40


def get(path):
    with urllib.request.urlopen(API + path, timeout=60) as r:
        return json.loads(r.read().decode("utf-8"))


def add_point(data, now, buy, sell):
    """drops points older than KEEP_DAYS and appends the new one"""
    points = [p for p in data.get("points", []) if p[0] > now - KEEP_DAYS * 86400]
    points.append([now, buy, sell])
    return {"points": points}


def main(path):
    # what 100 gems bring when sold for gold
    sell = int(get("/commerce/exchange/gems?quantity=100")["quantity"])
    # what 100 gems cost: the rate for a large amount of gold, times 100
    buy = int(get("/commerce/exchange/coins?quantity=10000000")["coins_per_gem"]) * 100
    data = {}
    if os.path.exists(path):
        with open(path) as f:
            data = json.load(f)
    data = add_point(data, int(time.time()), buy, sell)
    with open(path, "w") as f:
        json.dump(data, f, separators=(",", ":"))
    print("100 gems: buy %d, sell %d copper, %d points" % (buy, sell, len(data["points"])))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "gems.json")
