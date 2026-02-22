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

    def test_normalize_object_prefix(self):
        self.assertEqual(ops.normalize_object_prefix("", "course.zip"), "course.zip")
        self.assertEqual(ops.normalize_object_prefix("/packs//course", "course.zip"), "packs/course")

    def test_build_default_publish_object_prefix(self):
        self.assertEqual(
            ops.build_default_publish_object_prefix("course_daily_english", "1.2.3", "course.zip"),
            "course_daily_english/1.2.3/course.zip",
        )

    def test_merge_catalog_courses_append_new(self):
        existing = {
            "version": 1,
            "courses": [
                {"id": "course_a", "title": "A", "asset": {"mode": "zip"}},
            ],
        }
        incoming = {"id": "course_b", "title": "B", "asset": {"mode": "zip"}}
        merged = ops.merge_catalog_courses(existing, incoming, 2)
        self.assertEqual(merged["version"], 2)
        self.assertEqual([c["id"] for c in merged["courses"]], ["course_a", "course_b"])

    def test_merge_catalog_courses_replace_same_id(self):
        existing = {
            "version": 1,
            "courses": [
                {"id": "course_a", "title": "A-old", "asset": {"mode": "zip"}},
                {"id": "course_b", "title": "B", "asset": {"mode": "zip"}},
            ],
        }
        incoming = {"id": "course_a", "title": "A-new", "asset": {"mode": "segmented_zip"}}
        merged = ops.merge_catalog_courses(existing, incoming, 3)
        self.assertEqual(merged["version"], 3)
        self.assertEqual([c["id"] for c in merged["courses"]], ["course_a", "course_b"])
        self.assertEqual(merged["courses"][0]["title"], "A-new")

    def test_segmented_part_object_key(self):
        self.assertEqual(ops.segmented_part_object_key("course.zip", 1, 123), "course.zip.part-0001")
        self.assertEqual(ops.segmented_part_object_key("course.zip", 42, 12345), "course.zip.part-00042")

    def test_normalize_segment_manifest_parts(self):
        parts = [
            {"index": 2, "object_key": "b.part-0002"},
            {"index": 1, "object_key": "b.part-0001"},
        ]
        normalized = ops.normalize_segment_manifest_parts(parts)
        self.assertEqual([p["index"] for p in normalized], [1, 2])

    def test_normalize_segment_manifest_parts_invalid_gap(self):
        with self.assertRaises(ValueError):
            ops.normalize_segment_manifest_parts(
                [
                    {"index": 1, "object_key": "b.part-0001"},
                    {"index": 3, "object_key": "b.part-0003"},
                ]
            )

    def test_parser_has_republish_runtime_command(self):
        parser = ops.build_parser()
        args = parser.parse_args(
            [
                "package",
                "republish-runtime",
                "--endpoint",
                "http://127.0.0.1:9000",
                "--bucket",
                "engbook-courses",
            ]
        )
        self.assertEqual(args.entity, "package")
        self.assertEqual(args.action, "republish-runtime")

    def test_resolve_course_manifest_title_prefers_existing_manifest_title(self):
        with tempfile.TemporaryDirectory() as td:
            task = {"course_id": "course_demo"}
            package_dir = Path(td)
            (package_dir / "course_manifest.json").write_text(
                json.dumps({"title": "课程标题A"}, ensure_ascii=False),
                encoding="utf-8",
            )
            title = ops.resolve_course_manifest_title(task, package_dir)
            self.assertEqual(title, "课程标题A")

    def test_resolve_course_manifest_title_fallback_catalog_title(self):
        with tempfile.TemporaryDirectory() as td:
            task = {"course_id": "course_demo"}
            package_dir = Path(td)
            (package_dir / "catalog.json").write_text(
                json.dumps(
                    {"courses": [{"id": "course_demo", "title": "课程标题B"}]},
                    ensure_ascii=False,
                ),
                encoding="utf-8",
            )
            title = ops.resolve_course_manifest_title(task, package_dir)
            self.assertEqual(title, "课程标题B")

    def test_resolve_course_manifest_title_fallback_course_path_name(self):
        with tempfile.TemporaryDirectory() as td:
            task = {"course_id": "course_demo", "course_path": "/tmp/my_course_name"}
            package_dir = Path(td)
            title = ops.resolve_course_manifest_title(task, package_dir)
            self.assertEqual(title, "my course name")

    def test_resolve_course_manifest_title_ignores_id_like_manifest_title(self):
        with tempfile.TemporaryDirectory() as td:
            task = {"course_id": "course_demo", "course_path": "/tmp/friendly_name"}
            package_dir = Path(td)
            (package_dir / "course_manifest.json").write_text(
                json.dumps({"title": "course_demo"}, ensure_ascii=False),
                encoding="utf-8",
            )
            title = ops.resolve_course_manifest_title(task, package_dir)
            self.assertEqual(title, "friendly name")


if __name__ == "__main__":
    unittest.main()
