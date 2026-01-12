import 'dart:async'; // Import dart:async
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart'; // Import foundation for kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart'; // Import just_audio
import 'package:audio_waveforms/audio_waveforms.dart'; // Import audio_waveforms
import 'package:path_provider/path_provider.dart'; // Import path_provider
import '../data/mock_data.dart';
import '../domain/sentence_detail.dart';
import '../../../routing/routes.dart';
import 'widgets/practice_controls.dart'; // Import PracticeControls widget

class SentencePracticeScreen extends ConsumerStatefulWidget {
  final String sentenceId;

  const SentencePracticeScreen({
    super.key,
    required this.sentenceId,
  });

  @override
  ConsumerState<SentencePracticeScreen> createState() =>
      _SentencePracticeScreenState();
}

class _SentencePracticeScreenState
    extends ConsumerState<SentencePracticeScreen> {
  // Data
  final List<SentenceDetail> _sentences = mockSentences;
  int _currentIndex = 0;

  bool _isTranslationVisible = false;
  late VideoPlayerController _videoController;
  late AudioPlayer _audioPlayer; // Audio Player logic (JustAudio)
  PlayerController? _waveformController; // Waveform visualization (Nullable)

  bool _isPlaying = false;
  bool _isRecording = false;

  // Controls Visibility State
  bool _controlsVisible = true;
  Timer? _hideTimer;

  // Waveform State
  bool _isWaveformReady = false;

  @override
  void initState() {
    super.initState();
    // Initialize current index based on sentenceId if needed, defaulting to 0
    // _currentIndex = _sentences.indexWhere((s) => s.id == widget.sentenceId);
    // if (_currentIndex == -1) _currentIndex = 0;

    // Video setup
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4'),
    )..initialize().then((_) {
        setState(() {});
        // _videoController.play(); // Auto-play disabled to test controls
        _videoController.setLooping(true);
        // Turn on listener for progress
        _videoController.addListener(_syncSentenceWithVideo);
      });

    // Audio Player setup
    _audioPlayer = AudioPlayer();
    _initAudio();

    // Waveform Controller Setup (Only on native)
    if (!kIsWeb) {
      _waveformController = PlayerController();
      _prepareWaveform();
    }

    // Start timer initially if playing (optional, here we start visible)
    _startHideTimer();
  }

  Future<void> _prepareWaveform() async {
    if (kIsWeb) return;
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final File tempFile = File('${tempDir.path}/practice_audio.mp3');

      // Download if not exists (or always overwrite for demo)
      // For demo, we use HttpClient to download
      if (!await tempFile.exists()) {
        final request = await HttpClient().getUrl(Uri.parse(
            'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3'));
        final response = await request.close();
        await response.pipe(tempFile.openWrite());
      }

      await _waveformController?.preparePlayer(
        path: tempFile.path,
        noOfSamples: 100, // Reduced samples for smoother look on mobile width
        shouldExtractWaveform: true,
      );

      setState(() {
        _isWaveformReady = true;
      });
    } catch (e) {
      debugPrint("Error preparing waveform: $e");
    }
  }

  void _syncSentenceWithVideo() {
    if (!_videoController.value.isInitialized) return;

    final currentPos = _videoController.value.position;
    // debugPrint("Syncing: $currentPos matched index $_currentIndex");

    // Sync Waveform Visualization
    // Note: Calling seek on PlayerController frequently might be heavy?
    // AudioWaveforms PlayerController doesn't have a simple "set visual position" without seeking.
    // Ideally we assume they play in sync if we started them together, but since we use just_audio/video_player,
    // we might just need to verify drift.
    // _waveformController.seekTo(currentPos.inMilliseconds); // This might conflict if it tries to play sound?
    // Actually AudioFileWaveforms is a Player. If we don't call .play() on it, maybe seekTo just moves the cursor?
    // Yes, seekTo moves cursor.
    // Limit updates to UI frames or meaningful changes to avoid stutter.
    // For now, let's try syncing it.
    if (_isWaveformReady) {
      // Only seek if difference is significant to avoid jitter
      // _waveformController?.seekTo(currentPos.inMilliseconds);
    }
    // NOTE: seekTo often triggers native channel calls.
    // A better approach for purely visual might be finding a way to drive the scroll controller of the widget,
    // but the package hides it.
    // Let's try simple update.
    // _waveformController.seekTo(currentPos.inMilliseconds);

    // Simple linear check or optimized binary search if list is huge.
    // Given < 100 sentences, linear is fine.
    for (int i = 0; i < _sentences.length; i++) {
      final s = _sentences[i];
      // Check if currentPos is within start/end range
      if (currentPos >= s.startTime && currentPos < s.endTime) {
        if (_currentIndex != i) {
          setState(() {
            _currentIndex = i;
            // Also reset translation visibility when changing sentence?
            _isTranslationVisible = false;
          });
        }
        break;
      }
    }
  }

  Future<void> _initAudio() async {
    try {
      // Mock audio loading. Replace with actual URL from _sentence or equivalent
      await _audioPlayer.setUrl(
          'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3');
      // Listen to player state
      _audioPlayer.playerStateStream.listen((state) {
        // If playing state changed
        if (_isPlaying != state.playing) {
          setState(() {
            _isPlaying = state.playing;
          });
          if (_isPlaying) {
            _startHideTimer();
            // Also play waveform controller if we want it to animate smoothly?
            // If we play it, we get audio doubling.
            // _waveformController.startPlayer(); // DONT DO THIS unless we mute it.
            // But PlayerController doesn't expose volume control easily in preparePlayer?
            // Actually it does: _waveformController.setVolume(0.0)
          } else {
            _cancelHideTimer();
            setState(() => _controlsVisible = true); // Always show when paused
            // _waveformController.pausePlayer();
          }
        }
      });
    } catch (e) {
      debugPrint("Error loading audio: $e");
    }
  }

  @override
  void dispose() {
    _cancelHideTimer();
    _stopWaveformSync();
    _videoController.removeListener(_syncSentenceWithVideo);
    _videoController.dispose();
    _audioPlayer.dispose();
    _waveformController?.dispose();
    super.dispose();
  }

  void _cancelHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  void _startHideTimer() {
    _cancelHideTimer();
    // Only auto-hide if playing
    if (!_isPlaying) return;

    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _controlsVisible = false;
        });
      }
    });
  }

  // Call this when user interacts with controls
  void _onUserInteraction() {
    setState(() => _controlsVisible = true);
    _startHideTimer();
  }

  void _toggleTranslation() {
    setState(() {
      _isTranslationVisible = !_isTranslationVisible;
    });
    _onUserInteraction();
  }

  void _togglePlay() {
    if (_isPlaying) {
      _audioPlayer.pause();
      _videoController.pause();
      if (_isWaveformReady) {
        _waveformController?.pausePlayer();
      }
    } else {
      _audioPlayer.play();
      _videoController.play();
      if (_isWaveformReady) {
        // Use audio_waveforms just for visualization but we need it to move.
        // We can play it but mute it?
        // Unfortunately PlayerController doesn't have setVolume easily exposed in 1.0.5?
        // Let's create a sync loop instead of playing two files.
        // Actually, let's keep it simple: Just play it. Video player is mostly visual?
        // VideoPlayer has sound. JustAudio has sound. Waveform has sound. That's 3 sounds!
        // User's request is "draw real waveform".
        // Assuming we can mute the waveform player?
        // _waveformController.setVolume(0) is not available?
        // Let's try to just seek in loop.
      }
    }
    // _isPlaying state is updated by listener, but for immediate UI feedback:
    setState(() {
      _isPlaying = !_isPlaying;
      _controlsVisible = true;
    });
    if (_isPlaying) {
      _startHideTimer();
      _startWaveformSync();
    } else {
      _stopWaveformSync();
    }
  }

  // Custom sync loop for waveform visual
  Timer? _waveformSyncTimer;
  void _startWaveformSync() {
    _waveformSyncTimer?.cancel();
    _waveformSyncTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_isWaveformReady &&
          _videoController.value.isPlaying &&
          _waveformController != null) {
        _waveformController!
            .seekTo(_videoController.value.position.inMilliseconds);
      }
    });
  }

  void _stopWaveformSync() {
    _waveformSyncTimer?.cancel();
  }

  void _toggleRecord() {
    setState(() {
      _isRecording = !_isRecording;
    });
    // Implement actual recording logic here
    if (_isRecording) {
      debugPrint("Started Recording...");
    } else {
      debugPrint("Stopped Recording.");
    }
    _onUserInteraction();
  }

  void _handleNext() {
    final nextIndex = _currentIndex + 1;
    if (nextIndex < _sentences.length) {
      _seekToSentence(nextIndex);
    }
    _onUserInteraction();
  }

  void _handlePrevious() {
    final prevIndex = _currentIndex - 1;
    if (prevIndex >= 0) {
      _seekToSentence(prevIndex);
    }
    _onUserInteraction();
  }

  void _seekToSentence(int index) {
    final s = _sentences[index];
    _videoController.seekTo(s.startTime);
    _audioPlayer.seek(s.startTime); // Assume audio synced
    if (_isWaveformReady) {
      _waveformController?.seekTo(s.startTime.inMilliseconds);
    }
  }

  void _handleReplay5s() {
    // Seek back 5 seconds
    final position =
        _videoController.value.position - const Duration(seconds: 5);
    final newPos = position < Duration.zero ? Duration.zero : position;
    _audioPlayer.seek(newPos);
    _videoController.seekTo(newPos); // Sync video
    if (_isWaveformReady) {
      _waveformController?.seekTo(newPos.inMilliseconds);
    }
    _onUserInteraction();
  }

  void _handlePlayOriginal() {
    // Logic for playing original audio specifically if needed
    _togglePlay();
  }

  @override
  Widget build(BuildContext context) {
    // 提取颜色常量
    const accentColor = Color(0xFFFF9F29); // 橙色
    const grammarBgColor = Color(0xFF2A2723);

    // Get current sentence
    final currentSentence = _sentences[_currentIndex];

    return Scaffold(
      extendBody: true, // Allow body to extend behind bottomNavigationBar
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2E2618), // Deeper dark yellow/brown
              Color(0xFF18140E), // Very dark brown/black at bottom
            ],
          ),
        ),
        child: Column(
          children: [
            // 1. Header (Text safe area handled manually or via wrapper)
            SafeArea(
              bottom: false,
              child: _buildHeader(context, accentColor),
            ),

            // 2. Main Content (Scrollable)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(
                    left: 20.0, right: 20.0, bottom: 120.0),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // Video Area
                    _buildVideoArea(),

                    const SizedBox(height: 12),
                    // Time & Waveform
                    _buildWaveformArea(accentColor),

                    const SizedBox(height: 24),
                    // Sentence Text
                    Text(
                      currentSentence.text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Phonetics
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.volume_up_rounded,
                            color: accentColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          currentSentence.phonetic,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 16,
                            fontFamily: 'Courier',
                          ),
                        ),
                        const SizedBox(width: 8), // Added spacing
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Translation (Hidden/Shown)
                    _buildTranslationArea(accentColor, currentSentence),

                    const SizedBox(height: 24),

                    // Keywords/Tags (Hardcoded for demo based on image)
                    // TODO: Make this dynamic from sentence data if available
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (currentSentence.grammarNotes.isNotEmpty)
                          ...currentSentence.grammarNotes.entries
                              .take(2)
                              .map((e) => Padding(
                                    padding: const EdgeInsets.only(right: 12.0),
                                    child: _buildKeywordChip(
                                        e.key, ''), // Simplified
                                  )),
                      ],
                    ),

                    if (currentSentence.grammarNotes.isNotEmpty)
                      const SizedBox(height: 24),

                    // Grammar Note
                    if (currentSentence.grammarNotes.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: grammarBgColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.lightbulb,
                                    color: accentColor, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'GRAMMAR NOTE',
                                  style: TextStyle(
                                    color: accentColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Display first grammar note logic
                            Text(
                              currentSentence.grammarNotes.values.first,
                              style: const TextStyle(
                                color: Color(0xFFCCCCCC),
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // Floating Bottom Navigation
      bottomNavigationBar: PracticeControls(
        isPlaying: _isPlaying,
        isRecording: _isRecording,
        onPlayPause: _togglePlay,
        onRecord: _toggleRecord,
        onNext: _handleNext,
        onPrevious: _handlePrevious,
        onReplay5s: _handleReplay5s,
        onPlayOriginal: _handlePlayOriginal,
        accentColor: accentColor,
      ),
    );
  }

  Widget _buildVideoArea() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_videoController.value.isInitialized)
              VideoPlayer(_videoController)
            else
              const Center(
                  child: CircularProgressIndicator(color: Colors.orange)),

            // 1. Gesture Detector to Toggle Play/Pause (Covers entire video)
            GestureDetector(
              onTap: _togglePlay,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent), // Expand to fill
            ),

            // 2. Animated Controls Layer
            AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _controlsVisible ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Dim Overlay
                    Container(
                      color: Colors.black.withOpacity(0.2),
                    ),

                    // Center Play Button
                    GestureDetector(
                      onTap: _togglePlay,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withOpacity(0.5), width: 1),
                        ),
                        child: Icon(
                            _isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 40),
                      ),
                    ),

                    // Top Right Icons
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              _onUserInteraction();
                              context.push(Routes.playbackSettings);
                            },
                            child: _buildVideoActionIcon(Icons.settings),
                          ),
                          const SizedBox(width: 12),
                          _buildVideoActionIcon(Icons.subtitles_off),
                        ],
                      ),
                    ),

                    // Bottom Progress Bar
                    Positioned(
                      bottom: 12,
                      left: 16,
                      right: 16,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          height: 6,
                          child: VideoProgressIndicator(
                            _videoController,
                            allowScrubbing: true,
                            colors: const VideoProgressColors(
                              playedColor: Color(0xFFFF9F29),
                              bufferedColor: Colors.white24,
                              backgroundColor: Colors.white10,
                            ),
                            padding: EdgeInsets
                                .zero, // Remove internal padding to fill SizedBox
                          ),
                        ),
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

  Widget _buildVideoActionIcon(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  Widget _buildWaveformArea(Color accentColor) {
    final currentPosStr = _formatDuration(_videoController.value.position);
    final totalDurStr = _formatDuration(_videoController.value.duration);

    return Column(
      children: [
        // Timestamps
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(currentPosStr,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              Text(totalDurStr,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Waveform
        SizedBox(
          height: 60,
          child: Center(
            child: (!kIsWeb && _isWaveformReady && _waveformController != null)
                ? AudioFileWaveforms(
                    size: Size(MediaQuery.of(context).size.width, 60),
                    playerController: _waveformController!,
                    enableSeekGesture: false, // Driven by video
                    waveformType: WaveformType.fitWidth,
                    playerWaveStyle: PlayerWaveStyle(
                      fixedWaveColor: Colors.white.withOpacity(0.3),
                      liveWaveColor: accentColor,
                      spacing: 4,
                      waveThickness: 2,
                      showSeekLine: false,
                    ),
                  )
                : kIsWeb
                    ? const Text("Waveform not supported on Web",
                        style: TextStyle(color: Colors.grey))
                    : const CircularProgressIndicator(
                        color: Colors.orange, strokeWidth: 2),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  Widget _buildTranslationArea(
      Color accentColor, SentenceDetail currentSentence) {
    return GestureDetector(
      onTap: _toggleTranslation,
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: _isTranslationVisible
            ? null
            : BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.02),
                  width: 1,
                ),
              ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Blurred/Revealed Translation Text
            ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: _isTranslationVisible ? 0 : 8,
                sigmaY: _isTranslationVisible ? 0 : 8,
              ),
              child: Text(
                currentSentence.translation,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _isTranslationVisible
                      ? accentColor
                      : Colors.white.withOpacity(0.2), // Fainter when blurred
                  fontSize: 16, // Smaller font
                ),
              ),
            ),

            // Hint Text & Icon (Only visible when translation hidden)
            if (!_isTranslationVisible)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.visibility_off_outlined,
                      color: Colors.white.withOpacity(0.5), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    '点击显示翻译',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 13,
                      fontWeight: FontWeight.normal, // Removed bold
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeywordChip(String eng, String cn) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2723),
        borderRadius: BorderRadius.circular(8),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: eng,
              style: const TextStyle(
                  color: Color(0xFFFF9F29), fontWeight: FontWeight.bold),
            ),
            if (cn.isNotEmpty) ...[
              const TextSpan(text: '  '),
              TextSpan(
                text: cn,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Close Button
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey),
            onPressed: () => context.pop(),
          ),

          // Center: Title + Progress Text
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Friends S01E01",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "第 ${_currentIndex + 1} / ${_sentences.length} 句",
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),

          // Right: Menu Icon
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.menu_rounded, color: Colors.grey),
              onPressed: () {
                // Placeholder action
                debugPrint("Menu tapped");
              },
            ),
          ),
        ],
      ),
    );
  }
}
