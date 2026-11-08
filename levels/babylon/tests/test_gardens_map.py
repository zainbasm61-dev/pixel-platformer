#!/usr/bin/env python3
"""Map bounds, sign text, and route checks for the gardens blockout.

The step model is not a hero. Required travel moves one column at a time and
changes stand height by at most one tile. Optional travel allows a two-tile
step. Nothing here claims a measured jump.
"""

import json
import unittest
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAP_PATH = ROOT / "gardens_map.txt"
CONTRACT_PATH = ROOT / "gardens_contract.json"
SCENE_PATH = ROOT / "gardens_level.tscn"
TILE = 16


def load_map():
    rows = [line for line in MAP_PATH.read_text().splitlines() if line != ""]
    return rows


def load_contract():
    return json.loads(CONTRACT_PATH.read_text())


def can_stand(rows, x, y):
    height = len(rows)
    width = len(rows[0])
    return 0 <= x < width and 0 <= y < height - 1 and rows[y][x] != "#" and rows[y + 1][x] == "#"


def reach(rows, start, step, blocked):
    seen = {start}
    queue = deque([start])
    width = len(rows[0])
    while queue:
        x, y = queue.popleft()
        for nx in (x - 1, x + 1):
            if not 0 <= nx < width:
                continue
            for dy in range(-step, step + 1):
                ny = y + dy
                nxt = (nx, ny)
                if nxt in seen or nxt in blocked or not can_stand(rows, nx, ny):
                    continue
                seen.add(nxt)
                queue.append(nxt)
    return seen


def clearance(rows, x, y):
    for ny in range(y - 1, -1, -1):
        if rows[ny][x] == "#":
            return (y - ny) * TILE
    return 999


def landing(rows, x, y):
    for ny in range(y, len(rows) - 1):
        if can_stand(rows, x, ny):
            return ny
    return None


class GardensMapTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rows = load_map()
        cls.contract = load_contract()
        cls.width = len(cls.rows[0])
        cls.height = len(cls.rows)
        spikes = {(item["x"], item["y"]) for item in cls.contract["spikes"]}
        ribbon = (cls.contract["ribbon"]["x"], cls.contract["ribbon"]["y"])
        cls.spawn = (cls.contract["spawn"]["x"], cls.contract["spawn"]["y"])
        cls.exit = (cls.contract["exit"]["x"], cls.contract["exit"]["y"])
        cls.ribbon = ribbon
        cls.spikes = spikes
        cls.required = reach(cls.rows, cls.spawn, 1, spikes | {ribbon})
        cls.optional = reach(cls.rows, cls.spawn, 2, set())
        cls.world = reach(cls.rows, cls.spawn, 2, set())

    def test_bounds(self):
        self.assertEqual([self.width, self.height], self.contract["map_size"])
        self.assertEqual(self.width, 140)
        self.assertEqual(self.height, 26)
        self.assertTrue(all(len(row) == self.width for row in self.rows))

    def test_sign_count_text_and_positions(self):
        signs = self.contract["signs"]
        self.assertEqual(len(signs), 4)
        glyphs = {sign["glyph"]: sign for sign in signs}
        self.assertEqual(set(glyphs), {"1", "2", "3", "4"})
        for sign in signs:
            x, y = sign["x"], sign["y"]
            self.assertEqual(self.rows[y][x], sign["glyph"])
            self.assertFalse(sign["unlocks_ability"])
            self.assertTrue(can_stand(self.rows, x, y))
        self.assertEqual(signs[0]["x"], 18)
        self.assertEqual(signs[1]["x"], 36)
        self.assertEqual(signs[2]["x"], 44)
        self.assertEqual(signs[3]["x"], 68)
        self.assertEqual(signs[0]["text"], "الشلالات تنزل من الجنائن للفرات. اقفز على الصخور، المي بارد.")
        self.assertEqual(signs[1]["text"], "شريط فيروزي على الغصن… هذي إشارتها.")
        self.assertEqual(signs[2]["text"], "الطين يطيعني. أبني منصة وأعبر.")
        self.assertEqual(signs[3]["text"], "حرس النمرود يدورون بين الأشجار. خليك فوقهم.")
        self.assertEqual(self.contract["opening_line"], "بابل بعدها خضرة… بس البرج صار يغطي الشمس.")
        self.assertEqual(self.contract["exit_line"], "الجنائن خلصت. من هنا يبدأ الحجر والنار.")
        self.assertEqual(self.contract["title"], "الطابق الأول — الجنائن المعلّقة")
        joined = "".join(self.rows)
        self.assertEqual(joined.count("1"), 1)
        self.assertEqual(joined.count("2"), 1)
        self.assertEqual(joined.count("3"), 1)
        self.assertEqual(joined.count("4"), 1)

    def test_ribbon_is_optional_and_behind_the_falls(self):
        ribbon = self.contract["ribbon"]
        self.assertEqual(ribbon["text"], "إذا لگيت هذا، يعني بعدك تحاول. لا توقف.")
        self.assertTrue(ribbon["optional"])
        self.assertFalse(ribbon["required_for_exit"])
        self.assertFalse(ribbon["required_for_clay"])
        self.assertEqual(ribbon["visual_class"], "hanging_ribbon")
        x, y = ribbon["x"], ribbon["y"]
        self.assertEqual(self.rows[y][x], "R")
        self.assertEqual(joined_count(self.rows, "R"), 1)
        self.assertTrue(90 <= x <= 94)
        self.assertIn("w", self.rows[8][x])
        self.assertNotIn(self.ribbon, self.required)
        self.assertIn(self.ribbon, self.optional)
        returned = reach(self.rows, self.ribbon, 2, set())
        self.assertIn(self.spawn, returned)
        self.assertIn(self.exit, returned)

    def test_route_guides_are_not_the_collectible(self):
        guides = self.contract["route_guides"]
        self.assertEqual(len(guides), 2)
        self.assertEqual(joined_count(self.rows, "t"), 2)
        for guide in guides:
            self.assertEqual(guide["visual_class"], "branch_band")
            self.assertNotEqual((guide["x"], guide["y"]), self.ribbon)
            self.assertEqual(self.rows[guide["y"]][guide["x"]], "t")
            self.assertFalse(90 <= guide["x"] <= 94)

    def test_required_route_reaches_exit_without_clay_or_spikes(self):
        self.assertIn(self.exit, self.required)
        self.assertIn(self.exit, reach(self.rows, self.spawn, 1, self.spikes))
        clay = self.contract["clay_pickup"]
        self.assertNotEqual((clay["x"], clay["y"]), (self.contract["signs"][2]["x"], self.contract["signs"][2]["y"]))
        self.assertEqual(self.rows[18][52], "p")
        self.assertEqual(self.rows[18][53], "p")
        self.assertTrue(can_stand(self.rows, 52, 19))
        self.assertIn((52, 19), self.required)
        self.assertFalse(self.contract["movement"]["mandatory_clay_gap"])
        self.assertFalse(self.contract["movement"]["estimates_tested_with_hero"])
        for ghost in self.contract["provisional_clay_ghosts"]:
            self.assertNotEqual(self.rows[ghost["y"]][ghost["x"]], "#")

    def test_clearance_cliffs_and_softlocks(self):
        mins = [clearance(self.rows, x, y) for x, y in self.required]
        self.assertGreaterEqual(min(mins), 32)
        width = self.width
        for x, y in self.world:
            for nx in (x - 1, x + 1):
                if nx < 0 or nx >= width:
                    self.fail(f"walk off the map from {(x, y)}")
                if self.rows[y][nx] == "#":
                    continue
                landed = landing(self.rows, nx, y)
                self.assertIsNotNone(landed, f"no landing beside {(x, y)}")
                self.assertLessEqual(landed - y, 2, f"cliff at {(x, y)} -> {nx}")
        for cell in self.world:
            self.assertIn(self.exit, reach(self.rows, cell, 2, set()), cell)

    def test_guard_checkpoints_and_spawn_are_inside_the_map(self):
        guard = self.contract["guard"]
        self.assertEqual(joined_count(self.rows, "G"), 1)
        self.assertEqual((guard["x"], guard["y"]), (74, 19))
        self.assertEqual(guard["taunt"], "الجنائن للنمرود!")
        self.assertEqual(guard["defeat_line"], "...الشلال أخذ ترسي.")
        self.assertTrue(all((x, 19) in self.required for x in range(60, 80)))
        self.assertTrue(all(self.rows[19][x] != "#" for x in range(60, 80)))
        points = self.contract["checkpoints"]
        self.assertEqual(len(points), 4)
        self.assertIn({"id": "cp_before_guard", "x": 60, "y": 19}, points)
        hazard_xs = {spike["x"] for spike in self.contract["spikes"]}
        for point in points:
            self.assertNotIn(point["x"], hazard_xs)
            self.assertTrue(can_stand(self.rows, point["x"], point["y"]))
            self.assertIn((point["x"], point["y"]), self.required)
        self.assertEqual(self.rows[19][2], "P")
        self.assertEqual(self.rows[15][137], "E")
        self.assertEqual(len(self.contract["spikes"]), 3)
        for spike in self.contract["spikes"]:
            self.assertEqual(self.rows[spike["y"]][spike["x"]], "X")
            self.assertIn(self.exit, reach(self.rows, (spike["x"], spike["y"]), 1, set()))
            self.assertTrue(110 <= spike["x"] <= 129)

    def test_markers_stay_inside_bounds(self):
        cells = []
        for sign in self.contract["signs"]:
            cells.append((sign["x"], sign["y"]))
        for key in ("spawn", "exit", "guard", "clay_pickup", "ribbon"):
            item = self.contract[key]
            cells.append((item["x"], item["y"]))
        for item in self.contract["checkpoints"] + self.contract["route_guides"] + self.contract["provisional_clay_ghosts"] + self.contract["spikes"]:
            cells.append((item["x"], item["y"]))
        for x, y in cells:
            self.assertTrue(0 <= x < self.width and 0 <= y < self.height, (x, y))

    def test_scene_file_does_not_import_legacy_gameplay(self):
        text = SCENE_PATH.read_text()
        self.assertIn("res://levels/babylon/gardens_level.gd", text)
        self.assertNotIn("res://player/", text)
        self.assertNotIn("res://enemies/", text)
        self.assertNotIn("res://gameplay/", text)
        self.assertNotIn("res://ui/", text)
        script = (ROOT / "gardens_level.gd").read_text()
        self.assertNotIn("preload(", script)
        self.assertNotIn("load(\"res://player/", script)
        self.assertIn("do_not_instance", script)


def joined_count(rows, glyph):
    return "".join(rows).count(glyph)


if __name__ == "__main__":
    unittest.main(verbosity=2)
