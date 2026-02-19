import 'dart:async'; // Import dart:async
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';
import '../application/local_course_provider.dart';
import '../data/local_course_package_loader.dart';
import '../data/learning_resume_store.dart';
import '../domain/sentence_detail.dart';
import '../../../routing/routes.dart';
import 'playback_settings_screen.dart';
import 'widgets/short_video_bottom_bar.dart';
import 'widgets/short_video_caption.dart';
import 'widgets/short_video_header.dart';
import 'widgets/short_video_video_card.dart';

enum SubtitleMode { bilingual, englishOnly, hidden }

enum ShadowingPhase { idle, listening, recording, advancing }

class SentencePracticeScreen extends ConsumerStatefulWidget {
  final String sentenceId;
  final String? packageRoot;
  final String? courseTitle;

  const SentencePracticeScreen({
    super.key,
    required this.sentenceId,
    this.packageRoot,
    this.courseTitle,
  });

  @override
  ConsumerState<SentencePracticeScreen> createState() =>
      _SentencePracticeScreenState();
}

class _SentencePracticeScreenState extends ConsumerState<SentencePracticeScreen>
    with WidgetsBindingObserver {
  // Data
  List<SentenceDetail> _sentences = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  String? _loadWarning;
  String? _currentPackageRoot;
  String? _currentCourseTitle;
  String? _currentMediaPath;

  SubtitleMode _subtitleMode = SubtitleMode.bilingual;
  late VideoPlayerController _videoController;
  late AudioPlayer _audioPlayer;
  StreamSubscription<Duration>? _audioPositionSub;
  StreamSubscription<PlayerState>? _audioStateSub;
  StreamSubscription<Duration?>? _audioDurationSub;
  Duration _audioPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;
  bool _isAudioMode = false;
  // Controls Visibility State
  bool _isPlaying = false;
  bool _isShadowingMode = false;
  bool _shadowingLocked = false;
  bool _isShadowingBusy = false;
  bool _isShadowingRecording = false;
  ShadowingPhase _shadowingPhase = ShadowingPhase.idle;
  Duration _shadowingRemaining = Duration.zero;
  Timer? _shadowingTicker;
  bool _isSeeking = false;
  double _seekProgress = 0;
  bool _isTogglingPlay = false;
  int _shadowingSessionId = 0;
  final Duration _shadowingExtraDuration = const Duration(milliseconds: 600);
  final AudioRecorder _audioRecorder = AudioRecorder();

  // Video Controls State
  final double _volume = 1.0;
  final double _playbackSpeed = 1.0;
  bool _isFullscreen = false;
  late final PageController _lessonPageController;
  bool _isLessonPaging = false;
  bool _isProgrammaticPageJump = false;
  bool _isSentenceSwitching = false;
  int _seekRequestToken = 0;
  List<int> _lessonStartIndices = const [];
  int _currentLessonPage = 0;
  double _horizontalDragOffset = 0;
  int? _horizontalPreviewIndex;
  int _lastHorizontalDragUpdateUs = 0;
  final Map<String, int> _lessonLastSentenceIndex = {};
  final Map<String, bool> _lessonPlayingState = {};
  final Map<String, Duration> _lessonLastMediaPosition = {};
  final Map<String, Duration> _lessonLastMediaDuration = {};
  final Map<int, VideoPlayerController> _previewControllerCache = {};
  final Set<int> _previewControllerLoading = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lessonPageController = PageController();
    _audioPlayer = AudioPlayer();
    _audioPositionSub = _audioPlayer.positionStream.listen((pos) {
      _audioPosition = pos;
      _syncSentenceWithAudio(pos);
      _cacheCurrentLessonMediaState();
      if (mounted) setState(() {});
    });
    _audioStateSub = _audioPlayer.playerStateStream.listen((state) {
      if (!mounted || !_isAudioMode) return;
      setState(() {
        _isPlaying = state.playing;
        _cacheCurrentLessonPlayingState();
      });
    });
    _audioDurationSub = _audioPlayer.durationStream.listen((duration) {
      _audioDuration = duration ?? Duration.zero;
      _cacheCurrentLessonMediaState();
      if (mounted && _isAudioMode) setState(() {});
    });
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(
          'https://storage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4'),
    );
    _initializeContent();
  }

  Future<void> _initializeContent() async {
    const definedRoot = String.fromEnvironment(
      'COURSE_PACKAGE_DIR',
      defaultValue: '',
    );
    final providerRoot = ref.read(localCourseContextProvider)?.packageRoot;
    final packageRoot = widget.packageRoot ?? providerRoot ?? definedRoot;
    final courseTitleInput =
        widget.courseTitle ?? ref.read(localCourseContextProvider)?.courseTitle;

    final loaded = packageRoot.isNotEmpty
        ? await loadSentencesFromLocalPackage(packageRoot: packageRoot)
        : await ref.read(localCourseSentencesProvider.future);
    final list = loaded.sentences;
    final warning = loaded.warning;
    if (list.isEmpty) {
      if (!mounted) return;
      setState(() {
        _sentences = const [];
        _currentIndex = 0;
        _isPlaying = false;
        _lessonStartIndices = const [];
        _currentLessonPage = 0;
        _isLoading = false;
        _loadWarning = warning;
        _currentPackageRoot = null;
        _currentCourseTitle = null;
      });
      return;
    }

    final index = list.indexWhere((s) => s.id == widget.sentenceId);
    final targetIndex = index != -1 ? index : 0;
    final lessonStarts = _computeLessonStartIndices(list);
    final targetLessonPage =
        _lessonPageForSentenceIndex(lessonStarts, targetIndex);
    final mediaPath = list[targetIndex].mediaPath;
    final mediaType = list[targetIndex].mediaType;
    final courseTitle =
        courseTitleInput ?? list[targetIndex].courseTitle ?? '本地课程';

    await _switchMedia(
      mediaPath,
      mediaType: mediaType,
      seekTo: list[targetIndex].startTime,
    );

    if (!mounted) return;
    final initialPlaying = _playingStateForIndex(targetIndex);
    setState(() {
      _sentences = list;
      _currentIndex = targetIndex;
      _isPlaying = initialPlaying;
      _lessonStartIndices = lessonStarts;
      _currentLessonPage = targetLessonPage;
      _isLoading = false;
      _loadWarning = warning;
      _currentPackageRoot = packageRoot.isEmpty ? null : packageRoot;
      _currentCourseTitle = courseTitle;
    });
    _lessonLastSentenceIndex[_lessonKeyAt(targetIndex)] = targetIndex;
    _cacheCurrentLessonPlayingState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_lessonPageController.hasClients) return;
      _isProgrammaticPageJump = true;
      _lessonPageController.jumpToPage(targetLessonPage);
      scheduleMicrotask(() => _isProgrammaticPageJump = false);
    });
    unawaited(_warmAdjacentLessonPreviews());
    unawaited(_persistLearningResume());
  }

  Future<void> _switchMedia(
    String? mediaPath, {
    String? mediaType,
    Duration? seekTo,
    int? requestToken,
  }) async {
    bool isActiveRequest() =>
        requestToken == null || requestToken == _seekRequestToken;
    final path = (mediaPath ?? '').trim();
    final lowerPath = path.toLowerCase();
    final useAudio = (mediaType ?? '').toLowerCase() == 'audio' ||
        lowerPath.endsWith('.mp3') ||
        lowerPath.endsWith('.aac') ||
        lowerPath.endsWith('.wav') ||
        lowerPath.endsWith('.m4a');

    if (path.isEmpty) {
      if (!isActiveRequest()) return;
      await _initFallbackVideo(seekTo: seekTo);
      return;
    }

    if (_currentMediaPath == path) {
      if (!isActiveRequest()) return;
      if (_isAudioMode) {
        if (seekTo != null) {
          await _audioPlayer.seek(seekTo);
        }
        return;
      }
      if (_videoController.value.isInitialized) {
        if (seekTo != null) {
          await _videoController.seekTo(seekTo);
        }
        return;
      }
    }

    if (useAudio) {
      try {
        if (!isActiveRequest()) return;
        if (_videoController.value.isInitialized) {
          await _videoController.pause();
        }
        await _audioPlayer.setFilePath(path);
        _audioDuration = _audioPlayer.duration ?? Duration.zero;
        await _audioPlayer.setVolume(_volume);
        await _audioPlayer.setSpeed(_playbackSpeed);
        if (seekTo != null) {
          await _audioPlayer.seek(seekTo);
        }
        if (!isActiveRequest()) return;
        if (_isPlaying) {
          await _audioPlayer.play();
        }
        if (!isActiveRequest()) return;
        if (mounted) {
          setState(() {
            _isAudioMode = true;
            _currentMediaPath = path;
          });
        } else {
          _isAudioMode = true;
          _currentMediaPath = path;
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _loadWarning = '本地音频加载失败，已保留当前播放器。';
          });
        }
      }
      return;
    }

    final old = _videoController;
    old.removeListener(_syncSentenceWithVideo);
    void restoreOldListener() {
      old.addListener(_syncSentenceWithVideo);
    }

    try {
      final next = VideoPlayerController.file(File(path));
      await next.initialize();
      if (!isActiveRequest()) {
        restoreOldListener();
        await next.dispose();
        return;
      }
      await next.setLooping(true);
      await next.setVolume(_volume);
      await next.setPlaybackSpeed(_playbackSpeed);
      next.addListener(_syncSentenceWithVideo);
      if (seekTo != null) {
        await next.seekTo(seekTo);
      }
      if (!isActiveRequest()) {
        restoreOldListener();
        next.removeListener(_syncSentenceWithVideo);
        await next.dispose();
        return;
      }
      if (_isPlaying) {
        await next.play();
      }
      if (!isActiveRequest()) {
        restoreOldListener();
        next.removeListener(_syncSentenceWithVideo);
        await next.dispose();
        return;
      }

      if (mounted) {
        setState(() {
          _isAudioMode = false;
          _videoController = next;
          _currentMediaPath = path;
        });
      } else {
        _isAudioMode = false;
        _videoController = next;
        _currentMediaPath = path;
      }
      await old.dispose();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadWarning = '本地媒体加载失败，已保留当前播放器。';
        });
      }
    }
  }

  Future<void> _initFallbackVideo({Duration? seekTo}) async {
    if (_videoController.value.isInitialized) return;
    try {
      await _videoController.initialize();
      await _videoController.setLooping(true);
      await _videoController.setVolume(_volume);
      await _videoController.setPlaybackSpeed(_playbackSpeed);
      _videoController.addListener(_syncSentenceWithVideo);
      if (seekTo != null) {
        await _videoController.seekTo(seekTo);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadWarning = '默认播放器初始化失败。';
        });
      }
    }
  }

  // Waveform preparation removed
  // Future<void> _prepareWaveform() async { ... }

  void _syncSentenceWithVideo() {
    if (_isSentenceSwitching) return;
    if (_isAudioMode) return;
    if (!_videoController.value.isInitialized) return;

    final currentPos = _videoController.value.position;
    final currentPlaying = _videoController.value.isPlaying;
    if (_isPlaying != currentPlaying && mounted) {
      setState(() {
        _isPlaying = currentPlaying;
        _cacheCurrentLessonPlayingState();
      });
    } else {
      _cacheCurrentLessonPlayingState();
    }
    _cacheCurrentLessonMediaState();
    // debugPrint("Syncing: $currentPos"); // Uncomment for verbose logs

    if (_isShadowingMode &&
        _currentIndex >= 0 &&
        _currentIndex < _sentences.length) {
      final current = _sentences[_currentIndex];
      if (_isPlaying &&
          !_isSeeking &&
          currentPos >= current.endTime &&
          !_isShadowingBusy) {
        unawaited(_runShadowingStep());
      }
      return;
    }

    // Only sync inside current lesson to avoid cross-lesson timestamp collisions.
    final bounds = _lessonBoundsForIndex(_currentIndex);
    for (int i = bounds.start; i <= bounds.end; i++) {
      final s = _sentences[i];
      if (currentPos >= s.startTime && currentPos < s.endTime) {
        if (_currentIndex != i) {
          debugPrint("Scrub sync: Jumped to sentence $i at $currentPos");
          setState(() {
            _currentIndex = i;
          });
          _lessonLastSentenceIndex[_lessonKeyAt(i)] = i;
          unawaited(_persistLearningResume());
        }
        break;
      }
    }
  }

  void _syncSentenceWithAudio(Duration currentPos) {
    if (_isSentenceSwitching) return;
    if (!_isAudioMode) return;
    if (_isShadowingMode &&
        _currentIndex >= 0 &&
        _currentIndex < _sentences.length) {
      final current = _sentences[_currentIndex];
      if (_isPlaying &&
          !_isSeeking &&
          currentPos >= current.endTime &&
          !_isShadowingBusy) {
        unawaited(_runShadowingStep());
      }
      return;
    }
    final bounds = _lessonBoundsForIndex(_currentIndex);
    for (int i = bounds.start; i <= bounds.end; i++) {
      final s = _sentences[i];
      if (currentPos >= s.startTime && currentPos < s.endTime) {
        if (_currentIndex != i && mounted) {
          setState(() {
            _currentIndex = i;
          });
          _lessonLastSentenceIndex[_lessonKeyAt(i)] = i;
          unawaited(_persistLearningResume());
        }
        break;
      }
    }
  }

  void _cacheCurrentLessonMediaState() {
    if (_isSentenceSwitching) return;
    if (_sentences.isEmpty) return;
    final safeIndex = _currentIndex.clamp(0, _sentences.length - 1);
    final key = _lessonKeyAt(safeIndex);
    final position = _isAudioMode
        ? _audioPosition
        : (_videoController.value.isInitialized
            ? _videoController.value.position
            : Duration.zero);
    final duration = _isAudioMode
        ? _audioDuration
        : (_videoController.value.isInitialized
            ? _videoController.value.duration
            : Duration.zero);
    if (position >= Duration.zero) {
      _lessonLastMediaPosition[key] = position;
    }
    if (duration > Duration.zero) {
      _lessonLastMediaDuration[key] = duration;
    }
  }

  void _cacheMediaStateForLessonIndex(
    int index, {
    required Duration position,
    required Duration duration,
  }) {
    if (_sentences.isEmpty) return;
    if (index < 0 || index >= _sentences.length) return;
    final key = _lessonKeyAt(index);
    if (position >= Duration.zero) {
      _lessonLastMediaPosition[key] = position;
    }
    if (duration > Duration.zero) {
      _lessonLastMediaDuration[key] = duration;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clearPreviewControllerCache();
    _lessonPageController.dispose();
    _exitFullscreenMode();
    // _stopWaveformSync(); // Waveform removed
    if (_videoController.value.isInitialized) {
      _videoController.removeListener(_syncSentenceWithVideo);
    }
    _videoController.dispose();
    _audioPositionSub?.cancel();
    _audioStateSub?.cancel();
    _audioDurationSub?.cancel();
    _shadowingTicker?.cancel();
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    // _waveformController?.dispose(); // Waveform removed
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_persistLearningResume());
    }
  }

  void _clearPreviewControllerCache() {
    for (final controller in _previewControllerCache.values) {
      controller.dispose();
    }
    _previewControllerCache.clear();
    _previewControllerLoading.clear();
  }

  void _onUserInteraction() {
    // Reserved for future interaction analytics / hints.
  }

  void _cycleSubtitleMode() {
    setState(() {
      _subtitleMode = switch (_subtitleMode) {
        SubtitleMode.bilingual => SubtitleMode.englishOnly,
        SubtitleMode.englishOnly => SubtitleMode.hidden,
        SubtitleMode.hidden => SubtitleMode.bilingual,
      };
    });
    _onUserInteraction();
  }

  void _toggleShadowingMode() {
    if (_isShadowingMode) {
      unawaited(_exitShadowingMode());
      return;
    }
    setState(() {
      _isShadowingMode = true;
      _shadowingLocked = true;
      _isShadowingBusy = false;
      _isShadowingRecording = false;
      _shadowingRemaining = Duration.zero;
      _shadowingPhase = ShadowingPhase.listening;
    });
    if (!_isPlaying) {
      unawaited(_playCurrentMedia());
    }
    _onUserInteraction();
  }

  Future<void> _exitShadowingMode() async {
    await _cancelShadowingStep(keepMode: false);
    _clearHorizontalPreview();
    if (mounted) {
      setState(() {
        _isShadowingMode = false;
        _shadowingLocked = false;
        _shadowingPhase = ShadowingPhase.idle;
        _shadowingRemaining = Duration.zero;
        _isSeeking = false;
        _seekProgress = 0;
      });
    } else {
      _isShadowingMode = false;
      _shadowingLocked = false;
      _shadowingPhase = ShadowingPhase.idle;
      _shadowingRemaining = Duration.zero;
      _isSeeking = false;
      _seekProgress = 0;
    }
  }

  void _toggleShadowingLock() {
    if (_shadowingLocked) {
      unawaited(_exitShadowingMode());
      return;
    }
    if (!_isShadowingMode) return;
    setState(() {
      _shadowingLocked = true;
    });
  }

  void _startShadowingCountdown(Duration total) {
    _shadowingTicker?.cancel();
    _shadowingRemaining = total;
    _shadowingTicker =
        Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted) return;
      final next = _shadowingRemaining - const Duration(milliseconds: 200);
      setState(() {
        _shadowingRemaining = next.isNegative ? Duration.zero : next;
      });
      if (_shadowingRemaining <= Duration.zero) {
        timer.cancel();
      }
    });
  }

  Future<void> _runShadowingStep() async {
    if (!_isShadowingMode || _isShadowingBusy) return;
    if (_currentIndex < 0 || _currentIndex >= _sentences.length) return;
    final sessionId = _shadowingSessionId;
    final sentence = _sentences[_currentIndex];
    final sentenceDuration = sentence.endTime > sentence.startTime
        ? sentence.endTime - sentence.startTime
        : const Duration(seconds: 1);
    final recordWindow = sentenceDuration + _shadowingExtraDuration;
    final shouldContinue = _isPlaying;

    setState(() {
      _isShadowingBusy = true;
      _shadowingPhase = ShadowingPhase.recording;
    });

    try {
      await _pauseCurrentMedia();
      if (!_isShadowingMode || sessionId != _shadowingSessionId) return;

      final canRecord = await _audioRecorder.hasPermission();
      if (canRecord) {
        try {
          final recordPath = await _nextShadowingRecordPath(sentence.id);
          await _audioRecorder.start(
            const RecordConfig(
              encoder: AudioEncoder.aacLc,
              sampleRate: 16000,
              bitRate: 64000,
            ),
            path: recordPath,
          );
          if (mounted) {
            setState(() {
              _isShadowingRecording = true;
            });
          } else {
            _isShadowingRecording = true;
          }
        } catch (_) {
          if (mounted) {
            setState(() {
              _loadWarning = '录音启动失败，已跳过本句录音。';
            });
          }
        }
      } else if (mounted) {
        setState(() {
          _loadWarning = '录音权限未开启，跟读模式将跳过录音。';
        });
      }

      _startShadowingCountdown(recordWindow);
      await Future.delayed(recordWindow);
      _shadowingTicker?.cancel();
      await _stopShadowingRecordingIfNeeded();

      if (!_isShadowingMode || sessionId != _shadowingSessionId) return;
      if (mounted) {
        setState(() {
          _shadowingPhase = ShadowingPhase.advancing;
        });
      } else {
        _shadowingPhase = ShadowingPhase.advancing;
      }

      final nextIndex = _currentIndex + 1;
      if (nextIndex >= _sentences.length) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _cacheCurrentLessonPlayingState();
            _shadowingPhase = ShadowingPhase.listening;
          });
        } else {
          _isPlaying = false;
          _cacheCurrentLessonPlayingState();
          _shadowingPhase = ShadowingPhase.listening;
        }
        return;
      }

      if (shouldContinue) {
        if (mounted) {
          setState(() {
            _isPlaying = true;
            _cacheCurrentLessonPlayingState();
          });
        } else {
          _isPlaying = true;
          _cacheCurrentLessonPlayingState();
        }
      }
      await _seekToSentence(nextIndex);
      if (shouldContinue) {
        await _playCurrentMedia();
      }
    } finally {
      _clearHorizontalPreview();
      if (mounted) {
        setState(() {
          _isShadowingBusy = false;
          _isShadowingRecording = false;
          _shadowingRemaining = Duration.zero;
          _isSeeking = false;
          _seekProgress = 0;
          _shadowingPhase =
              _isShadowingMode ? ShadowingPhase.listening : ShadowingPhase.idle;
        });
      } else {
        _isShadowingBusy = false;
        _isShadowingRecording = false;
        _shadowingRemaining = Duration.zero;
        _isSeeking = false;
        _seekProgress = 0;
        _shadowingPhase =
            _isShadowingMode ? ShadowingPhase.listening : ShadowingPhase.idle;
      }
    }
  }

  Future<void> _pauseCurrentMedia() async {
    if (_isAudioMode) {
      await _audioPlayer.pause();
    } else if (_videoController.value.isInitialized) {
      await _videoController.pause();
    }
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _cacheCurrentLessonPlayingState();
      });
    } else {
      _isPlaying = false;
      _cacheCurrentLessonPlayingState();
    }
  }

  Future<void> _playCurrentMedia() async {
    if (_isAudioMode) {
      await _audioPlayer.play();
    } else if (_videoController.value.isInitialized) {
      await _videoController.play();
    }
    if (mounted) {
      setState(() {
        _isPlaying = true;
        _cacheCurrentLessonPlayingState();
      });
    } else {
      _isPlaying = true;
      _cacheCurrentLessonPlayingState();
    }
  }

  Future<void> _stopShadowingRecordingIfNeeded() async {
    if (!_isShadowingRecording) return;
    try {
      await _audioRecorder.stop();
    } catch (_) {
      // Ignore stop failures to keep pipeline flowing.
    }
    if (mounted) {
      setState(() {
        _isShadowingRecording = false;
      });
    } else {
      _isShadowingRecording = false;
    }
  }

  Future<void> _cancelShadowingStep({required bool keepMode}) async {
    _shadowingSessionId++;
    _shadowingTicker?.cancel();
    await _stopShadowingRecordingIfNeeded();
    if (mounted) {
      setState(() {
        _isShadowingBusy = false;
        _isShadowingRecording = false;
        _shadowingRemaining = Duration.zero;
        _shadowingPhase = keepMode && _isShadowingMode
            ? ShadowingPhase.listening
            : ShadowingPhase.idle;
      });
    } else {
      _isShadowingBusy = false;
      _isShadowingRecording = false;
      _shadowingRemaining = Duration.zero;
      _shadowingPhase = keepMode && _isShadowingMode
          ? ShadowingPhase.listening
          : ShadowingPhase.idle;
    }
  }

  Future<String> _nextShadowingRecordPath(String sentenceId) async {
    final baseDir = await getTemporaryDirectory();
    final folder = Directory('${baseDir.path}/shadowing_records');
    if (!folder.existsSync()) {
      folder.createSync(recursive: true);
    }
    final ts = DateTime.now().millisecondsSinceEpoch;
    final safeId = sentenceId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return '${folder.path}/${safeId}_$ts.m4a';
  }

  void _togglePlay() async {
    if (_isTogglingPlay) return;
    if (_isShadowingMode && _shadowingLocked) {
      return;
    }
    if (_isShadowingMode && _isShadowingBusy) {
      await _cancelShadowingStep(keepMode: true);
    }
    final shouldPlay = !_isPlaying;
    setState(() {
      _isPlaying = shouldPlay;
      _cacheCurrentLessonPlayingState();
    });
    _isTogglingPlay = true;
    try {
      if (_isAudioMode) {
        if (shouldPlay) {
          await _audioPlayer.play();
        } else {
          await _audioPlayer.pause();
        }
      } else {
        if (!_videoController.value.isInitialized) return;
        if (shouldPlay) {
          await _videoController.play();
        } else {
          await _videoController.pause();
        }
      }
      final actualPlaying = _isAudioMode
          ? _audioPlayer.playing
          : (_videoController.value.isInitialized
              ? _videoController.value.isPlaying
              : false);
      if (!mounted) {
        _isPlaying = actualPlaying;
        _cacheCurrentLessonPlayingState();
        return;
      }
      setState(() {
        _isPlaying = actualPlaying;
        _cacheCurrentLessonPlayingState();
      });
    } finally {
      _isTogglingPlay = false;
    }
  }

  String _shadowingStatusText() {
    if (!_isShadowingMode) return '';
    if (_shadowingPhase == ShadowingPhase.recording) {
      final seconds =
          (_shadowingRemaining.inMilliseconds / 1000).toStringAsFixed(1);
      return '跟读中 ${seconds}s';
    }
    if (_shadowingPhase == ShadowingPhase.advancing) {
      return '切换下一句...';
    }
    return '跟读模式（已锁定）';
  }

  Widget _buildShadowingStatusHint() {
    if (!_isShadowingMode) return const SizedBox.shrink();
    final color = _shadowingPhase == ShadowingPhase.recording
        ? Colors.redAccent
        : const Color(0xFFFF9F29);
    final statusIcon = _shadowingPhase == ShadowingPhase.recording
        ? TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.78, end: 1.05),
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeInOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: _safeOpacity(value),
                child: Transform.scale(scale: value, child: child),
              );
            },
            child: Icon(
              Icons.mic_rounded,
              size: 14,
              color: color.withValues(alpha: 0.92),
            ),
          )
        : TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.75, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: _safeOpacity(value),
                child: Transform.scale(scale: value, child: child),
              );
            },
            child: Icon(
              Icons.graphic_eq_rounded,
              size: 13,
              color: color.withValues(alpha: 0.88),
            ),
          );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        statusIcon,
        const SizedBox(width: 6),
        Text(
          _shadowingStatusText(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.right,
        ),
        const SizedBox(width: 6),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleShadowingLock,
          child: Icon(
            _shadowingLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
            size: 16,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }

  Future<void> _seekByProgress(double progress) async {
    final clamped = progress.clamp(0.0, 1.0);
    final total = _isAudioMode
        ? _audioDuration
        : (_videoController.value.isInitialized
            ? _videoController.value.duration
            : Duration.zero);
    if (total <= Duration.zero) return;
    final target = Duration(
      milliseconds: (total.inMilliseconds * clamped).round(),
    );
    if (_isAudioMode) {
      await _audioPlayer.seek(target);
    } else if (_videoController.value.isInitialized) {
      await _videoController.seekTo(target);
    }
  }

  void _onSeekStart(double progress) {
    if (_isShadowingMode) return;
    if (_isShadowingBusy) {
      unawaited(_cancelShadowingStep(keepMode: true));
    }
    setState(() {
      _isSeeking = true;
      _seekProgress = progress.clamp(0.0, 1.0);
    });
  }

  void _onSeekUpdate(double progress) {
    if (_isShadowingMode) return;
    if (!_isSeeking) return;
    setState(() {
      _seekProgress = progress.clamp(0.0, 1.0);
    });
  }

  Future<void> _onSeekEnd(double _) async {
    if (_isShadowingMode) return;
    if (!_isSeeking) return;
    final target = _seekProgress;
    setState(() {
      _isSeeking = false;
    });
    await _seekByProgress(target);
  }

  Future<void> _onSeekTap(double progress) async {
    if (_isShadowingMode) return;
    setState(() {
      _isSeeking = false;
    });
    await _seekByProgress(progress);
  }

  // Waveform sync removed
  // Timer? _waveformSyncTimer;
  // void _startWaveformSync() { ... }

  // void _stopWaveformSync() { ... }

  void _handleNext() {
    if (_isShadowingMode) return;
    final nextIndex = _currentIndex + 1;
    if (nextIndex < _sentences.length) {
      _seekToSentence(nextIndex);
    }
    _onUserInteraction();
  }

  void _handlePrevious() {
    if (_isShadowingMode) return;
    final prevIndex = _currentIndex - 1;
    if (prevIndex >= 0) {
      _seekToSentence(prevIndex);
    }
    _onUserInteraction();
  }

  void _clearHorizontalPreview() {
    if (!mounted) return;
    setState(() {
      _horizontalDragOffset = 0;
      _horizontalPreviewIndex = null;
    });
  }

  void _updateHorizontalPreview() {
    final offset = _horizontalDragOffset;
    if (offset.abs() < 8) {
      if (_horizontalPreviewIndex != null) {
        setState(() {
          _horizontalPreviewIndex = null;
        });
      }
      return;
    }
    final preview = offset < 0 ? _currentIndex + 1 : _currentIndex - 1;
    if (preview < 0 || preview >= _sentences.length) {
      if (_horizontalPreviewIndex != null) {
        setState(() {
          _horizontalPreviewIndex = null;
        });
      }
      return;
    }
    if (_horizontalPreviewIndex == preview) return;
    setState(() {
      _horizontalPreviewIndex = preview;
    });
  }

  void _onGlobalHorizontalDragUpdate(DragUpdateDetails details) {
    if (_isShadowingMode) return;
    final now = DateTime.now().microsecondsSinceEpoch;
    if (now - _lastHorizontalDragUpdateUs < 12000) {
      return;
    }
    _lastHorizontalDragUpdateUs = now;
    final width = MediaQuery.of(context).size.width;
    final next = (_horizontalDragOffset + details.delta.dx)
        .clamp(-width * 0.85, width * 0.85);
    setState(() {
      _horizontalDragOffset = next;
    });
    _updateHorizontalPreview();
  }

  void _onGlobalHorizontalDragEnd(DragEndDetails details) {
    if (_isShadowingMode) return;
    final width = MediaQuery.of(context).size.width;
    final velocity = details.velocity.pixelsPerSecond.dx;
    final threshold = width * 0.22;
    final shouldNext = _horizontalDragOffset < -threshold || velocity < -450;
    final shouldPrevious = _horizontalDragOffset > threshold || velocity > 450;
    if (shouldNext) {
      _clearHorizontalPreview();
      _handleNext();
      return;
    }
    if (shouldPrevious) {
      _clearHorizontalPreview();
      _handlePrevious();
      return;
    }
    _clearHorizontalPreview();
  }

  List<int> _computeLessonStartIndices(List<SentenceDetail> sentences) {
    if (sentences.isEmpty) return const [0];
    final starts = <int>[0];
    for (int i = 1; i < sentences.length; i++) {
      final previous = sentences[i - 1];
      final current = sentences[i];
      final previousKey = _lessonKeyFromSentence(previous);
      final currentKey = _lessonKeyFromSentence(current);
      if (currentKey != previousKey) {
        starts.add(i);
      }
    }
    return starts;
  }

  int _lessonPageForSentenceIndex(List<int> starts, int sentenceIndex) {
    if (starts.isEmpty) return 0;
    for (int i = starts.length - 1; i >= 0; i--) {
      if (sentenceIndex >= starts[i]) return i;
    }
    return 0;
  }

  void _syncLessonPageWithCurrentSentence() {
    if (_lessonStartIndices.isEmpty) return;
    final targetPage =
        _lessonPageForSentenceIndex(_lessonStartIndices, _currentIndex);
    if (targetPage == _currentLessonPage) return;
    setState(() {
      _currentLessonPage = targetPage;
    });
    if (!_lessonPageController.hasClients) return;
    _isProgrammaticPageJump = true;
    _lessonPageController.jumpToPage(targetPage);
    scheduleMicrotask(() => _isProgrammaticPageJump = false);
  }

  String _lessonKeyFromSentence(SentenceDetail sentence) {
    final packageRoot = (sentence.packageRoot ?? '').trim();
    final courseTitle = (sentence.courseTitle ?? '').trim();
    final scope = packageRoot.isNotEmpty
        ? 'pkg:$packageRoot'
        : (courseTitle.isNotEmpty ? 'course:$courseTitle' : 'global');
    final lessonId = (sentence.lessonId ?? '').trim();
    if (lessonId.isNotEmpty) return '$scope|lesson:$lessonId';
    final lessonTitle = (sentence.lessonTitle ?? '').trim();
    if (lessonTitle.isNotEmpty) return '$scope|title:$lessonTitle';
    final mediaPath = (sentence.mediaPath ?? '').trim();
    if (mediaPath.isNotEmpty) return '$scope|media:$mediaPath';
    return '$scope|default';
  }

  String _lessonKeyAt(int index) {
    return _lessonKeyFromSentence(_sentences[index]);
  }

  bool _playingStateForIndex(int index) {
    if (_sentences.isEmpty) return false;
    if (index < 0 || index >= _sentences.length) return false;
    return _lessonPlayingState[_lessonKeyAt(index)] ?? false;
  }

  void _cacheCurrentLessonPlayingState() {
    if (_sentences.isEmpty) return;
    if (_currentIndex < 0 || _currentIndex >= _sentences.length) return;
    final key = _lessonKeyAt(_currentIndex);
    _lessonPlayingState[key] = _isPlaying;
  }

  ({int start, int end}) _lessonBoundsForIndex(int index) {
    if (_sentences.isEmpty) return (start: 0, end: 0);
    final safeIndex = index.clamp(0, _sentences.length - 1);
    final key = _lessonKeyAt(safeIndex);
    var start = safeIndex;
    while (start - 1 >= 0 && _lessonKeyAt(start - 1) == key) {
      start--;
    }
    var end = safeIndex;
    while (end + 1 < _sentences.length && _lessonKeyAt(end + 1) == key) {
      end++;
    }
    return (start: start, end: end);
  }

  Future<VideoPlayerController?> _ensurePreviewControllerForIndex(
    int index,
  ) async {
    final cached = _previewControllerCache[index];
    if (cached != null) return cached;
    if (_previewControllerLoading.contains(index)) return null;

    final sentence = _sentences[index];
    final path = (sentence.mediaPath ?? '').trim();
    final mediaType = (sentence.mediaType ?? '').toLowerCase();
    final useAudio = mediaType == 'audio' ||
        path.toLowerCase().endsWith('.mp3') ||
        path.toLowerCase().endsWith('.aac') ||
        path.toLowerCase().endsWith('.wav') ||
        path.toLowerCase().endsWith('.m4a');
    if (useAudio || path.isEmpty) return null;

    _previewControllerLoading.add(index);
    VideoPlayerController? created;
    try {
      created = VideoPlayerController.file(File(path));
      await created.initialize();
      await created.setVolume(_volume);
      await created.setPlaybackSpeed(_playbackSpeed);
      await created.seekTo(sentence.startTime);
      if (!mounted) {
        await created.dispose();
        return null;
      }
      final existing = _previewControllerCache[index];
      if (existing != null) {
        await created.dispose();
        return existing;
      }
      _previewControllerCache[index] = created;
      return created;
    } catch (_) {
      await created?.dispose();
      return null;
    } finally {
      _previewControllerLoading.remove(index);
    }
  }

  Future<void> _warmAdjacentLessonPreviews() async {
    if (_sentences.isEmpty || _lessonStartIndices.isEmpty) return;
    if (_currentLessonPage < 0 ||
        _currentLessonPage >= _lessonStartIndices.length) {
      return;
    }
    final prevPage = _currentLessonPage - 1;
    final nextPage = _currentLessonPage + 1;
    final keep = <int>{
      _targetSentenceIndexForLessonPage(_currentLessonPage),
      if (prevPage >= 0) _targetSentenceIndexForLessonPage(prevPage),
      if (nextPage < _lessonStartIndices.length)
        _targetSentenceIndexForLessonPage(nextPage),
    };
    for (final index in keep) {
      await _ensurePreviewControllerForIndex(index);
    }
    final stale = _previewControllerCache.keys
        .where((index) => !keep.contains(index))
        .toList();
    for (final index in stale) {
      _previewControllerCache.remove(index)?.dispose();
    }
  }

  ({int indexInLesson, int totalInLesson}) _lessonProgressForIndex(int index) {
    if (_sentences.isEmpty) {
      return (indexInLesson: 1, totalInLesson: 1);
    }
    final currentKey = _lessonKeyAt(index);
    int start = index;
    while (start - 1 >= 0 && _lessonKeyAt(start - 1) == currentKey) {
      start--;
    }
    int end = index;
    while (end + 1 < _sentences.length && _lessonKeyAt(end + 1) == currentKey) {
      end++;
    }
    return (
      indexInLesson: (index - start) + 1,
      totalInLesson: (end - start) + 1,
    );
  }

  ({int indexInLesson, int totalInLesson}) _headerProgressForCurrentLesson() {
    if (_sentences.isEmpty || _lessonStartIndices.isEmpty) {
      return _lessonProgressForIndex(_currentIndex);
    }
    final safePage =
        _currentLessonPage.clamp(0, _lessonStartIndices.length - 1);
    final lessonStart = _lessonStartIndices[safePage];
    final lessonKey = _lessonKeyAt(lessonStart);
    final remembered = _lessonLastSentenceIndex[lessonKey];
    final displayIndex = (remembered != null &&
            remembered >= 0 &&
            remembered < _sentences.length &&
            _lessonKeyAt(remembered) == lessonKey)
        ? remembered
        : lessonStart;
    return _lessonProgressForIndex(displayIndex);
  }

  Future<void> _onLessonPageChanged(int page) async {
    if (_lessonStartIndices.isEmpty ||
        page < 0 ||
        page >= _lessonStartIndices.length) {
      return;
    }
    setState(() {
      _currentLessonPage = page;
    });
    if (_isProgrammaticPageJump) return;
    final targetSentenceIndex = _targetSentenceIndexForLessonPage(page);
    if (targetSentenceIndex == _currentIndex) {
      _clearHorizontalPreview();
      unawaited(_warmAdjacentLessonPreviews());
      return;
    }
    _clearHorizontalPreview();
    await _seekToSentence(targetSentenceIndex);
  }

  int _targetSentenceIndexForLessonPage(int page) {
    final startIndex = _lessonStartIndices[page];
    final key = _lessonKeyAt(startIndex);
    final remembered = _lessonLastSentenceIndex[key];
    if (remembered == null) return startIndex;
    if (remembered < 0 || remembered >= _sentences.length) return startIndex;
    if (_lessonKeyAt(remembered) != key) return startIndex;
    return remembered;
  }

  VideoPlayerController? _videoControllerForPage(int page, int sentenceIndex) {
    if (page == _currentLessonPage) return _videoController;
    return _previewControllerCache[sentenceIndex];
  }

  Widget _buildCaptionContent(
    SentenceDetail sentence, {
    required bool compactLayout,
    required bool blurNonVideo,
  }) {
    return SingleChildScrollView(
      child: _blurWrapper(
        blurNonVideo,
        ShortVideoCaption(
          text: sentence.text,
          phonetic: sentence.phonetic,
          translation: sentence.translation,
          showEnglish: _subtitleMode != SubtitleMode.hidden,
          showChinese: _subtitleMode == SubtitleMode.bilingual,
          compact: compactLayout,
        ),
      ),
    );
  }

  Widget _dragBlurWrapper(bool blur, Widget child) {
    if (!blur) return child;
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 0.8, sigmaY: 0.8),
      child: child,
    );
  }

  Future<void> _seekToSentence(int index) async {
    if (index < 0 || index >= _sentences.length) return;
    final requestToken = ++_seekRequestToken;
    final s = _sentences[index];
    setState(() {
      _horizontalDragOffset = 0;
      _horizontalPreviewIndex = null;
      _isSentenceSwitching = true;
      _currentIndex = index;
      _isPlaying = _playingStateForIndex(index);
    });

    try {
      await _switchMedia(
        s.mediaPath,
        mediaType: s.mediaType,
        seekTo: s.startTime,
        requestToken: requestToken,
      );
      if (!mounted || requestToken != _seekRequestToken) return;

      if (_isAudioMode) {
        await _audioPlayer.seek(s.startTime);
      } else if (_videoController.value.isInitialized) {
        await _videoController.seekTo(s.startTime);
      }

      if (!mounted || requestToken != _seekRequestToken) return;
      final actualPlaying = _isAudioMode
          ? _audioPlayer.playing
          : (_videoController.value.isInitialized
              ? _videoController.value.isPlaying
              : false);
      setState(() {
        _isPlaying = actualPlaying;
      });
      final activeDuration = _isAudioMode
          ? _audioDuration
          : (_videoController.value.isInitialized
              ? _videoController.value.duration
              : Duration.zero);
      _cacheMediaStateForLessonIndex(
        index,
        position: s.startTime,
        duration: activeDuration,
      );
      _lessonLastSentenceIndex[_lessonKeyAt(index)] = index;
      _cacheCurrentLessonPlayingState();
      _syncLessonPageWithCurrentSentence();
      await _persistLearningResume();
      unawaited(_warmAdjacentLessonPreviews());
      // _audioPlayer.seek(s.startTime); // Not using separate audio
      // Waveform removed
    } finally {
      if (mounted &&
          requestToken == _seekRequestToken &&
          _isSentenceSwitching) {
        setState(() {
          _isSentenceSwitching = false;
        });
      }
    }
  }

  Future<void> _persistLearningResume() async {
    if (_sentences.isEmpty ||
        _currentIndex < 0 ||
        _currentIndex >= _sentences.length) {
      return;
    }
    final sentence = _sentences[_currentIndex];
    final packageRoot = (_currentPackageRoot ?? sentence.packageRoot)?.trim();
    if (packageRoot == null || packageRoot.isEmpty) return;
    final title = _currentCourseTitle ?? sentence.courseTitle ?? '本地课程';
    await LearningResumeStore.save(
      LearningResume(
        packageRoot: packageRoot,
        courseTitle: title,
        sentenceId: sentence.id,
        lessonId: sentence.lessonId,
      ),
    );
  }

  // Fullscreen Control
  void _toggleFullscreen() {
    if (_isFullscreen) {
      _exitFullscreenMode();
    } else {
      _enterFullscreenMode();
    }
    setState(() => _isFullscreen = !_isFullscreen);
    _onUserInteraction();
  }

  void _enterFullscreenMode() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _exitFullscreenMode() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  IconData _subtitleIcon() {
    return switch (_subtitleMode) {
      SubtitleMode.bilingual => Icons.subtitles_rounded,
      SubtitleMode.englishOnly => Icons.closed_caption_outlined,
      SubtitleMode.hidden => Icons.subtitles_off_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_sentences.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('暂无可用句子数据')),
      );
    }

    const accentColor = Color(0xFFFF9F29);

    final rawMediaCurrent = _isAudioMode
        ? _audioPosition
        : (_videoController.value.isInitialized
            ? _videoController.value.position
            : Duration.zero);
    final rawMediaTotal = _isAudioMode
        ? _audioDuration
        : (_videoController.value.isInitialized
            ? _videoController.value.duration
            : Duration.zero);
    final currentLessonKey = _sentences.isEmpty || _lessonStartIndices.isEmpty
        ? null
        : _lessonKeyAt(
            _targetSentenceIndexForLessonPage(
              _currentLessonPage.clamp(0, _lessonStartIndices.length - 1),
            ),
          );
    final cachedCurrent = currentLessonKey == null
        ? null
        : _lessonLastMediaPosition[currentLessonKey];
    final cachedTotal = currentLessonKey == null
        ? null
        : _lessonLastMediaDuration[currentLessonKey];
    var mediaCurrent = rawMediaCurrent;
    var mediaTotal = rawMediaTotal;
    if (_isSentenceSwitching || mediaTotal <= Duration.zero) {
      if (cachedTotal != null && cachedTotal > Duration.zero) {
        mediaTotal = cachedTotal;
      }
      if (cachedCurrent != null && cachedCurrent >= Duration.zero) {
        mediaCurrent = cachedCurrent;
      }
    }
    if (mediaTotal > Duration.zero && mediaCurrent > mediaTotal) {
      mediaCurrent = mediaTotal;
    }
    final mediaProgress = mediaTotal.inMilliseconds <= 0
        ? 0.0
        : (mediaCurrent.inMilliseconds / mediaTotal.inMilliseconds)
            .clamp(0.0, 1.0);
    final height = MediaQuery.of(context).size.height;
    final compactLayout = height < 780;
    final videoFlex = compactLayout ? 7 : 8;
    final captionTopGap = compactLayout ? 10.0 : 16.0;
    final lessonProgress = _headerProgressForCurrentLesson();

    return Scaffold(
      extendBody: false,
      body: Container(
        color: Colors.black,
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: ShortVideoHeader(
                currentIndex: lessonProgress.indexInLesson - 1,
                total: lessonProgress.totalInLesson,
                onOpenDownloadCenter: _openDownloadCenter,
              ),
            ),
            Expanded(
              child: ClipRect(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.axis != Axis.vertical) {
                      return false;
                    }
                    if (notification is ScrollStartNotification &&
                        !_isLessonPaging) {
                      setState(() {
                        _isLessonPaging = true;
                      });
                      unawaited(_warmAdjacentLessonPreviews());
                    }
                    if (notification is ScrollEndNotification &&
                        _isLessonPaging) {
                      setState(() {
                        _isLessonPaging = false;
                      });
                    }
                    return false;
                  },
                  child: PageView.builder(
                    controller: _lessonPageController,
                    scrollDirection: Axis.vertical,
                    physics: _isShadowingMode
                        ? const NeverScrollableScrollPhysics()
                        : const PageScrollPhysics(),
                    itemCount: _lessonStartIndices.length,
                    onPageChanged: (page) {
                      unawaited(_onLessonPageChanged(page));
                    },
                    itemBuilder: (context, page) {
                      final isCurrentPage = page == _currentLessonPage;
                      final sentenceIndex = isCurrentPage
                          ? _currentIndex
                          : _targetSentenceIndexForLessonPage(page);
                      final sentence = _sentences[sentenceIndex];
                      final pageIsPlaying = isCurrentPage
                          ? _isPlaying
                          : _playingStateForIndex(sentenceIndex);
                      final expectedMediaPath =
                          (sentence.mediaPath ?? '').trim();
                      final currentMediaPath = (_currentMediaPath ?? '').trim();
                      final previewController =
                          _previewControllerCache[sentenceIndex];
                      final hasReadyPreview = previewController != null &&
                          previewController.value.isInitialized;
                      final shouldMaskSwitchingFrame = isCurrentPage &&
                          _isSentenceSwitching &&
                          expectedMediaPath.isNotEmpty &&
                          expectedMediaPath != currentMediaPath &&
                          !hasReadyPreview;
                      final isAudioMode = shouldMaskSwitchingFrame
                          ? false
                          : (isCurrentPage
                              ? _isAudioMode
                              : ((sentence.mediaType ?? '').toLowerCase() ==
                                  'audio'));
                      final videoController = shouldMaskSwitchingFrame
                          ? null
                          : (isCurrentPage &&
                                  _isSentenceSwitching &&
                                  hasReadyPreview
                              ? previewController
                              : _videoControllerForPage(page, sentenceIndex));
                      final pageChild = _buildLearningLayer(
                        sentenceIndex: sentenceIndex,
                        isActivePage: isCurrentPage,
                        compactLayout: compactLayout,
                        videoFlex: videoFlex,
                        captionTopGap: captionTopGap,
                        accentColor: accentColor,
                        mediaProgress: isCurrentPage ? mediaProgress : 0,
                        mediaCurrent:
                            isCurrentPage ? mediaCurrent : Duration.zero,
                        mediaTotal: isCurrentPage ? mediaTotal : Duration.zero,
                        pageIsPlaying: pageIsPlaying,
                        isAudioMode: isAudioMode,
                        videoController: videoController,
                        blurNonVideo: isCurrentPage && _isLessonPaging,
                      );
                      return pageChild;
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLearningLayer({
    required int sentenceIndex,
    required bool isActivePage,
    required bool compactLayout,
    required int videoFlex,
    required double captionTopGap,
    required Color accentColor,
    required double mediaProgress,
    required Duration mediaCurrent,
    required Duration mediaTotal,
    required bool pageIsPlaying,
    required bool isAudioMode,
    required VideoPlayerController? videoController,
    required bool blurNonVideo,
  }) {
    final sentence = _sentences[sentenceIndex];
    final pageControlsVisible = _isSentenceSwitching || !pageIsPlaying;
    final controlsOverlayVisible =
        isActivePage && pageControlsVisible && !_isShadowingMode;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate:
          isActivePage ? _onGlobalHorizontalDragUpdate : null,
      onHorizontalDragEnd: isActivePage ? _onGlobalHorizontalDragEnd : null,
      onHorizontalDragCancel: isActivePage ? _clearHorizontalPreview : null,
      child: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                const SizedBox(height: 6),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                    child: Column(
                      children: [
                        if (_loadWarning != null &&
                            sentenceIndex == _currentIndex)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 8),
                            child: Text(
                              _loadWarning!,
                              style: TextStyle(
                                color: Colors.orange.withValues(alpha: 0.9),
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        Expanded(
                          flex: videoFlex,
                          child: RepaintBoundary(
                            child: ShortVideoVideoCard(
                              isAudioMode: isAudioMode,
                              progress: mediaProgress,
                              videoController: videoController,
                              isPlaying: pageIsPlaying,
                              onTogglePlay: isActivePage ? _togglePlay : () {},
                            ),
                          ),
                        ),
                        SizedBox(height: captionTopGap),
                        Expanded(
                          flex: compactLayout ? 2 : 3,
                          child: isActivePage
                              ? GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onTap: _togglePlay,
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final width = constraints.maxWidth;
                                      final dragging =
                                          _horizontalDragOffset.abs() > 0.5;
                                      return Stack(
                                        children: [
                                          if (_horizontalPreviewIndex != null)
                                            Transform.translate(
                                              offset: Offset(
                                                _horizontalDragOffset < 0
                                                    ? _horizontalDragOffset +
                                                        width
                                                    : _horizontalDragOffset -
                                                        width,
                                                0,
                                              ),
                                              child: _buildCaptionContent(
                                                _sentences[
                                                    _horizontalPreviewIndex!],
                                                compactLayout: compactLayout,
                                                blurNonVideo: false,
                                              ),
                                            ),
                                          Transform.translate(
                                            offset: Offset(
                                                _horizontalDragOffset, 0),
                                            child: _dragBlurWrapper(
                                              dragging,
                                              _buildCaptionContent(
                                                sentence,
                                                compactLayout: compactLayout,
                                                blurNonVideo: blurNonVideo,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                )
                              : _buildCaptionContent(
                                  sentence,
                                  compactLayout: compactLayout,
                                  blurNonVideo: blurNonVideo,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (controlsOverlayVisible)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      height: MediaQuery.of(context).padding.bottom + 92,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.06),
                            Colors.black.withValues(alpha: 0.34),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (isActivePage)
            Align(
              alignment: Alignment.bottomCenter,
              child: _blurWrapper(
                blurNonVideo,
                RepaintBoundary(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    opacity: _safeOpacity(
                      (!pageControlsVisible) ||
                              (_isShadowingMode && _isShadowingBusy)
                          ? 0
                          : 1,
                    ),
                    child: IgnorePointer(
                      ignoring: !pageControlsVisible ||
                          (_isShadowingMode && _isShadowingBusy),
                      child: ShortVideoBottomBar(
                        accentColor: accentColor,
                        progress: _isSeeking ? _seekProgress : mediaProgress,
                        isPlaying: pageIsPlaying,
                        isShadowingMode: _isShadowingMode,
                        durationText:
                            '${_formatDuration(mediaCurrent)} / ${_formatDuration(mediaTotal)}',
                        onTogglePlay: _togglePlay,
                        onToggleShadowingMode: _toggleShadowingMode,
                        onCycleSubtitleMode: _cycleSubtitleMode,
                        onToggleFullscreen: _toggleFullscreen,
                        onLongPressBar: _openPlaybackSettings,
                        subtitleIcon: _subtitleIcon(),
                        isFullscreen: _isFullscreen,
                        onSeekStart: _onSeekStart,
                        onSeekUpdate: _onSeekUpdate,
                        onSeekEnd: _onSeekEnd,
                        onSeekTap: _onSeekTap,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            top: 10,
            right: 20,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _safeOpacity(isActivePage && _isShadowingMode ? 1 : 0),
              child: _buildShadowingStatusHint(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blurWrapper(bool blur, Widget child) {
    if (!blur) return child;
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 1.0, sigmaY: 1.0),
      child: child,
    );
  }

  void _openDownloadCenter() {
    context.push(Routes.downloadCenter);
  }

  Future<void> _openPlaybackSettings() async {
    if (!mounted) return;
    final height = MediaQuery.of(context).size.height;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      isDismissible: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF1a120b),
      constraints: BoxConstraints(maxHeight: height * 0.9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const PlaybackSettingsScreen(asBottomSheet: true),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  double _safeOpacity(num value) {
    final v = value.toDouble();
    if (!v.isFinite) return 1.0;
    return v.clamp(0.0, 1.0).toDouble();
  }
}
