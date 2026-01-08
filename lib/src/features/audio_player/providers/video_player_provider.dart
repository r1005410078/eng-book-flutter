import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:video_player/video_player.dart';
import 'package:collection/collection.dart';
import '../models/mock_data.dart';
import '../models/sentence.dart';

part 'video_player_provider.g.dart';

class VideoPlayerState {
  final bool isInitialized;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final VideoPlayerController? controller;

  const VideoPlayerState({
    this.isInitialized = false,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.controller,
  });

  VideoPlayerState copyWith({
    bool? isInitialized,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    VideoPlayerController? controller,
  }) {
    return VideoPlayerState(
      isInitialized: isInitialized ?? this.isInitialized,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      controller: controller ?? this.controller,
    );
  }
}

@riverpod
class VideoPlayerNotifier extends _$VideoPlayerNotifier {
  VideoPlayerController? _controller;

  @override
  VideoPlayerState build() {
    ref.onDispose(() {
      _controller?.dispose();
    });
    return const VideoPlayerState();
  }

  Future<void> initialize(String url) async {
    // If already initialized with same URL, skip? For now, simplistic reload.
    _controller?.dispose();

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;

    // Listen to controller updates
    controller.addListener(_onVideoControllerUpdate);

    await controller.initialize();

    // Update state to initialized
    state = state.copyWith(
      controller: controller,
      isInitialized: true,
      duration: controller.value.duration,
    );
  }

  void _onVideoControllerUpdate() {
    if (_controller == null) return;
    final value = _controller!.value;

    // Only update state if things changed to avoid unnecessary rebuilds,
    // but Riverpod handles distinct states well.
    // For position (very frequent), we might want to be careful, but for subtitle sync we need it.

    state = state.copyWith(
      isInitialized: value.isInitialized,
      isPlaying: value.isPlaying,
      position: value.position,
      duration: value.duration,
    );
  }

  Future<void> play() async {
    await _controller?.play();
  }

  Future<void> pause() async {
    await _controller?.pause();
  }

  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seekTo(Duration position) async {
    await _controller?.seekTo(position);
  }

  /// 获取当前播放的句子
  Sentence? get currentSentence {
    final positionMs = state.position.inMilliseconds;
    return MockDataService.sentences.firstWhereOrNull(
      (s) => positionMs >= s.startTimeMs && positionMs < s.endTimeMs,
    );
  }

  /// 获取当前句子索引
  int get currentIndex {
    final sentence = currentSentence;
    if (sentence == null) return -1;
    return MockDataService.sentences.indexOf(sentence);
  }

  /// 播放上一句
  Future<void> previousSentence() async {
    final idx = currentIndex;
    if (idx > 0) {
      final target = MockDataService.sentences[idx - 1];
      await seekTo(target.start);
    } else {
      await seekTo(Duration.zero);
    }
  }

  /// 播放下一句
  Future<void> nextSentence() async {
    final idx = currentIndex;
    // If not in a sentence (e.g. between sentences or at start), find the next one starting after current position
    if (idx == -1) {
      final positionMs = state.position.inMilliseconds;
      final next = MockDataService.sentences
          .firstWhereOrNull((s) => s.startTimeMs > positionMs);
      if (next != null) {
        await seekTo(next.start);
      }
      return;
    }

    if (idx < MockDataService.sentences.length - 1) {
      final target = MockDataService.sentences[idx + 1];
      await seekTo(target.start);
    }
  }
}
