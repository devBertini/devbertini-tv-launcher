# Copyright (C) 2026 Claudio Bertini (devBertini). GPL-3.0-or-later, like the rest of this project.
"""Tests of frame_log.py's reading of logcat: frames go to the moment whose marks hold them, and the budget counts.

    python -B tools/devbertini/test_frame_log.py
"""
import importlib.util
import pathlib
import unittest

spec = importlib.util.spec_from_file_location("frame_log", pathlib.Path(__file__).with_name("frame_log.py"))
frame_log = importlib.util.module_from_spec(spec)
spec.loader.exec_module(frame_log)

LOG = """I/flutter ( 4242): DevBertiniFrame build=9000 raster=8000 total=20000
I/DevBertiniMark( 5000): row start
I/flutter ( 4242): DevBertiniFrame build=4000 raster=12000 total=18000
I/flutter ( 4242): DevBertiniFrame build=5000 raster=21000 total=30000
I/DevBertiniMark( 5001): row end
I/flutter ( 4242): DevBertiniFrame build=1000 raster=1000 total=2000
I/DevBertiniMark( 5002): hero_and_back start
I/flutter ( 4242): DevBertiniFrame build=17000 raster=3000 total=22000
I/DevBertiniMark( 5003): hero_and_back end
"""


class SplitFramesTest(unittest.TestCase):
    def test_frames_belong_to_the_moment_between_its_marks(self):
        moments = frame_log.split_frames(LOG)
        self.assertEqual([f["raster"] for f in moments["row"]], [12000, 21000])
        self.assertEqual([f["build"] for f in moments["hero_and_back"]], [17000])

    def test_a_repeated_moment_gathers_every_run(self):
        moments = frame_log.split_frames(LOG + LOG)
        self.assertEqual(len(moments["row"]), 4)


class SummarizeTest(unittest.TestCase):
    def test_counts_the_frames_over_the_budget_on_each_thread(self):
        summary = frame_log.summarize(frame_log.split_frames(LOG)["row"])
        self.assertEqual(summary["frames"], 2)
        self.assertEqual(summary["raster"]["over_budget"], 1)
        self.assertEqual(summary["build"]["over_budget"], 0)
        self.assertEqual(summary["raster"]["max_ms"], 21.0)

    def test_no_frames_gives_empty_stats(self):
        self.assertEqual(frame_log.summarize([])["build"]["over_budget"], 0)


class FocusedPackageTest(unittest.TestCase):
    def test_reads_the_app_in_front(self):
        dump = "  mCurrentFocus=Window{fc00e5c u0 com.netflix.ninja/com.netflix.ninja.MainActivity}\n"
        self.assertEqual(frame_log.focused_package(dump), "com.netflix.ninja")


if __name__ == "__main__":
    unittest.main()
