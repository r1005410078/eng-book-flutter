import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';
import '../application/local_course_provider.dart';
import '../application/practice_lesson_index_service.dart';
import '../application/practice_lesson_header_progress_service.dart';
import '../application/practice_lesson_key_service.dart';
import '../application/practice_lesson_page_change_planner.dart';
import '../application/practice_lesson_preview_planner.dart';
import '../application/practice_media_playback_service.dart';
import '../application/practice_preview_controller_cache_service.dart';
import '../application/practice_playback_settings_provider.dart';
import '../application/practice_sentence_end_action_planner.dart';
import '../application/practice_sentence_position_matcher.dart';
import '../application/sentence_seek_coordinator.dart';
import '../application/shadowing_auto_record_service.dart';
import '../application/shadowing_step_controller.dart';
import '../data/learning_metrics_store.dart';
import '../data/local_course_package_loader.dart';
import '../data/learning_resume_store.dart';
import '../data/practice_playback_settings_store.dart';
import '../domain/sentence_detail.dart';
import '../../../routing/routes.dart';
import 'course_unit_picker_builder.dart';
import 'course_unit_picker_sheet.dart';
import 'empty_course_guide_view.dart';
import 'playback_settings_sheet.dart';
import 'shadowing_state.dart';
import 'shadowing_state_controller.dart';
import 'shadowing_status_hint.dart';
import 'widgets/short_video_bottom_bar.dart';
import 'widgets/short_video_caption.dart';
import 'widgets/short_video_header.dart';
import 'widgets/short_video_video_card.dart';

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
  List<String> _lessonKeys = const [];
  int _currentIndex = 0;
  bool _isLoading = true;
  String? _loadWarning;
  String? _currentPackageRoot;
  String? _currentCourseTitle;
  String? _currentMediaPath;

  bool _showEnglish = false;
  bool _showChinese = false;
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
  final ShadowingStateController _shadowingStateController =
      ShadowingStateController();
  Timer? _shadowingTicker;
  bool _isSeeking = false;
  double _seekProgress = 0;
  bool _isTogglingPlay = false;
  int _shadowingSessionId = 0;
  final AudioRecorder _audioRecorder = AudioRecorder();
  late final ShadowingAutoRecordService _shadowingAutoRecordService;
  late final ShadowingStepController _shadowingStepController;
  static const PracticeMediaPlaybackService _mediaPlaybackService =
      PracticeMediaPlaybackService();
  static const PracticeLessonIndexService _lessonIndexService =
      PracticeLessonIndexService();
  static const PracticeLessonHeaderProgressService
      _lessonHeaderProgressService = PracticeLessonHeaderProgressService();
  static const PracticeLessonKeyService _lessonKeyService =
      PracticeLessonKeyService();
  static const PracticeLessonPageChangePlanner _lessonPageChangePlanner =
      PracticeLessonPageChangePlanner();
  static const PracticeLessonPreviewPlanner _lessonPreviewPlanner =
      PracticeLessonPreviewPlanner();
  static const PracticePreviewControllerCacheService
      _previewControllerCacheService = PracticePreviewControllerCacheService();
  static const PracticeSentenceEndActionPlanner _sentenceEndActionPlanner =
      PracticeSentenceEndActionPlanner();
  static const PracticeSentencePositionMatcher _sentencePositionMatcher =
      PracticeSentencePositionMatcher();
  static const SentenceSeekCoordinator _sentenceSeekCoordinator =
      SentenceSeekCoordinator();

  // Video Controls State
  final double _volume = 1.0;
  double _playbackSpeed = 1.0;
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
  bool _isHandlingSentenceEnd = false;
  bool _isHorizontalDragging = false;
  bool _isScrubbingProgressBar = false;
  bool _showBottomControls = true;
  int? _manualSeekExpectedIndex;
  DateTime? _manualSeekProtectUntil;
  Timer? _controlsAutoHideTimer;
  Timer? _controlsPauseRevealTimer;
  static const Duration _controlsAutoHideDelay = Duration(milliseconds: 1300);
  static const Duration _controlsFadeDuration = Duration(milliseconds: 520);

  ShadowingState get _shadowing => _shadowingStateController.state;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lessonPageController = PageController();
    _shadowingAutoRecordService = ShadowingAutoRecordService(_audioRecorder);
    _shadowingStepController = ShadowingStepController(
      autoRecordService: _shadowingAutoRecordService,
    );
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
    final changed = _playbackSpeed != settings.playbackSpeed ||
        _showEnglish != settings.showEnglish ||
        _showChinese != settings.showChinese ||
        _blurTranslationByDefault != settings.blurTranslationByDefault ||
        _subtitleScale != settings.subtitleScale ||
        _completionMode != settings.completionMode ||
        _autoRecord != settings.autoRecord;
    _playbackSpeed = settings.playbackSpeed;
    _showEnglish = settings.showEnglish;
    _showChinese = settings.showChinese;
    _blurTranslationByDefault = settings.blurTranslationByDefault;
    _subtitleScale = settings.subtitleScale;
    _completionMode = settings.completionMode;
    _autoRecord = settings.autoRecord;
    if (mounted && changed) {
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
        _lessonKeys = const [];
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
    final resolvedPackageRoot = packageRoot.isEmpty ? null : packageRoot;
    final lessonKeys = _lessonKeyService.keysFromSentences(
      list,
      fallbackPackageRoot: resolvedPackageRoot,
    );
    final lessonStarts = _computeLessonStartIndicesFromKeys(lessonKeys);
    final targetLessonPage =
        _lessonPageForSentenceIndex(lessonStarts, targetIndex);
    final mediaPath = list[targetIndex].mediaPath;
    final mediaType = list[targetIndex].mediaType;
    final sentenceCourseTitle = (list[targetIndex].courseTitle ?? '').trim();
    final inputCourseTitle = (courseTitleInput ?? '').trim();
    final courseTitle = sentenceCourseTitle.isNotEmpty
        ? sentenceCourseTitle
        : (inputCourseTitle.isNotEmpty ? inputCourseTitle : '本地课程');

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
      _lessonKeys = lessonKeys;
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
    final useAudio = _isAudioMedia(mediaType: mediaType, lowerPath: lowerPath);

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
      await next.setLooping(false);
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
      await _videoController.setLooping(false);
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

  Future<void> _handleSentenceEnd() async {
    if (_isHandlingSentenceEnd) return;
    if (_currentIndex < 0 || _currentIndex >= _sentences.length) return;
    _isHandlingSentenceEnd = true;
    try {
      final shouldContinue = _isPlaying;
      final nextIndex = _currentIndex + 1;
      if (nextIndex >= 0 && nextIndex < _sentences.length) {
        final bounds = _lessonBoundsForIndex(_currentIndex);
        final currentLessonKey = _lessonKeyAt(_currentIndex);
        if (_completionMode == PlaybackCompletionMode.unitLoop &&
            _currentIndex >= bounds.end) {
          final fastSwitched = await _seekWithinCurrentMedia(
            bounds.start,
            preservePlayingState: true,
          );
          if (!fastSwitched) {
            await _seekToSentence(bounds.start, preservePlayingState: true);
          }
          if (shouldContinue && !_isPlaying) {
            await _playCurrentMedia();
          }
          return;
        }
        final crossesLesson = _lessonKeyAt(nextIndex) != currentLessonKey;
        final advancedWithoutSeek =
            await _advanceWithinCurrentMediaWithoutSeek(nextIndex);
        if (!advancedWithoutSeek) {
          final fastSwitched = await _seekWithinCurrentMedia(
            nextIndex,
            preservePlayingState: true,
          );
          if (!fastSwitched) {
            await _seekToSentence(nextIndex, preservePlayingState: true);
          }
        }
        if (shouldContinue && !_isPlaying) {
          await _playCurrentMedia();
        }
        if (crossesLesson) {
          _resetLessonPlaybackProgress(
            lessonKey: currentLessonKey,
            lessonStartIndex: bounds.start,
          );
        }
        return;
      }

      if (_completionMode == PlaybackCompletionMode.courseLoop) {
        final bounds = _lessonBoundsForIndex(_currentIndex);
        final currentLessonKey = _lessonKeyAt(_currentIndex);
        final fastSwitched = await _seekWithinCurrentMedia(
          0,
          preservePlayingState: true,
        );
        if (!fastSwitched) {
          await _seekToSentence(0, preservePlayingState: true);
        }
        if (shouldContinue && !_isPlaying) {
          await _playCurrentMedia();
        }
        _resetLessonPlaybackProgress(
          lessonKey: currentLessonKey,
          lessonStartIndex: bounds.start,
        );
        return;
      }
      if (_completionMode == PlaybackCompletionMode.pauseAfterFinish) {
        final bounds = _lessonBoundsForIndex(_currentIndex);
        _resetLessonPlaybackProgress(
          lessonKey: _lessonKeyAt(_currentIndex),
          lessonStartIndex: bounds.start,
        );
        await _pauseCurrentMedia();
        return;
      }
      if (_completionMode == PlaybackCompletionMode.allCoursesLoop) {
        final bounds = _lessonBoundsForIndex(_currentIndex);
        _resetLessonPlaybackProgress(
          lessonKey: _lessonKeyAt(_currentIndex),
          lessonStartIndex: bounds.start,
        );
        final moved = await _moveToNextCourseForLoop();
        if (!moved) {
          await _pauseCurrentMedia();
        }
      }
    } finally {
      _isHandlingSentenceEnd = false;
    }
  }

  bool _shouldAdvanceAtSentenceEnd(
    Duration currentPos,
    SentenceDetail sentence,
  ) {
    final sentenceDuration = sentence.endTime - sentence.startTime;
    final durationMs = sentenceDuration.inMilliseconds;
    if (durationMs <= 0) return currentPos >= sentence.endTime;
    final thresholdMs = (durationMs ~/ 6).clamp(70, 120);
    final triggerAt =
        sentence.endTime - Duration(milliseconds: thresholdMs.toInt());
    return currentPos >= triggerAt;
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
    _syncSentenceWithMediaPosition(currentPos);
  }

  void _syncSentenceWithAudio(Duration currentPos) {
    if (_isSentenceSwitching) return;
    if (!_isAudioMode) return;
    _syncSentenceWithMediaPosition(currentPos);
  }

  void _syncSentenceWithMediaPosition(Duration currentPos) {
    if (_currentIndex < 0 || _currentIndex >= _sentences.length) return;
    final shouldAdvance =
        _shouldAdvanceAtSentenceEnd(currentPos, _sentences[_currentIndex]);
    final action = _sentenceEndActionPlanner.plan(
      isShadowingMode: _shadowing.isMode,
      isShadowingBusy: _shadowing.busy,
      isPlaying: _isPlaying,
      isSeeking: _isSeeking,
      shouldAdvanceAtSentenceEnd: shouldAdvance,
    );
    if (action == SentenceEndAction.runShadowingStep) {
      unawaited(_runShadowingStep());
      return;
    }
    if (action == SentenceEndAction.handleSentenceEnd) {
      unawaited(_handleSentenceEnd());
      return;
    }

    final bounds = _lessonBoundsForIndex(_currentIndex);
    final matchedIndex = _sentencePositionMatcher.findIndexInBounds(
      position: currentPos,
      sentences: _sentences,
      start: bounds.start,
      end: bounds.end,
    );
    if (matchedIndex != null && _currentIndex != matchedIndex) {
      if (_shouldHoldManualSeekIndex(matchedIndex)) return;
      _applyState(() {
        _currentIndex = matchedIndex;
      });
      _lessonLastSentenceIndex[_lessonKeyAt(matchedIndex)] = matchedIndex;
      unawaited(_persistLearningResume());
      unawaited(_recordPracticeForIndex(matchedIndex));
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
    _previewControllerCacheService.clear(
      previewControllerCache: _previewControllerCache,
      previewControllerLoading: _previewControllerLoading,
    );
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
    if (_shadowing.isMode && _shadowing.busy) return;
    _controlsAutoHideTimer = Timer(_controlsAutoHideDelay, () {
      if (!mounted) return;
      if (!_isPlaying) return;
      if (_isSeeking || _isHorizontalDragging || _isSentenceSwitching) return;
      if (_shadowing.isMode && _shadowing.busy) return;
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

  void _applyState(VoidCallback change) {
    if (mounted) {
      setState(change);
    } else {
      change();
    }
  }

  void _toggleShadowingMode() {
    if (_shadowing.isMode) {
      unawaited(_exitShadowingMode());
      return;
    }
    setState(() {
      _shadowingStateController.activateMode();
    });
    if (!_isPlaying) {
      unawaited(_playCurrentMedia());
    }
    _onUserInteraction();
  }

  Future<void> _exitShadowingMode() async {
    await _cancelShadowingStep(keepMode: false);
    _clearHorizontalPreview();
    _applyState(() {
      _shadowingStateController.deactivateMode();
      _isSeeking = false;
      _seekProgress = 0;
    });
  }

  void _toggleShadowingLock() {
    if (_shadowing.locked) {
      unawaited(_exitShadowingMode());
      return;
    }
    if (!_shadowing.isMode) return;
    _applyState(() {
      _shadowingStateController.lockMode();
    });
  }

  void _startShadowingCountdown(Duration total) {
    _shadowingTicker?.cancel();
    _shadowingStateController.setRemaining(total);
    _shadowingTicker =
        Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted) return;
      final next = _shadowing.remaining - const Duration(milliseconds: 200);
      setState(() {
        _shadowingStateController.setRemaining(
          next.isNegative ? Duration.zero : next,
        );
      });
      if (_shadowing.remaining <= Duration.zero) {
        timer.cancel();
      }
    });
  }

  Future<void> _runShadowingStep() async {
    if (!_shadowing.isMode || _shadowing.busy) return;
    if (_currentIndex < 0 || _currentIndex >= _sentences.length) return;
    final sessionId = _shadowingSessionId;
    final sentence = _sentences[_currentIndex];
    final shouldContinue = _isPlaying;
    final sentenceDuration = sentence.endTime - sentence.startTime;

    await _shadowingStepController.runStep(
      autoRecord: _autoRecord,
      shouldContinuePlayback: shouldContinue,
      currentIndex: _currentIndex,
      sentenceCount: _sentences.length,
      sentenceId: sentence.id,
      sentenceDuration: sentenceDuration,
      playbackSpeed: _playbackSpeed,
      isActive: () => _shadowing.isMode && sessionId == _shadowingSessionId,
      pauseCurrentMedia: _pauseCurrentMedia,
      playCurrentMedia: _playCurrentMedia,
      seekToSentence: _seekToSentence,
      startCountdown: _startShadowingCountdown,
      stopCountdown: () => _shadowingTicker?.cancel(),
      stopRecordingIfNeeded: _stopShadowingRecordingIfNeeded,
      onEnterRecordingPhase: () {
        _applyState(() {
          _shadowingStateController.enterRecordingPhase();
        });
      },
      onRecordingStarted: () {
        _applyState(() {
          _shadowingStateController.setRecording(true);
        });
      },
      onWarning: (warning) {
        if (!mounted) return;
        _applyState(() {
          _loadWarning = warning;
        });
      },
      onEnterAdvancingPhase: () {
        _applyState(() {
          _shadowingStateController.setPhase(ShadowingPhase.advancing);
        });
      },
      onReachedEnd: () {
        _applyState(() {
          _isPlaying = false;
          _cacheCurrentLessonPlayingState();
          _shadowingStateController.setPhase(ShadowingPhase.listening);
        });
      },
      onResumePlaybackIntent: () {
        _applyState(() {
          _isPlaying = true;
          _cacheCurrentLessonPlayingState();
        });
      },
      onFinalize: () {
        _clearHorizontalPreview();
        _applyState(() {
          _shadowingStateController.finalizeStepState();
          _isSeeking = false;
          _seekProgress = 0;
        });
      },
    );
  }

  Future<void> _pauseCurrentMedia() async {
    await _mediaPlaybackService.pause(
      isAudioMode: _isAudioMode,
      audioPlayer: _audioPlayer,
      videoController: _videoController,
    );
    _applyState(() {
      _isPlaying = false;
      _cacheCurrentLessonPlayingState();
    });
    if (mounted) {
      _syncControlsVisibilityWithPlayback();
    }
  }

  Future<void> _playCurrentMedia() async {
    await _mediaPlaybackService.play(
      isAudioMode: _isAudioMode,
      audioPlayer: _audioPlayer,
      videoController: _videoController,
    );
    _applyState(() {
      _isPlaying = true;
      _cacheCurrentLessonPlayingState();
    });
    if (mounted) {
      _syncControlsVisibilityWithPlayback();
    }
  }

  Future<void> _stopShadowingRecordingIfNeeded() async {
    if (!_shadowing.recording) return;
    await _shadowingAutoRecordService.stop();
    _applyState(() {
      _shadowingStateController.setRecording(false);
    });
  }

  Future<void> _cancelShadowingStep({required bool keepMode}) async {
    _shadowingSessionId++;
    _shadowingTicker?.cancel();
    await _stopShadowingRecordingIfNeeded();
    _applyState(() {
      _shadowingStateController.resetStepState(keepMode: keepMode);
    });
  }

  void _togglePlay() async {
    if (_isTogglingPlay) return;
    if (_shadowing.isMode && _shadowing.locked) {
      return;
    }
    if (_shadowing.isMode && _shadowing.busy) {
      await _cancelShadowingStep(keepMode: true);
    }
    final shouldPlay = !_isPlaying;
    setState(() {
      _isPlaying = shouldPlay;
      _cacheCurrentLessonPlayingState();
    });
    _isTogglingPlay = true;
    try {
      await _mediaPlaybackService.setPlaying(
        shouldPlay: shouldPlay,
        isAudioMode: _isAudioMode,
        audioPlayer: _audioPlayer,
        videoController: _videoController,
      );
      final actualPlaying = _mediaPlaybackService.actualPlaying(
        isAudioMode: _isAudioMode,
        audioPlayer: _audioPlayer,
        videoController: _videoController,
      );
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

  Future<void> _seekByProgress(double progress) async {
    await _mediaPlaybackService.seekByProgress(
      progress: progress,
      isAudioMode: _isAudioMode,
      audioDuration: _audioDuration,
      audioPlayer: _audioPlayer,
      videoController: _videoController,
    );
  }

  Duration? _durationForProgress(double progress) {
    return _mediaPlaybackService.durationForProgress(
      progress: progress,
      isAudioMode: _isAudioMode,
      audioDuration: _audioDuration,
      videoController: _videoController,
    );
  }

  void _syncSentenceIndexAfterSeek(Duration target) {
    if (_sentences.isEmpty) return;
    if (_currentIndex < 0 || _currentIndex >= _sentences.length) return;
    final bounds = _lessonBoundsForIndex(_currentIndex);
    int matched = bounds.end;
    for (int i = bounds.start; i <= bounds.end; i++) {
      final s = _sentences[i];
      if (target >= s.startTime && target < s.endTime) {
        matched = i;
        break;
      }
    }

    if (matched != _currentIndex && mounted) {
      setState(() {
        _currentIndex = matched;
      });
      _lessonLastSentenceIndex[_lessonKeyAt(matched)] = matched;
      _cacheCurrentLessonPlayingState();
      unawaited(_persistLearningResume());
      unawaited(_recordPracticeForIndex(matched));
      return;
    }
    _lessonLastSentenceIndex[_lessonKeyAt(matched)] = matched;
  }

  void _onSeekStart(double progress) {
    if (_shadowing.isMode) return;
    if (_shadowing.busy) {
      unawaited(_cancelShadowingStep(keepMode: true));
    }
    setState(() {
      _isScrubbingProgressBar = true;
      _isSeeking = true;
      _seekProgress = progress.clamp(0.0, 1.0);
    });
    _onUserInteraction();
  }

  void _onSeekUpdate(double progress) {
    if (_shadowing.isMode) return;
    if (!_isSeeking) return;
    setState(() {
      _seekProgress = progress.clamp(0.0, 1.0);
    });
    _onUserInteraction();
  }

  Future<void> _onSeekEnd(double _) async {
    if (_shadowing.isMode) return;
    if (!_isSeeking) return;
    final target = _seekProgress;
    await _commitSeekAtProgress(target);
  }

  Future<void> _onSeekTap(double progress) async {
    if (_shadowing.isMode) return;
    final target = progress.clamp(0.0, 1.0);
    setState(() {
      _isSeeking = true;
      _seekProgress = target;
    });
    _onUserInteraction();
    await _commitSeekAtProgress(target);
  }

  Future<void> _commitSeekAtProgress(double target) async {
    await _seekByProgress(target);
    final targetDuration = _durationForProgress(target);
    if (targetDuration != null) {
      _armManualSeekProtection(targetDuration);
      _syncSentenceIndexAfterSeek(targetDuration);
    }
    if (!mounted) return;
    setState(() {
      _isScrubbingProgressBar = false;
      _isSeeking = false;
      _seekProgress = target;
    });
    _scheduleControlsAutoHide();
  }

  void _onSeekInteractionStart() {
    if (_isScrubbingProgressBar) return;
    if (!mounted) return;
    setState(() {
      _isScrubbingProgressBar = true;
    });
    _onUserInteraction();
  }

  void _onSeekInteractionEnd() {
    if (!_isScrubbingProgressBar) return;
    if (!mounted) return;
    setState(() {
      _isScrubbingProgressBar = false;
    });
    _scheduleControlsAutoHide();
  }

  void _handleNext() {
    if (_shadowing.isMode) return;
    final nextIndex = _currentIndex + 1;
    if (nextIndex < _sentences.length) {
      _seekToSentence(nextIndex);
    }
    _onUserInteraction();
  }

  void _handlePrevious() {
    if (_shadowing.isMode) return;
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
    if (_shadowing.isMode || _isScrubbingProgressBar) return;
    _isHorizontalDragging = true;
    _onUserInteraction();
  }

  void _onGlobalHorizontalDragUpdate(DragUpdateDetails details) {
    if (_shadowing.isMode || _isScrubbingProgressBar) return;
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
    if (_shadowing.isMode || _isScrubbingProgressBar) return;
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
    if (_isScrubbingProgressBar) return;
    _isHorizontalDragging = false;
    _settleHorizontalPreview();
    _scheduleControlsAutoHide();
  }

  void _armManualSeekProtection(Duration target) {
    final expected = _matchSentenceInCurrentLesson(target);
    if (expected == null) {
      _manualSeekExpectedIndex = null;
      _manualSeekProtectUntil = null;
      return;
    }
    _manualSeekExpectedIndex = expected;
    _manualSeekProtectUntil = DateTime.now().add(
      const Duration(seconds: 2),
    );
  }

  int? _matchSentenceInCurrentLesson(Duration target) {
    if (_currentIndex < 0 || _currentIndex >= _sentences.length) return null;
    final bounds = _lessonBoundsForIndex(_currentIndex);
    for (int i = bounds.start; i <= bounds.end; i++) {
      final s = _sentences[i];
      if (target >= s.startTime && target < s.endTime) {
        return i;
      }
    }
    return bounds.end;
  }

  bool _shouldHoldManualSeekIndex(int matchedIndex) {
    final expected = _manualSeekExpectedIndex;
    final until = _manualSeekProtectUntil;
    if (expected == null || until == null) return false;
    if (DateTime.now().isAfter(until)) {
      _manualSeekExpectedIndex = null;
      _manualSeekProtectUntil = null;
      return false;
    }
    if (expected < 0 || expected >= _sentences.length) {
      _manualSeekExpectedIndex = null;
      _manualSeekProtectUntil = null;
      return false;
    }
    if (matchedIndex >= expected) {
      _manualSeekExpectedIndex = null;
      _manualSeekProtectUntil = null;
      return false;
    }
    // During manual seek settling, prevent automatic sync from snapping back
    // to the previous sentence due to keyframe-aligned positions.
    return _lessonKeyAt(matchedIndex) == _lessonKeyAt(expected);
  }

  List<int> _computeLessonStartIndicesFromKeys(List<String> lessonKeys) {
    if (lessonKeys.isEmpty) return const [0];
    final starts = <int>[0];
    for (int i = 1; i < lessonKeys.length; i++) {
      if (lessonKeys[i] != lessonKeys[i - 1]) {
        starts.add(i);
      }
    }
    return starts;
  }

  int _lessonPageForSentenceIndex(List<int> starts, int sentenceIndex) {
    return _lessonIndexService.lessonPageForSentenceIndex(
      lessonStartIndices: starts,
      sentenceIndex: sentenceIndex,
    );
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
    return _lessonKeyService.keyFromSentence(
      sentence,
      fallbackPackageRoot: _currentPackageRoot,
    );
  }

  String _lessonKeyAt(int index) {
    if (index >= 0 && index < _lessonKeys.length) {
      return _lessonKeys[index];
    }
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
    return _lessonIndexService.boundsForIndex(
      lessonKeys: _lessonKeys,
      index: index,
    );
  }

  Future<VideoPlayerController?> _ensurePreviewControllerForIndex(
    int index,
  ) async {
    final sentence = _sentences[index];
    final path = (sentence.mediaPath ?? '').trim();
    final mediaType = (sentence.mediaType ?? '').toLowerCase();
    final useAudio = _isAudioMedia(mediaType: mediaType, mediaPath: path);
    return _previewControllerCacheService.ensureControllerForIndex(
      index: index,
      useAudio: useAudio,
      mediaPath: path,
      seekTo: sentence.startTime,
      volume: _volume,
      playbackSpeed: _playbackSpeed,
      isMounted: mounted,
      previewControllerCache: _previewControllerCache,
      previewControllerLoading: _previewControllerLoading,
    );
  }

  Future<void> _warmAdjacentLessonPreviews() async {
    if (_sentences.isEmpty || _lessonStartIndices.isEmpty) return;
    final keep = _lessonPreviewPlanner.keepIndices(
      currentPage: _currentLessonPage,
      pageCount: _lessonStartIndices.length,
      sentenceIndexForPage: _targetSentenceIndexForLessonPage,
    );
    if (keep.isEmpty) return;
    for (final index in keep) {
      await _ensurePreviewControllerForIndex(index);
    }
    final stale = _lessonPreviewPlanner.staleIndices(
      cachedIndices: _previewControllerCache.keys,
      keepIndices: keep,
    );
    _previewControllerCacheService.disposeStale(
      previewControllerCache: _previewControllerCache,
      staleIndices: stale,
    );
  }

  ({int indexInLesson, int totalInLesson}) _lessonProgressForIndex(int index) {
    return _lessonIndexService.progressForIndex(
      lessonKeys: _lessonKeys,
      index: index,
    );
  }

  ({int indexInLesson, int totalInLesson}) _headerProgressForCurrentLesson() {
    if (_sentences.isEmpty || _lessonStartIndices.isEmpty) {
      return _lessonProgressForIndex(_currentIndex);
    }
    final displayIndex = _lessonHeaderProgressService.displaySentenceIndex(
      currentLessonPage: _currentLessonPage,
      lessonStartIndices: _lessonStartIndices,
      lessonKeys: _lessonKeys,
      lessonLastSentenceIndex: _lessonLastSentenceIndex,
    );
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
    final targetSentenceIndex = _targetSentenceIndexForLessonPage(page);
    final plan = _lessonPageChangePlanner.plan(
      page: page,
      pageCount: _lessonStartIndices.length,
      isProgrammaticPageJump: _isProgrammaticPageJump,
      currentSentenceIndex: _currentIndex,
      targetSentenceIndex: targetSentenceIndex,
    );

    if (plan.action == LessonPageChangeAction.ignore) return;

    _clearHorizontalPreview();
    if (plan.action == LessonPageChangeAction.warmPreviewsOnly) {
      unawaited(_warmAdjacentLessonPreviews());
      return;
    }
    final seekTarget = plan.targetSentenceIndex;
    if (seekTarget == null) return;
    await _seekToSentence(seekTarget);
  }

  int _targetSentenceIndexForLessonPage(int page) {
    return _lessonIndexService.targetSentenceIndexForLessonPage(
      page: page,
      lessonStartIndices: _lessonStartIndices,
      lessonKeys: _lessonKeys,
      lessonLastSentenceIndex: _lessonLastSentenceIndex,
    );
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

  String? _previousLessonKey() {
    if (_currentIndex < 0 || _currentIndex >= _sentences.length) return null;
    return _lessonKeyAt(_currentIndex);
  }

  void _prepareSentenceSeekTransition({
    required int index,
    required bool preservePlayingState,
    required bool markSwitching,
  }) {
    _applyState(() {
      _horizontalDragOffset = 0;
      _horizontalPreviewIndex = null;
      if (markSwitching) {
        _isSentenceSwitching = true;
      }
      _currentIndex = index;
      if (!preservePlayingState) {
        _isPlaying = _playingStateForIndex(index);
      }
    });
  }

  Future<bool> _seekActiveMediaTo(Duration target) async {
    if (_isAudioMode) {
      await _audioPlayer.seek(target);
      return true;
    }
    if (_videoController.value.isInitialized) {
      await _videoController.seekTo(target);
      return true;
    }
    return false;
  }

  bool _finalizeSentenceSeekIfCurrentRequest({
    required int index,
    required Duration seekTarget,
    required String? previousLessonKey,
    required int requestToken,
  }) {
    if (!mounted || requestToken != _seekRequestToken) return false;
    _syncAfterSentenceSeek(
      index: index,
      seekTarget: seekTarget,
      previousLessonKey: previousLessonKey,
    );
    return true;
  }

  Future<bool> _performSentenceSeek({
    required int index,
    required bool preservePlayingState,
    required bool markSwitching,
    Future<void> Function(SentenceDetail sentence, int requestToken)?
        beforeSeek,
    void Function(int requestToken)? onFinally,
  }) async {
    if (index < 0 || index >= _sentences.length) return false;
    final requestToken = ++_seekRequestToken;
    final previousLessonKey = _previousLessonKey();
    final sentence = _sentences[index];

    return _sentenceSeekCoordinator.perform(
      index: index,
      sentenceCount: _sentences.length,
      prepareTransition: () {
        _prepareSentenceSeekTransition(
          index: index,
          preservePlayingState: preservePlayingState,
          markSwitching: markSwitching,
        );
      },
      beforeSeek:
          beforeSeek == null ? null : () => beforeSeek(sentence, requestToken),
      isRequestCurrent: () => mounted && requestToken == _seekRequestToken,
      seekActiveMedia: () => _seekActiveMediaTo(sentence.startTime),
      finalizeSeek: () {
        _finalizeSentenceSeekIfCurrentRequest(
          index: index,
          seekTarget: sentence.startTime,
          previousLessonKey: previousLessonKey,
          requestToken: requestToken,
        );
      },
      onFinally: onFinally == null ? null : () => onFinally(requestToken),
    );
  }

  Future<void> _seekToSentence(
    int index, {
    bool preservePlayingState = false,
  }) async {
    await _performSentenceSeek(
      index: index,
      preservePlayingState: preservePlayingState,
      markSwitching: true,
      beforeSeek: (sentence, requestToken) async {
        await _switchMedia(
          sentence.mediaPath,
          mediaType: sentence.mediaType,
          // Seek once after media selection to avoid duplicate seek jitter.
          seekTo: null,
          requestToken: requestToken,
        );
      },
      onFinally: (requestToken) {
        if (mounted &&
            requestToken == _seekRequestToken &&
            _isSentenceSwitching) {
          setState(() {
            _isSentenceSwitching = false;
          });
        }
      },
    );
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

  void _resetLessonPlaybackProgress({
    required String lessonKey,
    required int lessonStartIndex,
  }) {
    if (_sentences.isEmpty) return;
    if (lessonStartIndex < 0 || lessonStartIndex >= _sentences.length) return;
    if (_lessonKeyAt(lessonStartIndex) != lessonKey) return;

    _lessonLastSentenceIndex[lessonKey] = lessonStartIndex;
    _lessonLastMediaPosition[lessonKey] = Duration.zero;
    _lessonPlayingState[lessonKey] = false;
  }

  bool _isAudioSentence(SentenceDetail sentence) {
    return _isAudioMedia(
      mediaType: sentence.mediaType,
      mediaPath: (sentence.mediaPath ?? '').trim(),
    );
  }

  bool _isAudioMedia({
    String? mediaType,
    String? mediaPath,
    String? lowerPath,
  }) {
    final normalizedType = (mediaType ?? '').toLowerCase();
    if (normalizedType == 'audio') return true;
    final normalizedPath = lowerPath ?? (mediaPath ?? '').toLowerCase();
    return normalizedPath.endsWith('.mp3') ||
        normalizedPath.endsWith('.aac') ||
        normalizedPath.endsWith('.wav') ||
        normalizedPath.endsWith('.m4a');
  }

  Future<bool> _advanceWithinCurrentMediaWithoutSeek(int index) async {
    if (index < 0 || index >= _sentences.length) return false;
    if (_currentIndex < 0 || _currentIndex >= _sentences.length) return false;
    final current = _sentences[_currentIndex];
    final next = _sentences[index];
    final currentPath = (current.mediaPath ?? '').trim();
    final nextPath = (next.mediaPath ?? '').trim();
    if (currentPath.isEmpty || nextPath.isEmpty) return false;
    if (currentPath != nextPath) return false;
    if (_isAudioSentence(current) != _isAudioSentence(next)) return false;

    final previousLessonKey = _previousLessonKey();
    _prepareSentenceSeekTransition(
      index: index,
      preservePlayingState: true,
      markSwitching: false,
    );
    _syncAfterSentenceIndexTransition(
      index: index,
      previousLessonKey: previousLessonKey,
    );
    return true;
  }

  Future<bool> _seekWithinCurrentMedia(
    int index, {
    required bool preservePlayingState,
  }) async {
    if (index < 0 || index >= _sentences.length) return false;
    final sentence = _sentences[index];
    final targetPath = (sentence.mediaPath ?? '').trim();
    final currentPath = (_currentMediaPath ?? '').trim();
    if (targetPath.isEmpty || targetPath != currentPath) return false;
    if (_isAudioSentence(sentence) != _isAudioMode) return false;

    return _performSentenceSeek(
      index: index,
      preservePlayingState: preservePlayingState,
      markSwitching: true,
      onFinally: (_) => _isSentenceSwitching = false,
    );
  }

  void _syncAfterSentenceSeek({
    required int index,
    required Duration seekTarget,
    required String? previousLessonKey,
  }) {
    final actualPlaying = _mediaPlaybackService.actualPlaying(
      isAudioMode: _isAudioMode,
      audioPlayer: _audioPlayer,
      videoController: _videoController,
    );
    setState(() {
      _isPlaying = actualPlaying;
    });
    final activeDuration = _mediaPlaybackService.activeDuration(
      isAudioMode: _isAudioMode,
      audioDuration: _audioDuration,
      videoController: _videoController,
    );
    _syncAfterSentenceIndexTransition(
      index: index,
      previousLessonKey: previousLessonKey,
      cachePosition: seekTarget,
      cacheDuration: activeDuration,
    );
  }

  void _syncAfterSentenceIndexTransition({
    required int index,
    required String? previousLessonKey,
    Duration? cachePosition,
    Duration? cacheDuration,
  }) {
    if (cachePosition != null && cacheDuration != null) {
      _cacheMediaStateForLessonIndex(
        index,
        position: cachePosition,
        duration: cacheDuration,
      );
    }
    _lessonLastSentenceIndex[_lessonKeyAt(index)] = index;
    _cacheCurrentLessonPlayingState();
    _syncLessonPageWithCurrentSentence();
    final targetLessonKey = _lessonKeyAt(index);
    final lessonChanged = previousLessonKey != targetLessonKey;
    unawaited(_recordPracticeForIndex(
      index,
      countLessonEntry: lessonChanged,
    ));
    unawaited(_persistLearningResume());
    unawaited(_warmAdjacentLessonPreviews());
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
      return EmptyCourseGuideView(
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
                    physics: _shadowing.isMode
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
                              (_shadowing.isMode && _shadowing.busy)
                          ? 0
                          : 1,
                    ),
                    child: IgnorePointer(
                      ignoring: !pageControlsVisible ||
                          (_shadowing.isMode && _shadowing.busy),
                      child: ShortVideoBottomBar(
                        accentColor: accentColor,
                        progress: _isSeeking ? _seekProgress : mediaProgress,
                        isPlaying: pageIsPlaying,
                        isShadowingMode: _shadowing.isMode,
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
                        onSeekInteractionStart: _onSeekInteractionStart,
                        onSeekInteractionEnd: _onSeekInteractionEnd,
                        isSeekActive: _isSeeking || _isScrubbingProgressBar,
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
              opacity: _safeOpacity(isActivePage && _shadowing.isMode ? 1 : 0),
              child: ShadowingStatusHint(
                isShadowingMode: _shadowing.isMode,
                isRecordingPhase: _shadowing.phase == ShadowingPhase.recording,
                isAdvancingPhase: _shadowing.phase == ShadowingPhase.advancing,
                remaining: _shadowing.remaining,
                locked: _shadowing.locked,
                onToggleLock: _toggleShadowingLock,
              ),
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

  Future<void> _openCourseUnitPicker() async {
    if (_sentences.isEmpty) return;
    final courses = await buildCourseUnitPickerCourses(
      sentences: _sentences,
      currentIndex: _currentIndex,
      currentPackageRoot: _currentPackageRoot,
      currentCourseTitle: _currentCourseTitle,
      loadCourseCatalogsOverride: widget.loadCourseCatalogsOverride,
    );
    if (!mounted || courses.isEmpty) return;
    final currentPackage =
        (_currentPackageRoot ?? _sentences[_currentIndex].packageRoot ?? '')
            .trim();
    final currentLessonKey = _lessonKeyAt(_currentIndex);

    final selection = await showCourseUnitPickerSheet(
      context,
      courses: courses,
      currentPackageRoot: currentPackage,
      currentLessonKey: currentLessonKey,
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
    await showPracticePlaybackSettingsSheet(context);
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
