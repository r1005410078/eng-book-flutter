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
import '../application/practice_playback_flow_policy.dart';
import '../application/practice_playback_settings_provider.dart';
import '../data/learning_metrics_store.dart';
import '../data/local_course_package_loader.dart';
import '../data/learning_resume_store.dart';
import '../data/practice_playback_settings_store.dart';
import '../domain/sentence_detail.dart';
import '../../../routing/routes.dart';
import 'playback_settings_screen.dart';
import 'widgets/short_video_bottom_bar.dart';
import 'widgets/short_video_caption.dart';
import 'widgets/short_video_header.dart';
import 'widgets/short_video_video_card.dart';

enum ShadowingPhase { idle, listening, recording, advancing }

class _CourseUnitPickerUnit {
  final String lessonKey;
  final String lessonId;
  final String lessonTitle;
  final String firstSentenceId;
  final int sentenceCount;
  final int practiceCount;
  final double progressPercent;
  final int proficiency;
  final PracticeStatus status;

  const _CourseUnitPickerUnit({
    required this.lessonKey,
    required this.lessonId,
    required this.lessonTitle,
    required this.firstSentenceId,
    required this.sentenceCount,
    required this.practiceCount,
    required this.progressPercent,
    required this.proficiency,
    required this.status,
  });
}

class _CourseUnitPickerCourse {
  final String packageRoot;
  final String courseTitle;
  final List<_CourseUnitPickerUnit> units;
  final int practiceCount;
  final double progressPercent;
  final int proficiency;

  const _CourseUnitPickerCourse({
    required this.packageRoot,
    required this.courseTitle,
    required this.units,
    required this.practiceCount,
    required this.progressPercent,
    required this.proficiency,
  });
}

class _CourseUnitPickerSelection {
  final String packageRoot;
  final String courseTitle;
  final String lessonKey;
  final String firstSentenceId;

  const _CourseUnitPickerSelection({
    required this.packageRoot,
    required this.courseTitle,
    required this.lessonKey,
    required this.firstSentenceId,
  });
}

class SentencePracticeScreen extends ConsumerStatefulWidget {
  final String sentenceId;
  final String? packageRoot;
  final String? courseTitle;
  final Future<LocalSentenceLoadResult> Function(String packageRoot)?
      loadSentencesOverride;
  final Future<List<LocalCourseCatalog>> Function()? loadCourseCatalogsOverride;
  final bool skipMediaSetupForTest;

  const SentencePracticeScreen({
    super.key,
    required this.sentenceId,
    this.packageRoot,
    this.courseTitle,
    this.loadSentencesOverride,
    this.loadCourseCatalogsOverride,
    this.skipMediaSetupForTest = false,
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

  bool _showEnglish = true;
  bool _showChinese = true;
  bool _blurTranslationByDefault = false;
  double _subtitleScale = 0.5;
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
  final Duration _shadowingExtraDuration = const Duration(milliseconds: 120);
  final AudioRecorder _audioRecorder = AudioRecorder();

  // Video Controls State
  final double _volume = 1.0;
  double _playbackSpeed = 1.0;
  int _loopCount = 1;
  PlaybackCompletionMode _completionMode = PlaybackCompletionMode.courseLoop;
  bool _autoRecord = false;
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
  final Map<String, int> _lessonLastSentenceIndex = {};
  final Map<String, bool> _lessonPlayingState = {};
  final Map<String, Duration> _lessonLastMediaPosition = {};
  final Map<String, Duration> _lessonLastMediaDuration = {};
  final Map<int, VideoPlayerController> _previewControllerCache = {};
  final Set<int> _previewControllerLoading = {};
  String? _lastRecordedLessonKey;
  ProviderSubscription<PracticePlaybackSettings>? _settingsSubscription;
  String? _loopSentenceId;
  int _remainingLoopsForSentence = 1;
  bool _isHandlingSentenceEnd = false;
  bool _isHorizontalDragging = false;
  bool _showBottomControls = true;
  Timer? _controlsAutoHideTimer;
  Timer? _controlsPauseRevealTimer;
  static const Duration _controlsAutoHideDelay = Duration(milliseconds: 1300);
  static const Duration _controlsFadeDuration = Duration(milliseconds: 520);

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
      _syncControlsVisibilityWithPlayback();
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
    final settings = ref.read(practicePlaybackSettingsProvider);
    _syncSettingsState(settings);
    _settingsSubscription = ref.listenManual<PracticePlaybackSettings>(
      practicePlaybackSettingsProvider,
      (previous, next) {
        _syncSettingsState(next);
        unawaited(_applyPlaybackSettings(next));
      },
      fireImmediately: true,
    );
    _initializeContent();
  }

  Future<void> _initializeContent() async {
    const definedRoot = String.fromEnvironment(
      'COURSE_PACKAGE_DIR',
      defaultValue: '',
    );
    final providerContext = ref.read(localCourseContextProvider);
    final providerRoot = providerContext?.packageRoot;
    final packageRoot = widget.packageRoot ?? providerRoot ?? definedRoot;
    final courseTitleInput = widget.courseTitle ?? providerContext?.courseTitle;
    await _loadCourseContent(
      packageRoot: packageRoot,
      courseTitleInput: courseTitleInput,
      targetSentenceId: widget.sentenceId,
    );
  }

  void _syncSettingsState(PracticePlaybackSettings settings) {
    _playbackSpeed = settings.playbackSpeed;
    _showEnglish = settings.showEnglish;
    _showChinese = settings.showChinese;
    _blurTranslationByDefault = settings.blurTranslationByDefault;
    _subtitleScale = settings.subtitleScale;
    _loopCount = settings.loopCount;
    _completionMode = settings.completionMode;
    _autoRecord = settings.autoRecord;
    if (_sentences.isNotEmpty &&
        _currentIndex >= 0 &&
        _currentIndex < _sentences.length) {
      _resetSentenceLoopState(_sentences[_currentIndex].id);
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _applyPlaybackSettings(PracticePlaybackSettings settings) async {
    try {
      await _audioPlayer.setSpeed(settings.playbackSpeed);
    } catch (_) {
      // Keep playback running even if speed update fails on some sources.
    }
    if (_videoController.value.isInitialized) {
      try {
        await _videoController.setPlaybackSpeed(settings.playbackSpeed);
      } catch (_) {
        // Ignore to avoid interrupting practice flow.
      }
    }
    for (final controller in _previewControllerCache.values) {
      if (!controller.value.isInitialized) continue;
      try {
        await controller.setPlaybackSpeed(settings.playbackSpeed);
      } catch (_) {
        // Ignore stale preview updates.
      }
    }
  }

  Future<void> _loadCourseContent({
    required String packageRoot,
    String? courseTitleInput,
    required String targetSentenceId,
  }) async {
    final loaded = packageRoot.isNotEmpty
        ? await (widget.loadSentencesOverride?.call(packageRoot) ??
            loadSentencesFromLocalPackage(packageRoot: packageRoot))
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

    final index = list.indexWhere((s) => s.id == targetSentenceId);
    final targetIndex = index != -1 ? index : 0;
    final lessonStarts = _computeLessonStartIndices(list);
    final targetLessonPage =
        _lessonPageForSentenceIndex(lessonStarts, targetIndex);
    final mediaPath = list[targetIndex].mediaPath;
    final mediaType = list[targetIndex].mediaType;
    final courseTitle =
        courseTitleInput ?? list[targetIndex].courseTitle ?? '本地课程';

    _clearPreviewControllerCache();
    _lessonLastSentenceIndex.clear();
    _lessonPlayingState.clear();
    _lessonLastMediaPosition.clear();
    _lessonLastMediaDuration.clear();
    _lastRecordedLessonKey = null;

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
    _syncControlsVisibilityWithPlayback();
    if (packageRoot.isNotEmpty) {
      ref.read(localCourseContextProvider.notifier).state = LocalCourseContext(
        packageRoot: packageRoot,
        courseTitle: courseTitle,
      );
    }
    _lessonLastSentenceIndex[_lessonKeyAt(targetIndex)] = targetIndex;
    _resetSentenceLoopState(list[targetIndex].id);
    _cacheCurrentLessonPlayingState();
    unawaited(_recordPracticeForIndex(targetIndex, countLessonEntry: true));
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
    if (widget.skipMediaSetupForTest) {
      _currentMediaPath = (mediaPath ?? '').trim();
      return;
    }
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

  void _resetSentenceLoopState(String sentenceId) {
    if (_loopSentenceId == sentenceId) return;
    _loopSentenceId = sentenceId;
    _remainingLoopsForSentence = _loopCount.clamp(1, 10);
  }

  Future<void> _handleSentenceEnd() async {
    if (_isHandlingSentenceEnd) return;
    if (_currentIndex < 0 || _currentIndex >= _sentences.length) return;
    _isHandlingSentenceEnd = true;
    try {
      final shouldContinue = _isPlaying;
      final current = _sentences[_currentIndex];
      _resetSentenceLoopState(current.id);
      final decision = decideSentenceEndAction(
        remainingLoops: _remainingLoopsForSentence,
      );
      _remainingLoopsForSentence = decision.nextRemainingLoops;
      if (decision.action == SentenceEndAction.loopCurrent) {
        if (_isAudioMode) {
          await _audioPlayer.seek(current.startTime);
          if (_isPlaying && !_audioPlayer.playing) {
            await _audioPlayer.play();
          }
        } else if (_videoController.value.isInitialized) {
          await _videoController.seekTo(current.startTime);
          if (_isPlaying && !_videoController.value.isPlaying) {
            await _videoController.play();
          }
        }
        return;
      }

      final nextIndex = _currentIndex + 1;
      if (nextIndex >= 0 && nextIndex < _sentences.length) {
        final crossesLesson =
            _lessonKeyAt(nextIndex) != _lessonKeyAt(_currentIndex);
        final bounds = _lessonBoundsForIndex(_currentIndex);
        if (_completionMode == PlaybackCompletionMode.unitLoop &&
            _currentIndex >= bounds.end) {
          await _seekToSentence(bounds.start);
          if (shouldContinue && !_isPlaying) {
            await _playCurrentMedia();
          }
          return;
        }
        await _seekToSentence(nextIndex);
        if (shouldContinue &&
            _completionMode == PlaybackCompletionMode.courseLoop &&
            crossesLesson &&
            !_isPlaying) {
          await _playCurrentMedia();
        }
        return;
      }

      if (_completionMode == PlaybackCompletionMode.courseLoop) {
        await _seekToSentence(0);
        if (shouldContinue && !_isPlaying) {
          await _playCurrentMedia();
        }
        return;
      }
      if (_completionMode == PlaybackCompletionMode.pauseAfterFinish) {
        await _pauseCurrentMedia();
        return;
      }
      if (_completionMode == PlaybackCompletionMode.allCoursesLoop) {
        final moved = await _moveToNextCourseForLoop();
        if (!moved) {
          await _pauseCurrentMedia();
        }
      }
    } finally {
      _isHandlingSentenceEnd = false;
    }
  }

  Future<bool> _moveToNextCourseForLoop() async {
    final currentPackage =
        (_currentPackageRoot ?? (_sentences[_currentIndex].packageRoot ?? ''))
            .trim();
    final catalogs = await (widget.loadCourseCatalogsOverride?.call() ??
        listLocalCourseCatalogs());
    final validCatalogs = catalogs
        .where(
          (catalog) =>
              catalog.packageRoot.trim().isNotEmpty && catalog.units.isNotEmpty,
        )
        .toList();
    if (validCatalogs.isEmpty) {
      return false;
    }
    final currentIdx = validCatalogs.indexWhere(
      (catalog) => catalog.packageRoot.trim() == currentPackage,
    );
    final nextIdx =
        currentIdx == -1 ? 0 : (currentIdx + 1) % validCatalogs.length;
    final nextCatalog = validCatalogs[nextIdx];
    final nextRoot = nextCatalog.packageRoot.trim();
    final nextSentenceId = nextCatalog.units.first.firstSentenceId;
    if (nextRoot.isEmpty || nextSentenceId.trim().isEmpty) return false;
    if (nextRoot == currentPackage) {
      await _seekToSentence(0);
      return true;
    }
    await _loadCourseContent(
      packageRoot: nextRoot,
      courseTitleInput: nextCatalog.title,
      targetSentenceId: nextSentenceId,
    );
    return true;
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
      _syncControlsVisibilityWithPlayback();
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
    if (_currentIndex >= 0 && _currentIndex < _sentences.length) {
      final current = _sentences[_currentIndex];
      if (_isPlaying && !_isSeeking && currentPos >= current.endTime) {
        unawaited(_handleSentenceEnd());
        return;
      }
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
          _resetSentenceLoopState(_sentences[i].id);
          unawaited(_persistLearningResume());
          unawaited(_recordPracticeForIndex(i));
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
    if (_currentIndex >= 0 && _currentIndex < _sentences.length) {
      final current = _sentences[_currentIndex];
      if (_isPlaying && !_isSeeking && currentPos >= current.endTime) {
        unawaited(_handleSentenceEnd());
        return;
      }
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
          _resetSentenceLoopState(_sentences[i].id);
          unawaited(_persistLearningResume());
          unawaited(_recordPracticeForIndex(i));
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
    _settingsSubscription?.close();
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
    _controlsAutoHideTimer?.cancel();
    _controlsPauseRevealTimer?.cancel();
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
    if (!mounted) return;
    _controlsAutoHideTimer?.cancel();
    _controlsPauseRevealTimer?.cancel();
    if (!_showBottomControls) {
      setState(() {
        _showBottomControls = true;
      });
    }
    _scheduleControlsAutoHide();
  }

  void _scheduleControlsAutoHide() {
    _controlsAutoHideTimer?.cancel();
    if (!_isPlaying) return;
    if (_isSeeking || _isHorizontalDragging || _isSentenceSwitching) return;
    if (_isShadowingMode && _isShadowingBusy) return;
    _controlsAutoHideTimer = Timer(_controlsAutoHideDelay, () {
      if (!mounted) return;
      if (!_isPlaying) return;
      if (_isSeeking || _isHorizontalDragging || _isSentenceSwitching) return;
      if (_isShadowingMode && _isShadowingBusy) return;
      if (!_showBottomControls) return;
      setState(() {
        _showBottomControls = false;
      });
    });
  }

  void _syncControlsVisibilityWithPlayback() {
    if (!mounted) return;
    if (_isPlaying) {
      _controlsPauseRevealTimer?.cancel();
      _scheduleControlsAutoHide();
      return;
    }
    _controlsAutoHideTimer?.cancel();
    _controlsPauseRevealTimer?.cancel();
    _controlsPauseRevealTimer = Timer(const Duration(milliseconds: 220), () {
      if (!mounted || _isPlaying) return;
      if (_showBottomControls) return;
      setState(() {
        _showBottomControls = true;
      });
    });
  }

  void _cycleSubtitleMode() {
    unawaited(
      ref.read(practicePlaybackSettingsProvider.notifier).cycleSubtitleMode(),
    );
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
    final speed = _playbackSpeed <= 0 ? 1.0 : _playbackSpeed;
    final alignedToPlayback = Duration(
      milliseconds: (sentenceDuration.inMilliseconds / speed).round(),
    );
    final recordWindow = alignedToPlayback + _shadowingExtraDuration;
    final shouldContinue = _isPlaying;

    setState(() {
      _isShadowingBusy = true;
      _shadowingPhase = ShadowingPhase.recording;
    });

    try {
      await _pauseCurrentMedia();
      if (!_isShadowingMode || sessionId != _shadowingSessionId) return;

      if (_autoRecord) {
        final availability = await detectAutoRecordAvailability(
          AudioRecorderPermissionProbe(_audioRecorder),
        );
        if (availability == AutoRecordAvailability.available) {
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
        } else if (availability == AutoRecordAvailability.permissionDenied &&
            mounted) {
          setState(() {
            _loadWarning = '录音权限未开启，自动录音已跳过。';
          });
        } else if (availability == AutoRecordAvailability.unsupported &&
            mounted) {
          setState(() {
            _loadWarning = '当前设备不支持自动录音，已跳过录音。';
          });
        }
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
      _syncControlsVisibilityWithPlayback();
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
      _syncControlsVisibilityWithPlayback();
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
      _syncControlsVisibilityWithPlayback();
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
    _onUserInteraction();
  }

  void _onSeekUpdate(double progress) {
    if (_isShadowingMode) return;
    if (!_isSeeking) return;
    setState(() {
      _seekProgress = progress.clamp(0.0, 1.0);
    });
    _onUserInteraction();
  }

  Future<void> _onSeekEnd(double _) async {
    if (_isShadowingMode) return;
    if (!_isSeeking) return;
    final target = _seekProgress;
    setState(() {
      _isSeeking = false;
    });
    _scheduleControlsAutoHide();
    await _seekByProgress(target);
  }

  Future<void> _onSeekTap(double progress) async {
    if (_isShadowingMode) return;
    setState(() {
      _isSeeking = false;
    });
    _onUserInteraction();
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

  void _settleHorizontalPreview() {
    if (!mounted) return;
    final hadPreview = _horizontalPreviewIndex != null;
    setState(() {
      _horizontalDragOffset = 0;
    });
    if (!hadPreview) return;
    Future<void>.delayed(const Duration(milliseconds: 140), () {
      if (!mounted || _isHorizontalDragging) return;
      if (_horizontalDragOffset.abs() > 0.01) return;
      setState(() {
        _horizontalPreviewIndex = null;
      });
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

  void _onGlobalHorizontalDragStart(DragStartDetails details) {
    if (_isShadowingMode) return;
    _isHorizontalDragging = true;
    _onUserInteraction();
  }

  void _onGlobalHorizontalDragUpdate(DragUpdateDetails details) {
    if (_isShadowingMode) return;
    final width = MediaQuery.of(context).size.width;
    final delta = details.delta.dx;
    final hasNext = _currentIndex + 1 < _sentences.length;
    final hasPrevious = _currentIndex - 1 >= 0;
    final draggingToNext = delta < 0;
    final blockedAtEdge =
        (draggingToNext && !hasNext) || (!draggingToNext && !hasPrevious);
    final adjustedDelta = blockedAtEdge ? delta * 0.45 : delta;
    final next = (_horizontalDragOffset + adjustedDelta)
        .clamp(-width * 0.85, width * 0.85);
    setState(() {
      _horizontalDragOffset = next;
    });
    _updateHorizontalPreview();
  }

  void _onGlobalHorizontalDragEnd(DragEndDetails details) {
    if (_isShadowingMode) return;
    _isHorizontalDragging = false;
    final width = MediaQuery.of(context).size.width;
    final velocity = details.velocity.pixelsPerSecond.dx;
    final threshold = width * 0.24;
    final shouldNext = _horizontalDragOffset < -threshold || velocity < -700;
    final shouldPrevious = _horizontalDragOffset > threshold || velocity > 700;
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
    _settleHorizontalPreview();
    _scheduleControlsAutoHide();
  }

  void _onGlobalHorizontalDragCancel() {
    _isHorizontalDragging = false;
    _settleHorizontalPreview();
    _scheduleControlsAutoHide();
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
          showEnglish: _showEnglish,
          showChinese: _showChinese,
          blurTranslationByDefault: _blurTranslationByDefault,
          subtitleScale: _subtitleScale,
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
    final previousLessonKey =
        (_currentIndex >= 0 && _currentIndex < _sentences.length)
            ? _lessonKeyAt(_currentIndex)
            : null;
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
      _resetSentenceLoopState(_sentences[index].id);
      _cacheCurrentLessonPlayingState();
      _syncLessonPageWithCurrentSentence();
      final targetLessonKey = _lessonKeyAt(index);
      final lessonChanged = previousLessonKey != targetLessonKey;
      await _recordPracticeForIndex(
        index,
        countLessonEntry: lessonChanged,
      );
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

  Future<void> _recordPracticeForIndex(
    int index, {
    bool countLessonEntry = false,
  }) async {
    if (index < 0 || index >= _sentences.length) return;
    final sentence = _sentences[index];
    final packageRoot =
        (_currentPackageRoot ?? sentence.packageRoot ?? '').trim();
    if (packageRoot.isEmpty) return;
    final lessonKey = _lessonKeyAt(index);
    if (lessonKey.isEmpty) return;

    if (countLessonEntry && _lastRecordedLessonKey != lessonKey) {
      final bounds = _lessonBoundsForIndex(index);
      await LearningMetricsStore.recordLessonEntry(
        packageRoot: packageRoot,
        lessonKey: lessonKey,
        totalCourseSentences: _sentences.length,
        totalLessonSentences: (bounds.end - bounds.start) + 1,
      );
      _lastRecordedLessonKey = lessonKey;
    }

    final bounds = _lessonBoundsForIndex(index);
    await LearningMetricsStore.recordSentencePractice(
      packageRoot: packageRoot,
      lessonKey: lessonKey,
      sentenceId: sentence.id,
      totalCourseSentences: _sentences.length,
      totalLessonSentences: (bounds.end - bounds.start) + 1,
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
    if (_showEnglish && _showChinese) return Icons.subtitles_rounded;
    if (_showEnglish && !_showChinese) return Icons.closed_caption_outlined;
    if (!_showEnglish && !_showChinese) return Icons.subtitles_off_outlined;
    return Icons.translate_rounded;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_sentences.isEmpty) {
      return _EmptyCourseGuideView(
        onGoToDownloadCenter: _openDownloadCenter,
        warning: _loadWarning,
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
                courseTitle: _headerCourseTitle(),
                lessonTitle: _headerLessonTitle(),
                onTapCourseUnitPicker: _openCourseUnitPicker,
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
    final pageControlsVisible = isActivePage && _showBottomControls;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: isActivePage ? _onGlobalHorizontalDragStart : null,
      onHorizontalDragUpdate:
          isActivePage ? _onGlobalHorizontalDragUpdate : null,
      onHorizontalDragEnd: isActivePage ? _onGlobalHorizontalDragEnd : null,
      onHorizontalDragCancel:
          isActivePage ? _onGlobalHorizontalDragCancel : null,
      child: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                const SizedBox(height: 6),
                Expanded(
                  child: Column(
                    children: [
                      if (_loadWarning != null &&
                          sentenceIndex == _currentIndex)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
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
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
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
                                    final dragProgress = width <= 0
                                        ? 0.0
                                        : (_horizontalDragOffset.abs() /
                                                (width * 0.32))
                                            .clamp(0.0, 1.0);
                                    final currentOpacity =
                                        (1.0 - (dragProgress * 0.24))
                                            .clamp(0.0, 1.0)
                                            .toDouble();
                                    final previewOpacity =
                                        (0.22 + (dragProgress * 0.78))
                                            .clamp(0.0, 1.0)
                                            .toDouble();
                                    final currentScale =
                                        (1.0 - (dragProgress * 0.015))
                                            .clamp(0.98, 1.0)
                                            .toDouble();
                                    final previewScale =
                                        (0.99 + (dragProgress * 0.01))
                                            .clamp(0.99, 1.0)
                                            .toDouble();
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
                                            child: Opacity(
                                              opacity: _safeOpacity(
                                                previewOpacity,
                                              ),
                                              child: Transform.scale(
                                                alignment: Alignment.center,
                                                scale: previewScale,
                                                child: _buildCaptionContent(
                                                  _sentences[
                                                      _horizontalPreviewIndex!],
                                                  compactLayout: compactLayout,
                                                  blurNonVideo: false,
                                                ),
                                              ),
                                            ),
                                          ),
                                        Transform.translate(
                                          offset:
                                              Offset(_horizontalDragOffset, 0),
                                          child: Opacity(
                                            opacity: _safeOpacity(
                                              currentOpacity,
                                            ),
                                            child: Transform.scale(
                                              alignment: Alignment.center,
                                              scale: currentScale,
                                              child: _dragBlurWrapper(
                                                dragging,
                                                _buildCaptionContent(
                                                  sentence,
                                                  compactLayout: compactLayout,
                                                  blurNonVideo: blurNonVideo,
                                                ),
                                              ),
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
              ],
            ),
          ),
          if (isActivePage)
            Align(
              alignment: Alignment.bottomCenter,
              child: _blurWrapper(
                blurNonVideo,
                RepaintBoundary(
                  child: AnimatedOpacity(
                    duration: _controlsFadeDuration,
                    curve: Curves.easeOutCubic,
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

  String _courseUnitKey({
    required String packageRoot,
    String? lessonId,
    String? lessonTitle,
    String? mediaPath,
  }) {
    final scope = 'pkg:$packageRoot';
    final safeLessonId = (lessonId ?? '').trim();
    if (safeLessonId.isNotEmpty) return '$scope|lesson:$safeLessonId';
    final safeLessonTitle = (lessonTitle ?? '').trim();
    if (safeLessonTitle.isNotEmpty) return '$scope|title:$safeLessonTitle';
    final safeMediaPath = (mediaPath ?? '').trim();
    if (safeMediaPath.isNotEmpty) return '$scope|media:$safeMediaPath';
    return '$scope|default';
  }

  List<_CourseUnitPickerUnit> _buildUnitOptionsFromSentences(
    List<SentenceDetail> sentences,
    String packageRoot,
    LearningMetricsSnapshot metricsSnapshot,
  ) {
    if (sentences.isEmpty) return const [];
    final units = <_CourseUnitPickerUnit>[];
    int start = 0;
    while (start < sentences.length) {
      final startSentence = sentences[start];
      final key = _lessonKeyFromSentence(startSentence);
      int end = start;
      while (end + 1 < sentences.length &&
          _lessonKeyFromSentence(sentences[end + 1]) == key) {
        end++;
      }
      final lessonId = (startSentence.lessonId ?? '').trim();
      final lessonTitle = (startSentence.lessonTitle ?? '').trim();
      final displayTitle = lessonTitle.isNotEmpty
          ? lessonTitle
          : (lessonId.isNotEmpty ? '单元 $lessonId' : '单元 ${units.length + 1}');
      final unitMetrics = metricsSnapshot.unitView(
        packageRoot,
        key,
        totalSentenceCount: end - start + 1,
      );
      units.add(
        _CourseUnitPickerUnit(
          lessonKey: key,
          lessonId: lessonId,
          lessonTitle: displayTitle,
          firstSentenceId: startSentence.id,
          sentenceCount: end - start + 1,
          practiceCount: unitMetrics.practiceCount,
          progressPercent: unitMetrics.progressPercent,
          proficiency: unitMetrics.proficiency,
          status: unitMetrics.status,
        ),
      );
      start = end + 1;
    }
    return units;
  }

  Future<List<_CourseUnitPickerCourse>> _loadCourseUnitPickerCourses() async {
    final currentPackage = (_currentPackageRoot ??
            (_sentences.isNotEmpty
                ? _sentences[_currentIndex].packageRoot
                : null) ??
            '')
        .trim();
    final currentCourseTitle = (_currentCourseTitle ??
            (_sentences.isNotEmpty
                ? _sentences[_currentIndex].courseTitle
                : null) ??
            '本地课程')
        .trim();
    final map = <String, _CourseUnitPickerCourse>{};
    final metricsSnapshot = await LearningMetricsStore.loadSnapshot();

    final catalogs = await (widget.loadCourseCatalogsOverride?.call() ??
        listLocalCourseCatalogs());
    for (final catalog in catalogs) {
      final root = catalog.packageRoot.trim();
      if (root.isEmpty || catalog.units.isEmpty) continue;
      final courseTotalSentences = catalog.units.fold<int>(
        0,
        (sum, unit) => sum + unit.sentenceCount,
      );
      final courseMetrics = metricsSnapshot.courseView(
        root,
        totalSentenceCount: courseTotalSentences,
      );
      final units = catalog.units.map((unit) {
        final lessonKey = _courseUnitKey(
          packageRoot: root,
          lessonId: unit.lessonId,
          lessonTitle: unit.title,
        );
        final unitMetrics = metricsSnapshot.unitView(
          root,
          lessonKey,
          totalSentenceCount: unit.sentenceCount,
        );
        return _CourseUnitPickerUnit(
          lessonKey: lessonKey,
          lessonId: unit.lessonId,
          lessonTitle: unit.title,
          firstSentenceId: unit.firstSentenceId,
          sentenceCount: unit.sentenceCount,
          practiceCount: unitMetrics.practiceCount,
          progressPercent: unitMetrics.progressPercent,
          proficiency: unitMetrics.proficiency,
          status: unitMetrics.status,
        );
      }).toList();
      map[root] = _CourseUnitPickerCourse(
        packageRoot: root,
        courseTitle: catalog.title,
        units: units,
        practiceCount: courseMetrics.practiceCount,
        progressPercent: courseMetrics.progressPercent,
        proficiency: courseMetrics.proficiency,
      );
    }

    if (currentPackage.isNotEmpty && _sentences.isNotEmpty) {
      final units = _buildUnitOptionsFromSentences(
        _sentences,
        currentPackage,
        metricsSnapshot,
      );
      final courseMetrics = metricsSnapshot.courseView(
        currentPackage,
        totalSentenceCount: _sentences.length,
      );
      map[currentPackage] = _CourseUnitPickerCourse(
        packageRoot: currentPackage,
        courseTitle: currentCourseTitle,
        units: units,
        practiceCount: courseMetrics.practiceCount,
        progressPercent: courseMetrics.progressPercent,
        proficiency: courseMetrics.proficiency,
      );
    }

    final courses = map.values.toList();
    courses.sort((a, b) {
      if (a.packageRoot == currentPackage) return -1;
      if (b.packageRoot == currentPackage) return 1;
      return a.courseTitle.compareTo(b.courseTitle);
    });
    return courses;
  }

  Future<void> _openCourseUnitPicker() async {
    if (_sentences.isEmpty) return;
    final courses = await _loadCourseUnitPickerCourses();
    if (!mounted || courses.isEmpty) return;
    final currentPackage =
        (_currentPackageRoot ?? _sentences[_currentIndex].packageRoot ?? '')
            .trim();
    final currentLessonKey = _lessonKeyAt(_currentIndex);

    final selection = await showModalBottomSheet<_CourseUnitPickerSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      isDismissible: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF1a120b),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.94,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (_) => _CourseUnitPickerSheet(
        courses: courses,
        currentPackageRoot: currentPackage,
        currentLessonKey: currentLessonKey,
      ),
    );
    if (selection == null || !mounted) return;

    final targetPackage = selection.packageRoot.trim();
    if (targetPackage == currentPackage) {
      final remembered = _lessonLastSentenceIndex[selection.lessonKey];
      final targetIndex = remembered != null &&
              remembered >= 0 &&
              remembered < _sentences.length &&
              _lessonKeyAt(remembered) == selection.lessonKey
          ? remembered
          : _sentences.indexWhere(
              (s) => _lessonKeyFromSentence(s) == selection.lessonKey,
            );
      if (targetIndex >= 0 && targetIndex != _currentIndex) {
        await _seekToSentence(targetIndex);
      }
      return;
    }

    await _loadCourseContent(
      packageRoot: targetPackage,
      courseTitleInput: selection.courseTitle,
      targetSentenceId: selection.firstSentenceId,
    );
  }

  String _headerCourseTitle() {
    if (_sentences.isEmpty) return _currentCourseTitle ?? '本地课程';
    final sentence = _sentences[_currentIndex];
    return (_currentCourseTitle ?? sentence.courseTitle ?? '本地课程').trim();
  }

  String _headerLessonTitle() {
    if (_sentences.isEmpty) return '单元';
    final sentence = _sentences[_currentIndex];
    final lessonTitle = (sentence.lessonTitle ?? '').trim();
    if (lessonTitle.isNotEmpty) return lessonTitle;
    final lessonId = (sentence.lessonId ?? '').trim();
    if (lessonId.isNotEmpty) return '单元 $lessonId';
    return '单元 ${(_currentLessonPage + 1).toString().padLeft(2, '0')}';
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

class _EmptyCourseGuideView extends StatelessWidget {
  final VoidCallback onGoToDownloadCenter;
  final String? warning;

  const _EmptyCourseGuideView({
    required this.onGoToDownloadCenter,
    this.warning,
  });

  @override
  Widget build(BuildContext context) {
    const titleColor = Color(0xFFF5F5F2);
    const subtitleColor = Color(0xFFD6D7DB);
    const highlightColor = Color(0xFFF9C431);
    const iconColor = Color(0xFFD5C995);
    const buttonColor = Color(0xFFEC9000);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(color: Color(0xFF0C0C10)),
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(0, -1.1),
                    end: Alignment(0, 1.0),
                    colors: [
                      Color(0xFF656A60),
                      Color(0xFF8D7A5F),
                      Color(0xFF171923),
                      Color(0xFF09090D),
                    ],
                    stops: [0.0, 0.44, 0.77, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              left: -90,
              top: -80,
              child: IgnorePointer(
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFCED1C4).withValues(alpha: 0.12),
                  ),
                ),
              ),
            ),
            Positioned(
              right: -120,
              top: -40,
              child: IgnorePointer(
                child: Container(
                  width: 380,
                  height: 380,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFCCB48F).withValues(alpha: 0.2),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.62),
                    ],
                    stops: const [0.28, 0.62, 1.0],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  children: [
                    const Spacer(flex: 7),
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 48,
                      color: iconColor.withValues(alpha: 0.96),
                    ),
                    const SizedBox(height: 34),
                    Text(
                      '开启你的',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 38 / 2,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 16,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '语言学习之旅',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: highlightColor,
                        fontSize: 33,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                            color: Color(0xCC000000),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 44),
                    Text(
                      '基于 Krashen 可理解输入与 100LS 训练法',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: subtitleColor.withValues(alpha: 0.94),
                        fontSize: 21,
                        height: 1.4,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: 92,
                      height: 2,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: const Color(0xFFC58A1C).withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '带你进入沉浸式学习心流',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: subtitleColor.withValues(alpha: 0.9),
                        fontSize: 20,
                        height: 1.5,
                      ),
                    ),
                    if (warning != null && warning!.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        warning!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.52),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const Spacer(flex: 3),
                    SizedBox(
                      width: double.infinity,
                      height: 68,
                      child: FilledButton(
                        onPressed: onGoToDownloadCenter,
                        style: FilledButton.styleFrom(
                          backgroundColor: buttonColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 0,
                          textStyle: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('前往下载中心'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseUnitPickerSheet extends StatefulWidget {
  final List<_CourseUnitPickerCourse> courses;
  final String currentPackageRoot;
  final String currentLessonKey;

  const _CourseUnitPickerSheet({
    required this.courses,
    required this.currentPackageRoot,
    required this.currentLessonKey,
  });

  @override
  State<_CourseUnitPickerSheet> createState() => _CourseUnitPickerSheetState();
}

class _CourseUnitPickerSheetState extends State<_CourseUnitPickerSheet> {
  late String _selectedPackageRoot;
  String? _selectedLessonKey;

  String _unitStatusLabel(PracticeStatus status) {
    return switch (status) {
      PracticeStatus.notStarted => '未开始',
      PracticeStatus.inProgress => '学习中',
      PracticeStatus.completed => '已完成',
    };
  }

  @override
  void initState() {
    super.initState();
    final exists = widget.courses.any(
      (course) => course.packageRoot == widget.currentPackageRoot,
    );
    _selectedPackageRoot =
        exists ? widget.currentPackageRoot : widget.courses.first.packageRoot;
    _selectedLessonKey = widget.currentLessonKey;
  }

  _CourseUnitPickerUnit? _selectedUnitForCourse(
      _CourseUnitPickerCourse course) {
    if (course.units.isEmpty) return null;
    final selected = _selectedLessonKey;
    if (selected != null) {
      for (final unit in course.units) {
        if (unit.lessonKey == selected) return unit;
      }
    }
    return course.units.first;
  }

  Color _statusColor(PracticeStatus status) {
    return switch (status) {
      PracticeStatus.completed => const Color(0xFF48D48A),
      PracticeStatus.inProgress => const Color(0xFFFFA726),
      PracticeStatus.notStarted => Colors.white.withValues(alpha: 0.35),
    };
  }

  Widget _statusTrailing(PracticeStatus status, {required bool selected}) {
    if (status == PracticeStatus.completed) {
      return Icon(
        Icons.check_circle_rounded,
        size: 28,
        color: const Color(0xFF48D48A).withValues(alpha: selected ? 1 : 0.92),
      );
    }
    if (status == PracticeStatus.inProgress) {
      return Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: const Color(0xFFFFA726),
          borderRadius: BorderRadius.circular(6),
        ),
      );
    }
    return Icon(
      Icons.radio_button_unchecked_rounded,
      size: 18,
      color: Colors.white.withValues(alpha: 0.34),
    );
  }

  void _confirmSelection(_CourseUnitPickerCourse selectedCourse) {
    final selectedUnit = _selectedUnitForCourse(selectedCourse);
    if (selectedUnit == null) return;
    Navigator.of(context).pop(
      _CourseUnitPickerSelection(
        packageRoot: selectedCourse.packageRoot,
        courseTitle: selectedCourse.courseTitle,
        lessonKey: selectedUnit.lessonKey,
        firstSentenceId: selectedUnit.firstSentenceId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final selectedCourse = widget.courses.firstWhere(
      (course) => course.packageRoot == _selectedPackageRoot,
      orElse: () => widget.courses.first,
    );
    final selectedUnit = _selectedUnitForCourse(selectedCourse);

    return Padding(
      padding: EdgeInsets.fromLTRB(0, 0, 0, bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Text(
              'COURSE CATALOG',
              style: TextStyle(
                color: const Color(0xFFB47A23).withValues(alpha: 0.85),
                fontSize: 12,
                letterSpacing: 2.0,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 56,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              primary: false,
              itemCount: widget.courses.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final course = widget.courses[index];
                final selected = course.packageRoot == _selectedPackageRoot;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (selected) return;
                    setState(() {
                      _selectedPackageRoot = course.packageRoot;
                      _selectedLessonKey = null;
                    });
                  },
                  child: Container(
                    width: 182,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF2A1D10)
                          : const Color(0xFF19110B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF8A581A)
                            : Colors.white.withValues(alpha: 0.09),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.circle,
                              size: 12,
                              color: selected
                                  ? const Color(0xFFFFA726)
                                  : const Color(0xFF4ADE80),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                course.courseTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: selected
                                      ? const Color(0xFFFFB239)
                                      : const Color(0xFFB47A23),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          '${course.practiceCount} 次 · ${course.progressPercent.round()}% · 熟练度 ${course.proficiency}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.46),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: const Color(0xFF3A2611)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${selectedCourse.courseTitle} — 单元',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFFFB02E),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '● 已完成',
                  style: TextStyle(
                    color: _statusColor(PracticeStatus.completed),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '● 当前在学',
                  style: TextStyle(
                    color: _statusColor(PracticeStatus.inProgress),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              itemCount: selectedCourse.units.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final unit = selectedCourse.units[index];
                final active = selectedUnit?.lessonKey == unit.lessonKey;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      _selectedLessonKey = unit.lessonKey;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFF2A1D10)
                          : const Color(0xFF19110B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: active
                            ? const Color(0xFF8A581A)
                            : Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 46,
                          child: Text(
                            (index + 1).toString().padLeft(2, '0'),
                            style: TextStyle(
                              color: active
                                  ? const Color(0xFFFFB239)
                                  : const Color(0xFF7B5A2C),
                              fontSize: active ? 15 : 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                unit.lessonTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: active
                                      ? const Color(0xFFFFB239)
                                      : const Color(0xFFB47A23),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${_unitStatusLabel(unit.status)} · 练习 ${unit.practiceCount} 次 · ${unit.progressPercent.round()}% · 熟练度 ${unit.proficiency}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        _statusTrailing(unit.status, selected: active),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF18100A),
              border: Border(top: BorderSide(color: Color(0xFF3A2611))),
            ),
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedUnit == null
                        ? '已选择:${selectedCourse.courseTitle}'
                        : '已选择:${selectedCourse.courseTitle} / ${selectedUnit.lessonTitle}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.46),
                      fontSize: 11.5,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 148,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => _confirmSelection(selectedCourse),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFAA2B),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '继续学习',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
