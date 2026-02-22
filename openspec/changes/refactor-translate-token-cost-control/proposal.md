# Change: Reduce Translate Token Cost in Course Pipeline

## Why
The current translate step already batches requests, but it still over-consumes tokens and API calls in common real-world lessons due to avoidable fallback patterns. When a batch split fails, the code can degrade to per-sentence translation, causing request amplification and higher token cost.

## What Changes
- Replace newline-concatenation batching with multi-`q` parameter batching to keep sentence boundaries stable.
- Add translation de-duplication so repeated English sentences are translated once and reused.
- Add deterministic chunking (by sentence count and character budget) to avoid oversized requests.
- Add chunk-level retry/fallback instead of full per-sentence fallback for the whole lesson.
- Correct type contract for batch translator input (`list[str | None]`) to match actual call sites and improve maintainability.

## Impact
- Affected specs: `course-package`
- Affected code: `/Users/rongts/eng-book-flutter/tools/course_pipeline/course_pipeline_ops.py`
