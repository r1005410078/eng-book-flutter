# Course Pipeline Tools

## Entry Points
- Project script: `tools/course_pipeline/course_pipeline_ops.py`
- Global wrapper installer: `tools/course_pipeline/bin/install_global_command.sh`

## Quick Start
```bash
python3 tools/course_pipeline/course_pipeline_ops.py --help
bash tools/course_pipeline/bin/install_global_command.sh
course-pipeline --help
```

## Package Publish Helpers
Compute package checksum/size:
```bash
course-pipeline package inspect ./course.zip
```

Build `catalog.json` with computed `sha256` and `size_bytes`:
```bash
course-pipeline package build-catalog ./course.zip \
  --mode zip \
  --zip-url http://home.rongts.tech/engbook-courses/course.zip \
  --course-id course_daily_english \
  --title "Daily English" \
  --tags 全部,视频,入门 \
  --out ./catalog.json
```

By default, `--out` catalog is merged by `course_id` (update same id / keep others). Use `--catalog-replace` to overwrite it.

Auto mode by threshold (small zip / large segmented):
```bash
course-pipeline package build-catalog ./course.zip \
  --mode auto \
  --threshold-mib 512 \
  --zip-url http://home.rongts.tech/engbook-courses/course.zip \
  --manifest-url http://home.rongts.tech/engbook-courses/course.zip.manifest.json \
  --course-id course_daily_english \
  --title "Daily English" \
  --out ./catalog.json
```

Upload package to MinIO (requires `mc`):
```bash
course-pipeline package upload-minio ./course.zip \
  --endpoint http://home.rongts.tech \
  --bucket engbook-courses \
  --object-key course.zip \
  --make-bucket \
  --access-key "$COURSE_PIPELINE_MINIO_ACCESS_KEY" \
  --secret-key "$COURSE_PIPELINE_MINIO_SECRET_KEY"
```

Segmented upload for large packages (more stable on low-memory VMs):
```bash
course-pipeline package upload-minio-segmented ./course.zip \
  --endpoint http://home.rongts.tech \
  --bucket engbook-courses \
  --object-prefix course.zip \
  --part-size-mib 256 \
  --manifest-object-key course.zip.manifest.json \
  --access-key "$COURSE_PIPELINE_MINIO_ACCESS_KEY" \
  --secret-key "$COURSE_PIPELINE_MINIO_SECRET_KEY"
```

This command uploads `course.zip.part-0001` ... `course.zip.part-XXXX` and writes a manifest JSON locally (and to MinIO by default).

Restore package from segmented manifest:
```bash
course-pipeline package download-minio-segmented \
  --manifest-object-key course.zip.manifest.json \
  --endpoint http://home.rongts.tech \
  --bucket engbook-courses \
  --out ./course-restored.zip \
  --access-key "$COURSE_PIPELINE_MINIO_ACCESS_KEY" \
  --secret-key "$COURSE_PIPELINE_MINIO_SECRET_KEY"
```

Or restore from a local manifest file:
```bash
course-pipeline package download-minio-segmented \
  --manifest-file ./course.zip.parts.json \
  --out ./course-restored.zip \
  --access-key "$COURSE_PIPELINE_MINIO_ACCESS_KEY" \
  --secret-key "$COURSE_PIPELINE_MINIO_SECRET_KEY"
```

One command publish (auto choose zip/segmented by threshold) and generate catalog:
```bash
course-pipeline package publish-minio-auto ./course.zip \
  --endpoint http://home.rongts.tech \
  --bucket engbook-courses \
  --course-id course_daily_english \
  --title "Daily English" \
  --threshold-mib 512 \
  --part-size-mib 256 \
  --object-prefix course_daily_english/1.0.0/course.zip \
  --catalog-out ./catalog.json \
  --access-key "$COURSE_PIPELINE_MINIO_ACCESS_KEY" \
  --secret-key "$COURSE_PIPELINE_MINIO_SECRET_KEY"
```

Default object path is `<course_id>/<version_name>/<file_name>` to avoid overwrite across versions.  
`catalog-out` is merged by `course_id` by default; use `--catalog-replace` if you need full replacement.

Republish all packaged runtime courses (delete remote `<course_id>/` first, then upload latest task package per course):
```bash
course-pipeline package republish-runtime \
  --endpoint http://home.rongts.tech \
  --bucket engbook-courses \
  --catalog-out ./catalog.json \
  --access-key "$COURSE_PIPELINE_MINIO_ACCESS_KEY" \
  --secret-key "$COURSE_PIPELINE_MINIO_SECRET_KEY"
```

If a task has no `*.zip`, command will auto-pack `.runtime/tasks/<task_id>/package/` into `<course_id>.zip` before publishing.  
Use `--no-pack-if-missing` to disable that behavior.

If `file_path` is under `.runtime/tasks/<task_id>/...` (or `--task-id` is provided), command also writes:
- `.runtime/tasks/<task_id>/output_publish.json`

## Human-in-the-loop Steps
Use explicit step commands for AI stages:
- `course-pipeline task run-step <task_id> translate`
- `course-pipeline task run-step <task_id> grammar`
- `course-pipeline task run-step <task_id> summary`

## HITL Override Files
When `translate`, `grammar`, `summary` step runs, the pipeline generates input files under:
- `.runtime/tasks/<task_id>/hitl/*_translate_input.json`
- `.runtime/tasks/<task_id>/hitl/*_grammar_input.json`
- `.runtime/tasks/<task_id>/hitl/*_summary_input.json`

To provide manual AI output, write one of these optional files before re-running a step:
- `*_translate_output.json`
- `*_grammar_output.json`
- `*_summary_output.json`

Then run `task run-step` again; pipeline will consume override output and write `*_effective.json`.
