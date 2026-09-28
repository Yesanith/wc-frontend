import unittest

from record_gems import KEEP_DAYS, add_point


class AddPointTest(unittest.TestCase):
    def test_appends_and_keeps_recent_points(self):
        now = 1_800_000_000
        old = [now - (KEEP_DAYS + 1) * 86400, 1, 1]
        recent = [now - 86400, 2, 2]
        data = add_point({"points": [old, recent]}, now, 30000, 20000)
        self.assertEqual(data["points"], [recent, [now, 30000, 20000]])

    def test_starts_from_nothing(self):
        self.assertEqual(add_point({}, 10, 1, 2), {"points": [[10, 1, 2]]})


if __name__ == "__main__":
    unittest.main()
