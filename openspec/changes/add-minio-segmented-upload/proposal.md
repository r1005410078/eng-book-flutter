# Change: Add Segmented MinIO Upload For Large Course Packages

## Why
Large single-object uploads can fail on low-memory virtual machines with intermittent 502 errors and host instability.

## What Changes
- Add a new command `package upload-minio-segmented` to split large package files into multiple objects and upload sequentially.
- Generate a manifest JSON containing source checksum, part metadata, and object URLs.
- Support uploading manifest to MinIO by default for downstream automation.
- Add a restore command `package download-minio-segmented` to download parts by manifest and merge back into the original package file with checksum verification.

## Impact
- Affected specs: `course-package`
- Affected code: `tools/course_pipeline/course_pipeline_ops.py`, `tools/course_pipeline/README.md`, `tools/course_pipeline/tests/test_pipeline_contracts.py`
