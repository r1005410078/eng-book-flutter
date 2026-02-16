import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


class TestCommandExposure(unittest.TestCase):
    def test_wrapper_help_matches_script_help(self):
        repo = Path(__file__).resolve().parents[3]
        script = repo / "tools" / "course_pipeline" / "course_pipeline_ops.py"

        with tempfile.TemporaryDirectory() as td:
            td_path = Path(td)
            wrapper = td_path / "course-pipeline"
            wrapper.write_text(
                f"#!/usr/bin/env bash\npython3 '{script}' \"$@\"\n",
                encoding="utf-8",
            )
            wrapper.chmod(0o755)

            script_help = subprocess.check_output(["python3", str(script), "--help"], text=True)
            wrapper_help = subprocess.check_output([str(wrapper), "--help"], text=True)
            self.assertEqual(script_help, wrapper_help)


if __name__ == "__main__":
    unittest.main()
