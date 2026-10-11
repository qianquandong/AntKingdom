"""反例确认校验器会阻止坏地图/文案，而不是仅打印 FAILED 后成功退出。"""
from contextlib import redirect_stdout
import io
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import check_map
import check_strings


class ValidationTests(unittest.TestCase):
    def test_current_map_passes(self):
        self.assertFalse(check_map.validate(check_map.MAP.read_text(encoding="utf-8").splitlines()))

    def test_current_strings_pass(self):
        self.assertFalse(check_strings.validate(check_strings.PRD.read_text(encoding="utf-8")))

    def test_bad_map_returns_failure(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "map.txt"
            path.write_text("bad map", encoding="utf-8")
            with patch.object(check_map, "MAP", path), redirect_stdout(io.StringIO()):
                self.assertEqual(check_map.main(), 1)

    def test_broken_footprint_and_disconnected_tunnel_rejected(self):
        grid = check_map.MAP.read_text(encoding="utf-8").splitlines()
        grid[3] = "###QQ####"
        grid[9] = ".########"
        errors = check_map.validate(grid)
        self.assertTrue(any("footprint" in error for error in errors))
        self.assertTrue(any("disconnected" in error for error in errors))

    def test_string_failures_rejected(self):
        doc = check_strings.PRD.read_text(encoding="utf-8")
        bad_docs = [doc.replace("| Crumb Kingdom |", "| 蚂蚁 |"),
                    "Missing: `ui.missing`\n" + doc,
                    doc.replace("| Crumb Kingdom | 24 |", "| Crumb Kingdom | 3 |"),
                    doc.replace("{food}", "{missing}"),
                    doc.replace("`world.backyard`", "`game.title`")]
        for bad in bad_docs:
            with self.subTest(text=bad[:50]):
                self.assertTrue(check_strings.validate(bad))

    def test_bad_strings_return_failure(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "PRD.md"
            path.write_text("no appendix", encoding="utf-8")
            with patch.object(check_strings, "PRD", path), redirect_stdout(io.StringIO()):
                self.assertEqual(check_strings.main(), 1)


if __name__ == "__main__":
    unittest.main()
