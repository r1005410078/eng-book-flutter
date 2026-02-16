# Assistant Memory (Project Snapshot)

Last updated: 2026-02-16

## 1) Project Summary
- Project: `engbooks` (Flutter app for English learning / 100LS practice).
- Goal: sentence-level listening/speaking drills + reading mode, with course-based learning flow.
- Current stage: MVP with heavy mock data on UI and learning flow.

## 2) Tech & Structure
- Stack: Flutter 3.x, Dart (null safety), Riverpod, go_router.
- Main entry: `lib/main.dart`, app root: `lib/app.dart`.
- Routing:
  - `/` -> `HomeScreen`
  - `/practice/sentence/:id` -> `SentencePracticeScreen`
  - `/practice/reading/:id` -> `ReadingPracticeScreen`
  - `/practice/settings` -> `PlaybackSettingsScreen`
  - `/course/detail` -> `CourseDetailScreen` (expects `Course` in `extra`)
- Feature-first folders:
  - `lib/src/features/home/*`
  - `lib/src/features/practice/*`
  - `lib/src/routing/*`

## 3) Current Product Behavior (as implemented)
- Home page shows a dark-theme learning path UI with mock nodes and progress card.
- Top-right icon opens `CourseSelectionScreen` (modal bottom sheet style).
- Course selection supports mock category filtering and opens course detail page.
- Course detail page is presentational; "开始学习" action is TODO.
- Sentence practice page uses `video_player` with a remote demo video (`Sintel.mp4`), sentence sync by timestamp, and floating controls.
- Reading practice page lists transcript-style sentences and supports sentence focus/jump.
- Playback settings page is local state only (not wired to shared state).
- Sentence/content data is from `lib/src/features/practice/data/mock_data.dart` (150 generated sentences).

## 4) OpenSpec Baseline
- Core spec currently listed by OpenSpec CLI: `ui` (8 requirements) at `openspec/specs/ui/spec.md`.
- `openspec/project.md` defines:
  - mobile-first MVP
  - feature-first architecture
  - Riverpod/go_router conventions
  - testing expectations (unit/widget/integration)

## 5) Active Changes (not archived)
- Incomplete:
  - `integrate-backend-api` -> `0/6` tasks
  - `refactor-home-screen` -> `0/6` tasks
  - `add-reading-page` -> `0/5` tasks
- Marked complete in tasks:
  - `add-sentence-practice-view`
  - `enrich-video-controls`
  - `disable-waveform-web`
  - `change-video-interaction`
  - `fix-scrub-sync`
  - `keep-bottom-toolbar-visible`
  - `keep-header-visible`
  - `link-progress-and-mock-data`
  - `polish-video-ui`
  - `real-waveform`
  - `refactor-header-style`
  - `refine-video-controls`

## 6) Practical Working Notes
- Treat this repo as a UI-first MVP with some spec/task mismatch possible (some features exist in code while tasks remain unchecked).
- Backend integration has proposal/tasks but is not implemented end-to-end yet.
- If user asks for new capability or architecture shift, follow OpenSpec flow from `openspec/AGENTS.md` before coding.

