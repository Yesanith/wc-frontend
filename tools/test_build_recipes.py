"""Checks the batched fetch without the network: python -m unittest discover tools"""

import threading
import time
import unittest

import build_recipes as b


class FetchBatchesTest(unittest.TestCase):
    def test_rows_keep_the_order_of_the_ids(self):
        def fetch(path, params):
            ids = [int(x) for x in params["ids"].split(",")]
            # later batches answer first, the result must not care
            time.sleep(0.001 * (1000 - ids[0]) / 200)
            return [{"id": i, "lang": params.get("lang")} for i in ids]

        rows = b.fetch_batches("/items", list(range(1000)), {"lang": "de"}, fetch=fetch, workers=4)
        self.assertEqual([r["id"] for r in rows], list(range(1000)))
        self.assertTrue(all(r["lang"] == "de" for r in rows))

    def test_batches_are_at_most_the_api_limit(self):
        sizes = []

        def fetch(path, params):
            sizes.append(len(params["ids"].split(",")))
            return []

        b.fetch_batches("/recipes", list(range(450)), fetch=fetch)
        self.assertEqual(sorted(sizes), [50, 200, 200])

    def test_several_requests_run_at_once(self):
        running = 0
        peak = 0
        lock = threading.Lock()

        def fetch(path, params):
            nonlocal running, peak
            with lock:
                running += 1
                peak = max(peak, running)
            time.sleep(0.02)
            with lock:
                running -= 1
            return []

        b.fetch_batches("/items", list(range(200 * 8)), fetch=fetch, workers=4)
        self.assertGreater(peak, 1)
        self.assertLessEqual(peak, 4)

    def test_no_ids_means_no_requests(self):
        self.assertEqual(b.fetch_batches("/items", [], fetch=lambda p, q: self.fail("fetched")), [])


class MarketLinesTest(unittest.TestCase):
    def test_only_listed_items_in_id_order(self):
        items = {
            3: {"id": 3, "type": "Weapon", "rarity": "Exotic", "level": 80, "details": {"type": "LongBow"}},
            1: {"id": 1, "type": "CraftingMaterial", "rarity": "Basic", "level": 0},
            2: {"id": 2, "type": "Trophy", "rarity": "Junk", "level": 0},
        }
        lines = b.market_lines(items, [3, 1, 3, 99])
        self.assertEqual(lines, ["1\tCraftingMaterial\t\tBasic\t0\n", "3\tWeapon\tLongBow\tExotic\t80\n"])

    def test_subtypes_lose_their_spaces(self):
        items = {5: {"id": 5, "type": "Armor", "rarity": "Rare", "level": 1, "details": {"type": "Heavy Coat"}}}
        self.assertEqual(b.market_lines(items, [5]), ["5\tArmor\tHeavyCoat\tRare\t1\n"])


if __name__ == "__main__":
    unittest.main()
