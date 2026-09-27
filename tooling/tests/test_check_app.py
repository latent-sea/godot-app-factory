"""Tests for how tooling/check_app.py judges a run: exit code, pass line and clean output must all agree."""

from __future__ import annotations

import subprocess
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import check_app  # noqa: E402


def ran(code: int, out: str, err: str = "") -> subprocess.CompletedProcess[str]:
    return subprocess.CompletedProcess(["godot"], code, out, err)


class VerdictTest(unittest.TestCase):
    def test_all_three_agree(self) -> None:
        self.assertIsNone(check_app.verdict("t", ran(0, "Godot Engine v4.6.2\nPASS test_x.gd\n"), "PASS test_x.gd"))

    def test_nonzero_exit_fails_even_with_the_pass_line(self) -> None:
        self.assertIn("exited 1", check_app.verdict("t", ran(1, "PASS test_x.gd\n"), "PASS test_x.gd"))

    def test_missing_pass_line_fails_even_on_exit_zero(self) -> None:
        self.assertIn("never printed", check_app.verdict("t", ran(0, "all good really\n"), "PASS test_x.gd"))

    def test_pass_line_must_be_a_whole_line(self) -> None:
        self.assertIn("never printed", check_app.verdict("t", ran(0, "PASS test_x.gd.bak\n"), "PASS test_x.gd"))

    def test_script_error_fails_even_when_it_passed(self) -> None:
        out = "PASS test_x.gd\n"
        err = "SCRIPT ERROR: Invalid call. Nonexistent function 'nope'.\n   at: _init (res://tests/test_x.gd:4)\n"
        self.assertIn("reports trouble", check_app.verdict("t", ran(0, out, err), "PASS test_x.gd"))

    def test_engine_error_fails(self) -> None:
        self.assertIn("reports trouble", check_app.verdict("t", ran(0, "PROBE OK\n", "ERROR: Condition failed.\n"), "PROBE OK"))

    def test_a_timeout_fails(self) -> None:
        self.assertIn("exited -1", check_app.verdict("t", ran(-1, "", "still running after 300s; stopped\n"), "PROBE OK"))

    def test_words_that_merely_contain_error_are_fine(self) -> None:
        out = "the list shows no errors\nPROBE OK\n"
        self.assertIsNone(check_app.verdict("t", ran(0, out), "PROBE OK"))


if __name__ == "__main__":
    unittest.main()
