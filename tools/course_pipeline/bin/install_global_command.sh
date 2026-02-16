#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${HOME}/.local/bin"
TARGET_CMD="${TARGET_DIR}/course-pipeline"
PROJECT_SCRIPT="/Users/rongts/eng-book-flutter/tools/course_pipeline/course_pipeline_ops.py"

mkdir -p "${TARGET_DIR}"
cat > "${TARGET_CMD}" <<WRAP
#!/usr/bin/env bash
python3 "${PROJECT_SCRIPT}" "$@"
WRAP
chmod +x "${TARGET_CMD}"

echo "Installed: ${TARGET_CMD}"
echo "Ensure PATH includes: ${TARGET_DIR}"
