import 'dart:async'; // Import dart:async
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
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
  // late AudioPlayer _audioPlayer; // Not using separate audio - using video audio
  // Controls Visibility State
  bool _isPlaying = false;
  bool _isRecording = false;

  bool _controlsVisible = true;
  Timer? _hideTimer;

  // Video Controls State
  double _volume = 1.0;
  double _previousVolume = 1.0; // For mute toggle
  double _playbackSpeed = 1.0;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    // Initialize current index based on sentenceId if needed, defaulting to 0
    // _currentIndex = _sentences.indexWhere((s) => s.id == widget.sentenceId);
    // if (_currentIndex == -1) _currentIndex = 0;

    // Video setup
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(
          'https://storage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4'),
    )..initialize().then((_) {
        setState(() {});
        // _videoController.play(); // Auto-play disabled to test controls
        _videoController.setLooping(true);
        // Turn on listener for progress
        _videoController.addListener(_syncSentenceWithVideo);
      });

    // Audio Player setup (using video audio instead)
    // _audioPlayer = AudioPlayer();
    // _initAudio();

    // Waveform Controller Setup (removed)
    // if (!kIsWeb) {
    //   _waveformController = PlayerController();
    //   _prepareWaveform();
    // }

    // Start timer initially if playing (optional, here we start visible)
    _startHideTimer();
  }

  // Waveform preparation removed
  // Future<void> _prepareWaveform() async { ... }

  void _syncSentenceWithVideo() {
    if (!_videoController.value.isInitialized) return;

    final currentPos = _videoController.value.position;
    // debugPrint("Syncing: $currentPos"); // Uncomment for verbose logs

    // Simple linear check
    for (int i = 0; i < _sentences.length; i++) {
      final s = _sentences[i];
      if (currentPos >= s.startTime && currentPos < s.endTime) {
        if (_currentIndex != i) {
          debugPrint("Scrub sync: Jumped to sentence $i at $currentPos");
          setState(() {
            _currentIndex = i;
            _isTranslationVisible = false;
          });
        }
        break;
      }
    }
  }

  Future<void> _initAudio() async {
    // Using video audio instead of separate audio player
    // Audio is handled by VideoPlayerController
    return;
    /*
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
          } else {
            _cancelHideTimer();
            setState(() => _controlsVisible = true); // Always show when paused
          }
        }
      });
    } catch (e) {
      debugPrint("Error loading audio: $e");
    }
    */
  }

  @override
  void dispose() {
    _cancelHideTimer();
    // _stopWaveformSync(); // Waveform removed
    _videoController.removeListener(_syncSentenceWithVideo);
    _videoController.dispose();
    // _audioPlayer.dispose(); // Not using separate audio player
    // _waveformController?.dispose(); // Waveform removed
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
      // _audioPlayer.pause();
      _videoController.pause();
      // Waveform removed
    } else {
      // _audioPlayer.play();
      _videoController.play();
      // Waveform removed
    }
    // _isPlaying state is updated by listener, but for immediate UI feedback:
    setState(() {
      _isPlaying = !_isPlaying;
      _controlsVisible = true;
    });
    if (_isPlaying) {
      _startHideTimer();
      // _startWaveformSync(); // Waveform removed
    } else {
      // _stopWaveformSync(); // Waveform removed
    }
  }

  // Waveform sync removed
  // Timer? _waveformSyncTimer;
  // void _startWaveformSync() { ... }

  // void _stopWaveformSync() { ... }

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
    // _audioPlayer.seek(s.startTime); // Not using separate audio
    // Waveform removed
  }

  void _handleReplay5s() {
    // Seek back 5 seconds
    final position =
        _videoController.value.position - const Duration(seconds: 5);
    final newPos = position < Duration.zero ? Duration.zero : position;
    // _audioPlayer.seek(newPos); // Not using separate audio
    _videoController.seekTo(newPos); // Sync video
    // Waveform removed
    _onUserInteraction();
  }

  void _handlePlayOriginal() {
    // Logic for playing original audio specifically if needed
    _togglePlay();
  }

  // Volume Control
  void _setVolume(double value) {
    setState(() {
      _volume = value;
      _previousVolume = value > 0 ? value : _previousVolume;
    });
    _videoController.setVolume(value);
    // _audioPlayer.setVolume(value); // Not using separate audio
    _onUserInteraction();
  }

  void _toggleMute() {
    if (_volume > 0) {
      _setVolume(0);
    } else {
      _setVolume(_previousVolume);
    }
  }

  // Playback Speed Control
  void _setPlaybackSpeed(double speed) {
    setState(() {
      _playbackSpeed = speed;
    });
    _videoController.setPlaybackSpeed(speed);
    // _audioPlayer.setSpeed(speed); // Not using separate audio
    _onUserInteraction();
  }

  // Fullscreen Control
  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
    // Note: Full implementation would require SystemChrome
    // and proper orientation handling
    _onUserInteraction();
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
                            color: accentColor, size: 18),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            currentSentence.phonetic,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 13,
                              fontFamily: 'Courier',
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
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
                    // Dim Overlay with tap to toggle controls
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _controlsVisible = !_controlsVisible;
                        });
                        if (_controlsVisible) {
                          _startHideTimer();
                        }
                      },
                      child: Container(
                        color: Colors.black.withOpacity(0.2),
                      ),
                    ),

                    // Top Right Icons
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              _onUserInteraction();
                              context.push(Routes.playbackSettings);
                            },
                            child: _buildVideoActionIcon(Icons.settings),
                          ),
                          const SizedBox(width: 8),
                          _buildVideoActionIcon(Icons.subtitles_off),
                        ],
                      ),
                    ),

                    // Bottom: Progress Bar + Controls
                    Positioned(
                      bottom: 8,
                      left: 12,
                      right: 12,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Progress bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              height: 4,
                              child: VideoProgressIndicator(
                                _videoController,
                                allowScrubbing: true,
                                colors: const VideoProgressColors(
                                  playedColor: Color(0xFFFF9F29),
                                  bufferedColor: Colors.white24,
                                  backgroundColor: Colors.white10,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Control bar
                          _buildVideoControlBar(),
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
    );
  }

  Widget _buildVideoActionIcon(IconData icon) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            shape: BoxShape.circle,
            border:
                Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: 16),
        ),
      ),
    );
  }

  Widget _buildVideoControlBar() {
    final currentPosStr = _formatDuration(_videoController.value.position);
    final totalDurStr = _formatDuration(_videoController.value.duration);

    return Row(
      children: [
        // Time display
        Text(
          '$currentPosStr / $totalDurStr',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
            fontFamily: 'Courier',
          ),
        ),
        const SizedBox(width: 12),

        // Play/Pause button
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),

        const Spacer(),

        // Volume control
        GestureDetector(
          onTap: _toggleMute,
          child: Icon(
            _volume == 0
                ? Icons.volume_off
                : _volume < 0.5
                    ? Icons.volume_down
                    : Icons.volume_up,
            color: Colors.white.withOpacity(0.9),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),

        // Playback speed
        GestureDetector(
          onTap: () {
            // Cycle through speeds: 1x -> 1.25x -> 1.5x -> 2x -> 0.5x -> 0.75x -> 1x
            final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
            final currentIndex = speeds.indexOf(_playbackSpeed);
            final nextIndex = (currentIndex + 1) % speeds.length;
            _setPlaybackSpeed(speeds[nextIndex]);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _playbackSpeed != 1.0
                  ? const Color(0xFFFF9F29).withOpacity(0.3)
                  : Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${_playbackSpeed}x',
              style: TextStyle(
                color: _playbackSpeed != 1.0
                    ? const Color(0xFFFF9F29)
                    : Colors.white.withOpacity(0.9),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Fullscreen button
        GestureDetector(
          onTap: _toggleFullscreen,
          child: Icon(
            _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
            color: Colors.white.withOpacity(0.9),
            size: 20,
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
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Back Button
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 20),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
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
              const SizedBox(height: 2),
              Text(
                "第 ${_currentIndex + 1} / ${_sentences.length} 句",
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 10,
                ),
              ),
            ],
          ),

          // Right: Text Mode Icon (Book)
          IconButton(
            icon: const Icon(Icons.menu_book_rounded,
                color: Colors.white, size: 22),
            onPressed: () {
              // Placeholder action for text mode
              debugPrint("Text mode tapped");
            },
          ),
        ],
      ),
    );
  }
}
