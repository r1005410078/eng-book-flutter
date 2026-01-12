import 'dart:ui';
import 'package:flutter/material.dart';

class PracticeControls extends StatelessWidget {
  final bool isPlaying;
  final bool isRecording;
  final VoidCallback onPlayPause;
  final VoidCallback onRecord;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onReplay5s;
  final VoidCallback onPlayOriginal;
  final Color accentColor;

  const PracticeControls({
    super.key,
    required this.isPlaying,
    required this.isRecording,
    required this.onPlayPause,
    required this.onRecord,
    required this.onNext,
    required this.onPrevious,
    required this.onReplay5s,
    required this.onPlayOriginal,
    this.accentColor = const Color(0xFFFF9F29),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 30, left: 24, right: 24),
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
                      onPressed: onPrevious,
                      icon: const Icon(Icons.arrow_back, color: Colors.grey),
                      tooltip: 'Previous Sentence',
                    ),
                    IconButton(
                      onPressed: onReplay5s,
                      icon: const Icon(Icons.replay_5, color: Colors.grey),
                      tooltip: 'Replay 5s',
                    ),

                    // Mic Button
                    Material(
                      color: isRecording ? Colors.red : accentColor,
                      shape: const CircleBorder(),
                      elevation: 8,
                      shadowColor: (isRecording ? Colors.red : accentColor)
                          .withOpacity(0.5),
                      child: InkWell(
                        onTap: onRecord,
                        customBorder: const CircleBorder(),
                        splashColor: Colors.white.withOpacity(0.3),
                        highlightColor: Colors.white.withOpacity(0.1),
                        child: Container(
                          width: 52,
                          height: 52,
                          alignment: Alignment.center,
                          child: Icon(isRecording ? Icons.stop : Icons.mic,
                              color: Colors.white, size: 28),
                        ),
                      ),
                    ),

                    IconButton(
                      onPressed:
                          onPlayPause, // This was onPlayOriginal in previous code, but typically play/pause is central or this one.
                      // The design has 'Play Original' separate. Let's check design again.
                      // Design says: 21. 播放控制（播放/暂停，循环）。 22. 录音（麦克风按钮）。
                      // Bottom bar in previous code had: Prev, Replay5, Mic, PlayOriginal, Next.
                      // And a big Overlay Play button on video.
                      // Task says "PracticeControls (Play/Pause, Record, Nav)".
                      // I will make this button toggle Play/Pause.
                      icon: Icon(
                          isPlaying
                              ? Icons.pause_circle_outline_rounded
                              : Icons.play_circle_outline_rounded,
                          color: isPlaying ? accentColor : Colors.grey),
                      tooltip: isPlaying ? 'Pause' : 'Play',
                    ),
                    IconButton(
                      onPressed: onNext,
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
