import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class ShortVideoVideoCard extends StatelessWidget {
  final bool isAudioMode;
  final double progress;
  final VideoPlayerController videoController;
  final bool isPlaying;
  final VoidCallback onTogglePlay;
  final double aspectRatio;

  const ShortVideoVideoCard({
    super.key,
    required this.isAudioMode,
    required this.progress,
    required this.videoController,
    required this.isPlaying,
    required this.onTogglePlay,
    this.aspectRatio = 16 / 9,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAspectRatio = videoController.value.isInitialized &&
            videoController.value.aspectRatio > 0
        ? videoController.value.aspectRatio
        : aspectRatio;

    return SizedBox.expand(
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isAudioMode)
            Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: SizedBox(
                width: 220,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.audiotrack,
                      size: 64,
                      color: Color(0xFFFF9F29),
                    ),
                    const SizedBox(height: 18),
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation(
                        Color(0xFFFF9F29),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (videoController.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: effectiveAspectRatio,
                child: VideoPlayer(videoController),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.orange),
            ),
          IgnorePointer(
            ignoring: true,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 160),
              opacity: isPlaying ? 0 : 1,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 46,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: GestureDetector(
              onTap: onTogglePlay,
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}
