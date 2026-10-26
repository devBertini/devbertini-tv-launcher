# Copyright (C) 2026 Claudio Bertini (devBertini). GPL-3.0-or-later, like the rest of this project.
"""Tests of local_config.py: where the adb path and the known devices come from (tools/devbertini/local.json, never
versioned), and what happens when there is no such file.

    python -B tools/devbertini/test_local_config.py
"""
import importlib.util
import json
import os
import pathlib
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("local_config", pathlib.Path(__file__).with_name("local_config.py"))
local_config = importlib.util.module_from_spec(spec)
spec.loader.exec_module(local_config)

CONFIG = {
    "adb": "/opt/sdk/adb",
    "devices": {
        "living": {"serial": "AB12CD34EF56", "setup": ["common"]},
        "bedroom": {"serial": "ZY98XW76VU54"},
    },
}


class LoadTest(unittest.TestCase):
    def test_a_missing_file_is_an_empty_configuration(self):
        with tempfile.TemporaryDirectory() as folder:
            self.assertEqual(local_config.load(os.path.join(folder, "local.json")), {})

    def test_reads_the_file(self):
        with tempfile.TemporaryDirectory() as folder:
            path = os.path.join(folder, "local.json")
            with open(path, "w", encoding="utf-8") as f:
                json.dump(CONFIG, f)
            self.assertEqual(local_config.load(path), CONFIG)

    def test_a_file_that_is_not_json_names_itself_in_the_error(self):
        with tempfile.TemporaryDirectory() as folder:
            path = os.path.join(folder, "local.json")
            with open(path, "w", encoding="utf-8") as f:
                f.write("{not json")
            with self.assertRaises(ValueError) as caught:
                local_config.load(path)
            self.assertIn(path, str(caught.exception))


class AdbPathTest(unittest.TestCase):
    def test_the_environment_wins_over_the_file(self):
        self.assertEqual(local_config.adb_path(env={"ADB": "/env/adb"}, config=CONFIG), "/env/adb")

    def test_the_file_is_used_without_the_environment(self):
        self.assertEqual(local_config.adb_path(env={}, config=CONFIG), "/opt/sdk/adb")

    def test_without_either_adb_comes_from_the_path(self):
        self.assertEqual(local_config.adb_path(env={}, config={}), "adb")

    def test_an_empty_environment_value_is_ignored(self):
        self.assertEqual(local_config.adb_path(env={"ADB": ""}, config=CONFIG), "/opt/sdk/adb")


class DevicesTest(unittest.TestCase):
    def test_no_file_means_no_known_devices(self):
        self.assertEqual(local_config.devices({}), {})

    def test_a_named_device_gives_its_serial(self):
        self.assertEqual(local_config.serial_for("living", CONFIG), "AB12CD34EF56")
        self.assertEqual(local_config.serial_for("bedroom", CONFIG), "ZY98XW76VU54")

    def test_an_unknown_name_gives_nothing(self):
        self.assertIsNone(local_config.serial_for("garage", CONFIG))
        self.assertIsNone(local_config.serial_for("living", {}))

    def test_a_serial_is_accepted_as_it_is(self):
        self.assertEqual(local_config.serial_for("QQ00AA11BB22", {}), "QQ00AA11BB22")

    def test_the_error_names_what_can_be_given(self):
        with_file = local_config.unknown_device("garage", CONFIG)
        self.assertIn("'garage'", with_file)
        self.assertIn("living", with_file)
        self.assertIn("bedroom", with_file)
        without_file = local_config.unknown_device("garage", {})
        self.assertIn("ip:port", without_file)
        self.assertIn("serial", without_file)
        self.assertIn("local.json", without_file)


if __name__ == "__main__":
    unittest.main()
