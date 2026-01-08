# Proposal: Integrate BetterPlayer for Video Playback

## Objective

Enhance the learning experience by replacing the static visual area with a fully functional video player using `better_player`. This allows users to watch video content associated with the lessons, which is crucial for the 100LS methodology (learning from movies/TV shows).

## Plan

### 1. Update Dependencies

- **Action**: Ensure `better_player` is properly configured in `pubspec.yaml` (It is already present).

### 2. Update Mock Data (`lib/src/features/audio_player/models/mock_data.dart`)

- **Action**: Add a mock video URL to `MockDataService`.
- **Details**:
  - Add `static const String videoUrl`.
  - Use a reliable public test video URL (e.g., Big Buck Bunny or similar standard test streams) to ensure playback works immediately.

### 3. Create Video Player Widget

- **Action**: Create a new widget `VideoPlayerArea` (or update `VisualArea`).
- **Details**:
  - **Path**: `lib/src/features/audio_player/widgets/video_player_area.dart` (New file recommended to keep `VisualArea` as fallback or separate component).
  - **Logic**:
    - Initialize `BetterPlayerController`.
    - Configure `BetterPlayerConfiguration` for a clean, educational UI (e.g., minimal controls, loop optional).
    - Handle lifecycle (dispose controller).
  - **Features**:
    - Play/Pause toggle.
    - Sync with existing audio control logic (If the app architecture treats audio and video as separate modes, we might need a centralized media controller. For this iteration, we will focus on embedding the player first).

### 4. Integrate into Screen (`lib/src/features/audio_player/screens/audio_player_screen.dart`)

- **Action**: Replace or conditionally render `VisualArea` with the new `VideoPlayerArea`.
- **Details**:
  - Add logic to determine if the current resource is audio-only or video.
  - Since we are moving to video, we will prioritize displaying the video player.

## Mock Data Update

I will add the following to `MockDataService`:

```dart
static const String videoUrl =
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
```

## Why this approach?

- **BetterPlayer** is a robust plugin derived from Chewie/VideoPlayer but with more features (caching, better controls) out of the box.
- Separation of concerns: Creating a dedicated `VideoPlayerArea` widget keeps the code clean and allows for easy swapping between a static cover image and a dynamic video player.

## Request for Approval

Please confirm if you would like to proceed with this plan, specifically:

1.  Using a dedicated `VideoPlayerArea` widget.
2.  Using the suggested mock video URL.
