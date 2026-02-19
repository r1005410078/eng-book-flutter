import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class ShortVideoBottomBar extends StatelessWidget {
  final Color accentColor;
  final double progress;
  final bool isPlaying;
  final bool isShadowingMode;
  final String durationText;
  final VoidCallback onTogglePlay;
  final VoidCallback onToggleShadowingMode;
  final VoidCallback onCycleSubtitleMode;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onLongPressBar;
  final IconData subtitleIcon;
  final bool isFullscreen;
  final ValueChanged<double> onSeekStart;
  final ValueChanged<double> onSeekUpdate;
  final ValueChanged<double> onSeekEnd;
  final ValueChanged<double> onSeekTap;
  final VoidCallback onSeekInteractionStart;
  final VoidCallback onSeekInteractionEnd;
  final bool isSeekActive;

  const ShortVideoBottomBar({
    super.key,
    required this.accentColor,
    required this.progress,
    required this.isPlaying,
    required this.isShadowingMode,
    required this.durationText,
    required this.onTogglePlay,
    required this.onToggleShadowingMode,
    required this.onCycleSubtitleMode,
    required this.onToggleFullscreen,
    required this.onLongPressBar,
    required this.subtitleIcon,
    required this.isFullscreen,
    required this.onSeekStart,
    required this.onSeekUpdate,
    required this.onSeekEnd,
    required this.onSeekTap,
    required this.onSeekInteractionStart,
    required this.onSeekInteractionEnd,
    required this.isSeekActive,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final insets = mediaQuery.padding;
    final bottomInset = isLandscape ? 2.0 : (insets.bottom + 6);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        insets.left + 12,
        6,
        insets.right + 12,
        bottomInset,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 3.2, sigmaY: 3.2),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.045),
                  Colors.black.withValues(alpha: 0.07),
                ],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    double positionToProgress(double dx) {
                      if (width <= 0) return 0;
                      return (dx / width).clamp(0.0, 1.0);
                    }

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      dragStartBehavior: DragStartBehavior.down,
                      onTapDown: (_) => onSeekInteractionStart(),
                      onTapUp: (details) {
                        onSeekTap(positionToProgress(details.localPosition.dx));
                        onSeekInteractionEnd();
                      },
                      onTapCancel: onSeekInteractionEnd,
                      onHorizontalDragStart: (details) {
                        onSeekInteractionStart();
                        onSeekStart(
                          positionToProgress(details.localPosition.dx),
                        );
                      },
                      onHorizontalDragUpdate: (details) => onSeekUpdate(
                        positionToProgress(details.localPosition.dx),
                      ),
                      onHorizontalDragEnd: (_) {
                        onSeekEnd(progress);
                        onSeekInteractionEnd();
                      },
                      onHorizontalDragCancel: onSeekInteractionEnd,
                      child: SizedBox(
                        height: 28,
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 90),
                              curve: Curves.easeOut,
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: isSeekActive ? 8 : 5,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.14),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(accentColor),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPressStart: (_) => onLongPressBar(),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        _compactIconButton(
                          onPressed: onTogglePlay,
                          icon: isPlaying
                              ? Icons.pause
                              : Icons.play_arrow_rounded,
                        ),
                        const SizedBox(width: 6),
                        _compactIconButton(
                          onPressed: onToggleShadowingMode,
                          icon: Icons.record_voice_over_rounded,
                          active: isShadowingMode,
                        ),
                        const Spacer(),
                        Text(
                          durationText,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12,
                            fontFamily: 'Courier',
                          ),
                        ),
                        const Spacer(),
                        _compactIconButton(
                          onPressed: onCycleSubtitleMode,
                          icon: subtitleIcon,
                        ),
                        _compactIconButton(
                          onPressed: onToggleFullscreen,
                          icon: isFullscreen
                              ? Icons.stay_current_portrait_rounded
                              : Icons.screen_rotation_alt_rounded,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _compactIconButton({
    required VoidCallback onPressed,
    required IconData icon,
    bool active = false,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: SizedBox(
        width: 34,
        height: 34,
        child: Icon(icon, color: active ? accentColor : Colors.white, size: 20),
      ),
    );
  }
}
