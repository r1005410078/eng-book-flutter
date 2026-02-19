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
  --download-url http://home.rongts.tech:9000/engbook-courses/course.zip \
  --course-id course_daily_english \
  --title "Daily English" \
  --out ./catalog.json
```

Upload package to MinIO (requires `mc`):
```bash
course-pipeline package upload-minio ./course.zip \
  --endpoint http://home.rongts.tech:9000 \
  --bucket engbook-courses \
  --object-key course.zip \
  --make-bucket \
  --access-key "$COURSE_PIPELINE_MINIO_ACCESS_KEY" \
  --secret-key "$COURSE_PIPELINE_MINIO_SECRET_KEY"
```

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
