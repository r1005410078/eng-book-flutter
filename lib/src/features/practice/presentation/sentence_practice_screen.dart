import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../data/mock_data.dart';
import '../domain/sentence_detail.dart';
import '../../../routing/routes.dart';

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
  late final SentenceDetail _sentence;
  bool _isTranslationVisible = false;
  late VideoPlayerController _videoController;

  @override
  void initState() {
    super.initState();
    _sentence = mockSentence;
    // 使用示例视频
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(
          'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4'),
    )..initialize().then((_) {
        setState(() {});
        _videoController.play();
        _videoController.setLooping(true);
      });
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  void _toggleTranslation() {
    setState(() {
      _isTranslationVisible = !_isTranslationVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 提取颜色常量
    const accentColor = Color(0xFFFF9F29); // 橙色
    const grammarBgColor = Color(0xFF2A2723);

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
                      _sentence.text,
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
                          _sentence.phonetic,
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
                    _buildTranslationArea(accentColor),

                    const SizedBox(height: 24),

                    // Keywords/Tags (Hardcoded for demo based on image)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildKeywordChip('have been', '去过'),
                        const SizedBox(width: 12),
                        _buildKeywordChip('all this time', '一直'),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Grammar Note
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: grammarBgColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
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
                          SizedBox(height: 8),
                          Text(
                            'Using "have been" (Present Perfect) suggests an action that started in the past and continues to the present.',
                            style: TextStyle(
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
      bottomNavigationBar:
          _buildBottomControls(const Color(0xFF1E1C1A), accentColor),
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

            // Overlays (Play button, etc.)
            Container(
              color: Colors.black.withOpacity(0.2), // Dim overlay
            ),
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 36),
            ),

            // Top Right Icons
            Positioned(
              top: 12,
              right: 12,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.push(Routes.playbackSettings),
                    child: _buildVideoActionIcon(Icons.settings),
                  ),
                  const SizedBox(width: 8),
                  _buildVideoActionIcon(Icons.subtitles_off),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoActionIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 16),
    );
  }

  Widget _buildWaveformArea(Color accentColor) {
    return Column(
      children: [
        // Timestamps
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('02:14',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              Text('15:30',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Waveform
        SizedBox(
          height: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(15, (index) {
              // More organic waveform pattern simluating voice structure
              // (Silence -> Speak -> Pause -> Speak -> Silence)
              final rawHeight = (generatedWaveformHeights[
                  index % generatedWaveformHeights.length]);
              // Add slight random variant for "noise" if desired, or keep clear.

              // Simulate progress: 40% played
              final isPlayed = index < 10;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.0),
                width: 4,
                height:
                    rawHeight.toDouble() * 0.6, // Scale height down slightly
                decoration: BoxDecoration(
                  color:
                      isPlayed ? accentColor : Colors.white.withOpacity(0.15),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  // Static mock data for waveform heights to keep visual clean
  static const List<int> generatedWaveformHeights = [
    3,
    5,
    4,
    10,
    20,
    35,
    40,
    30,
    20,
    12,
    6,
    4,
    5,
    8,
  ];

  Widget _buildTranslationArea(Color accentColor) {
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
                _sentence.translation,
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
            const TextSpan(text: '  '),
            TextSpan(
              text: cn,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
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
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey),
            onPressed: () => context.pop(),
          ),
          // Progress Pills (Mock)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: List.generate(5, (index) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      height: 6,
                      decoration: BoxDecoration(
                        color: index == 2
                            ? accentColor
                            : Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          // Streak
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2723),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.local_fire_department, color: accentColor, size: 14),
                const SizedBox(width: 4),
                Text(
                  '12',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(Color bgColor, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 30, left: 24, right: 24),
      // Outer container for Shadow (Material clipping would hide it otherwise)
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(36),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            // Material acts as the glass surface
            child: Material(
              color: const Color(0xFF2A2723).withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(36),
                side: BorderSide(
                  color: Colors.white.withOpacity(0.15),
                  width: 1.0,
                ),
              ),
              child: SizedBox(
                height: 72,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.arrow_back, color: Colors.grey),
                      tooltip: 'Previous Sentence',
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.replay_5, color: Colors.grey),
                      tooltip: 'Replay 5s',
                    ),

                    // Mic Button (Refactored for Ripple Visibility)
                    Material(
                      color: accentColor,
                      shape: const CircleBorder(),
                      elevation: 8,
                      shadowColor: accentColor.withOpacity(0.5),
                      child: InkWell(
                        onTap: () {
                          // TODO: Record
                        },
                        customBorder: const CircleBorder(),
                        splashColor: Colors.white.withOpacity(0.3),
                        highlightColor: Colors.white.withOpacity(0.1),
                        child: Container(
                          width: 52,
                          height: 52,
                          alignment: Alignment.center,
                          child: const Icon(Icons.mic,
                              color: Colors.white, size: 28),
                        ),
                      ),
                    ),

                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.play_circle_outline_rounded,
                          color: Colors.grey),
                      tooltip: 'Play Original',
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.arrow_forward, color: Colors.grey),
                      tooltip: 'Next Sentence',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
