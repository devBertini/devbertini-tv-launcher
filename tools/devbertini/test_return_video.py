# Copyright (C) 2026 Claudio Bertini (devBertini). GPL-3.0-or-later, like the rest of this project.
"""Tests of return_video.py's reading of screenrecord's raw frames and of its frame distance.

    python -B tools/devbertini/test_return_video.py
"""
import importlib.util
import pathlib
import struct
import unittest

spec = importlib.util.spec_from_file_location("return_video", pathlib.Path(__file__).with_name("return_video.py"))
return_video = importlib.util.module_from_spec(spec)
spec.loader.exec_module(return_video)

SIZE = return_video.SIZE


def frame(value):
    pixels = bytes([value]) * SIZE
    return struct.pack("<III", 16 + SIZE, return_video.W, return_video.H) + b"\x00" * 8 + pixels


class ParseFramesTest(unittest.TestCase):
    def test_reads_every_frame_in_order(self):
        frames = return_video.parse_frames(frame(10) + frame(200))
        self.assertEqual(len(frames), 2)
        self.assertEqual(frames[0][0], 10)
        self.assertEqual(frames[1][-1], 200)

    def test_a_truncated_last_frame_is_left_out(self):
        self.assertEqual(len(return_video.parse_frames(frame(1) + frame(2)[:-5])), 1)

    def test_another_size_is_refused(self):
        bad = struct.pack("<III", 16 + SIZE, 640, 360) + b"\x00" * 8 + b"\x00" * SIZE
        with self.assertRaises(ValueError):
            return_video.parse_frames(bad)


class DistanceTest(unittest.TestCase):
    def test_equal_frames_are_zero_and_black_to_white_is_255(self):
        black, white = bytes(SIZE), bytes([255]) * SIZE
        self.assertEqual(return_video.distance(black, black), 0)
        self.assertEqual(return_video.distance(black, white), 255)
        self.assertEqual(return_video.brightness(white), 255)


if __name__ == "__main__":
    unittest.main()
