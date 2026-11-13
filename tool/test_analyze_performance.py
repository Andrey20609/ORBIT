from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import analyze_performance


class FrameTimesTest(unittest.TestCase):
    def write(self, content: str) -> Path:
        directory = Path(self.temp_dir.name)
        path = directory / "gfxinfo-framestats.txt"
        path.write_text(content, encoding="utf-8")
        return path

    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def test_zero_rendered_frames_rejects_profile_rows(self) -> None:
        path = self.write(
            "Total frames rendered: 0\n"
            "Flags,HandleInputStart,FrameCompleted\n"
            "0,1000000,17000000\n"
        )
        self.assertEqual(analyze_performance.frame_times(path), [])

    def test_valid_duration_uses_matching_clock_fields(self) -> None:
        path = self.write(
            "Total frames rendered: 2\n"
            "Flags,HandleInputStart,FrameCompleted\n"
            "0,1000000,17000000\n"
            "0,20000000,40000000\n"
        )
        self.assertEqual(analyze_performance.frame_times(path), [16.0, 20.0])

    def test_absurd_or_nonpositive_durations_are_rejected(self) -> None:
        path = self.write(
            "Total frames rendered: 2\n"
            "Flags,HandleInputStart,FrameCompleted\n"
            "0,1,144112054394524960\n"
            "0,20000000,10000000\n"
        )
        self.assertEqual(analyze_performance.frame_times(path), [])


if __name__ == "__main__":
    unittest.main()
