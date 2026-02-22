## 1. Implementation
- [x] 1.1 Add CLI subcommand `package upload-minio-segmented` with part-size and manifest options.
- [x] 1.2 Implement sequential segment upload and local manifest generation.
- [x] 1.3 Upload manifest object to MinIO by default and allow skipping.
- [x] 1.4 Update README with segmented upload usage.
- [x] 1.5 Add unit tests for segmented upload helper behavior.
- [x] 1.6 Add CLI subcommand `package download-minio-segmented` for manifest-driven restore.
- [x] 1.7 Validate restored file size and sha256 against manifest.
- [x] 1.8 Update README with segmented restore usage.
