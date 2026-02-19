import 'dart:io';

import 'package:video_player/video_player.dart';

class PracticePreviewControllerCacheService {
  const PracticePreviewControllerCacheService();

  void clear({
    required Map<int, VideoPlayerController> previewControllerCache,
    required Set<int> previewControllerLoading,
  }) {
    for (final controller in previewControllerCache.values) {
      controller.dispose();
    }
    previewControllerCache.clear();
    previewControllerLoading.clear();
  }

  void disposeStale({
    required Map<int, VideoPlayerController> previewControllerCache,
    required Iterable<int> staleIndices,
  }) {
    for (final index in staleIndices) {
      previewControllerCache.remove(index)?.dispose();
    }
  }

  Future<VideoPlayerController?> ensureControllerForIndex({
    required int index,
    required bool useAudio,
    required String mediaPath,
    required Duration seekTo,
    required double volume,
    required double playbackSpeed,
    required bool isMounted,
    required Map<int, VideoPlayerController> previewControllerCache,
    required Set<int> previewControllerLoading,
  }) async {
    final cached = previewControllerCache[index];
    if (cached != null) return cached;
    if (previewControllerLoading.contains(index)) return null;
    if (useAudio || mediaPath.isEmpty) return null;

    previewControllerLoading.add(index);
    VideoPlayerController? created;
    try {
      created = VideoPlayerController.file(File(mediaPath));
      await created.initialize();
      await created.setVolume(volume);
      await created.setPlaybackSpeed(playbackSpeed);
      await created.seekTo(seekTo);
      if (!isMounted) {
        await created.dispose();
        return null;
      }
      final existing = previewControllerCache[index];
      if (existing != null) {
        await created.dispose();
        return existing;
      }
      previewControllerCache[index] = created;
      return created;
    } catch (_) {
      await created?.dispose();
      return null;
    } finally {
      previewControllerLoading.remove(index);
    }
  }
}
