"""Checks the marker merge without the network: python -m unittest discover tools"""

import unittest

import build_worldmap as b


def game_map(name, waypoints):
    return {
        "name": name,
        "label_coord": [1, 1],
        "points_of_interest": {
            str(i): {"type": "waypoint", "name": "%s %d" % (name, i), "coord": [i, i], "chat_link": "x"}
            for i in range(waypoints)
        },
    }


FLOORS = {
    1: {"regions": {"4": {"name": "Kryta", "label_coord": [5, 5], "maps": {
        "15": game_map("Queensdale", 2),
        "99": game_map("Story instance", 1),
        "20": game_map("Lake Doric", 1),
    }}}},
    49: {"regions": {"12": {"name": "Crystal Desert", "label_coord": [9, 9], "maps": {
        "1210": game_map("Crystal Oasis", 3),
    }}}},
    50: {"regions": {"4": {"name": "Kryta", "label_coord": [5, 5], "maps": {
        "20": game_map("Lake Doric", 4),
    }}}},
}

MAPS = [
    {"id": 15, "name": "Queensdale", "type": "Public", "continent_id": 1, "default_floor": 1, "floors": [0, 1]},
    {"id": 99, "name": "Story", "type": "Instance", "continent_id": 1, "default_floor": 1, "floors": [1]},
    {"id": 1210, "name": "Crystal Oasis", "type": "Public", "continent_id": 1, "default_floor": 49, "floors": [49]},
    # the default floor does not carry it, the next listed floor does
    {"id": 20, "name": "Lake Doric", "type": "Public", "continent_id": 1, "default_floor": 7, "floors": [7, 50, 1]},
    {"id": 30, "name": "Nowhere", "type": "Public", "continent_id": 1, "default_floor": 8, "floors": [8]},
    {"id": 40, "name": "Mists", "type": "Public", "continent_id": 2, "default_floor": 1, "floors": [1]},
]


class CollectTest(unittest.TestCase):
    def setUp(self):
        self.calls = []

        def get_floor(f):
            self.calls.append(f)
            return FLOORS.get(f)

        self.rows, self.missing = b.collect(MAPS, get_floor)

    def waypoints(self, map_name):
        return [r for r in self.rows if r[0] == "waypoint" and r[5] == map_name]

    def test_maps_off_the_main_floors_are_found(self):
        self.assertEqual(len(self.waypoints("Crystal Oasis")), 3)

    def test_each_map_comes_from_one_floor_only(self):
        # its default floor 7 is empty, floor 50 has it, the floor 1 copy is ignored
        self.assertEqual(len(self.waypoints("Lake Doric")), 4)
        self.assertEqual([r[3] for r in self.rows if r[0] == "map"].count("Lake Doric"), 1)

    def test_instances_and_other_continents_are_left_out(self):
        names = {r[5] for r in self.rows}
        self.assertNotIn("Story instance", names)
        self.assertNotIn("Mists", names)

    def test_regions_are_labelled_once(self):
        self.assertEqual(sorted(r[3] for r in self.rows if r[0] == "region"), ["Crystal Desert", "Kryta"])

    def test_a_map_on_no_floor_is_reported(self):
        self.assertEqual(self.missing, [30])

    def test_every_floor_is_fetched_once(self):
        self.assertEqual(sorted(self.calls), sorted(set(self.calls)))


if __name__ == "__main__":
    unittest.main()
