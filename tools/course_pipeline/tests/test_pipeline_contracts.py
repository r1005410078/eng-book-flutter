import json
import tempfile
import unittest
from pathlib import Path

# Import project script functions directly for unit checks.
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import course_pipeline_ops as ops  # noqa: E402


class TestRawNamingRules(unittest.TestCase):
    def test_accept_valid_numbered_media(self):
        with tempfile.TemporaryDirectory() as td:
            p = Path(td)
            (p / "01_intro.mp3").write_bytes(b"x")
            (p / "02_topic.mp4").write_bytes(b"x")
            keys, err = ops.scan_raw_lessons(p)
            self.assertIsNone(err)
            self.assertEqual(keys, ["01", "02"])

    def test_reject_duplicate_lesson_key(self):
        with tempfile.TemporaryDirectory() as td:
            p = Path(td)
            (p / "01_a.mp3").write_bytes(b"x")
            (p / "01_b.mp4").write_bytes(b"x")
            keys, err = ops.scan_raw_lessons(p)
            self.assertEqual(keys, [])
            self.assertEqual(err, "RAW_FOLDER_DUPLICATE_LESSON")

    def test_reject_no_valid_media(self):
        with tempfile.TemporaryDirectory() as td:
            p = Path(td)
            (p / "hello.mp3").write_bytes(b"x")
            keys, err = ops.scan_raw_lessons(p)
            self.assertEqual(keys, [])
            self.assertEqual(err, "RAW_FOLDER_INVALID_NAME")


class TestSchemaFiles(unittest.TestCase):
    def test_schema_files_exist_and_are_json(self):
        root = Path(__file__).resolve().parents[1] / "schemas"
        required = [
            "course_manifest.schema.json",
            "lesson.schema.json",
            "task.schema.json",
        ]
        for name in required:
            path = root / name
            self.assertTrue(path.exists(), f"missing schema: {name}")
            data = json.loads(path.read_text(encoding="utf-8"))
            self.assertEqual(data.get("type"), "object")
            self.assertIn("required", data)

    def test_task_schema_has_required_status_enum(self):
        path = Path(__file__).resolve().parents[1] / "schemas" / "task.schema.json"
        data = json.loads(path.read_text(encoding="utf-8"))
        status_enum = data["properties"]["status"]["enum"]
        self.assertEqual(
            status_enum,
            ["uploaded", "processing", "paused", "ready", "failed", "stopped"],
        )


class TestPackageHelpers(unittest.TestCase):
    def test_sha256_and_size(self):
        with tempfile.TemporaryDirectory() as td:
            file_path = Path(td) / "course.zip"
            file_path.write_bytes(b"abc123")
            digest, size_bytes = ops.sha256_and_size(file_path)
            self.assertEqual(
                digest,
                "6ca13d52ca70c883e0f0bb101e425a89e8624de51db2d2392593af6a84118090",
            )
            self.assertEqual(size_bytes, 6)

    def test_normalize_endpoint_host(self):
        self.assertEqual(ops.normalize_endpoint_host("http://home.rongts.tech:9000"), "home.rongts.tech:9000")
        self.assertEqual(ops.normalize_endpoint_host("home.rongts.tech:9000"), "home.rongts.tech:9000")


if __name__ == "__main__":
    unittest.main()
