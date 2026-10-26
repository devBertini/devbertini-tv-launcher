"""Tests of measure_frames.py's guard: it reads which app is in front before pressing any key.

    python -B tools/devbertini/test_measure_frames.py
"""
import importlib.util
import pathlib
import unittest

spec = importlib.util.spec_from_file_location("measure_frames", pathlib.Path(__file__).with_name("measure_frames.py"))
measure_frames = importlib.util.module_from_spec(spec)
spec.loader.exec_module(measure_frames)


class FocusedPackageTest(unittest.TestCase):
    def test_reads_the_app_in_front(self):
        dump = "  mCurrentFocus=Window{fc00e5c u0 com.netflix.ninja/com.netflix.ninja.MainActivity}\n"
        self.assertEqual(measure_frames.focused_package(dump), "com.netflix.ninja")

    def test_reads_the_launcher(self):
        dump = "  mCurrentFocus=Window{6972927 u0 com.leanbitlab.ltvL/com.leanbitlab.ltvL.MainActivity}"
        self.assertEqual(measure_frames.focused_package(dump), measure_frames.PKG)

    def test_nothing_in_front_reads_as_none(self):
        self.assertIsNone(measure_frames.focused_package("  mCurrentFocus=null\n"))
        self.assertIsNone(measure_frames.focused_package(""))


if __name__ == "__main__":
    unittest.main()
