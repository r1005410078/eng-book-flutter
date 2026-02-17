import 'dart:ui';

import 'package:flutter/material.dart';

class ShortVideoBottomBar extends StatelessWidget {
  final Color accentColor;
  final double progress;
  final bool isPlaying;
  final bool isShadowingMode;
  final String durationText;
  final VoidCallback onTogglePlay;
  final VoidCallback onToggleShadowingMode;
  final VoidCallback onCycleSubtitleMode;
  final VoidCallback onOpenSettings;
  final VoidCallback onToggleFullscreen;
  final IconData subtitleIcon;
  final bool isFullscreen;
  final ValueChanged<double> onSeekStart;
  final ValueChanged<double> onSeekUpdate;
  final ValueChanged<double> onSeekEnd;
  final ValueChanged<double> onSeekTap;

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
    required this.onOpenSettings,
    required this.onToggleFullscreen,
    required this.subtitleIcon,
    required this.isFullscreen,
    required this.onSeekStart,
    required this.onSeekUpdate,
    required this.onSeekEnd,
    required this.onSeekTap,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final insets = mediaQuery.padding;
    final bottomInset = isLandscape ? 2.0 : (insets.bottom + 6);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        insets.left + 14,
        6,
        insets.right + 14,
        bottomInset,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            color: Colors.black.withValues(alpha: 0.16),
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        double positionToProgress(double dx) {
                          if (width <= 0) return 0;
                          return (dx / width).clamp(0.0, 1.0);
                        }

                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (details) =>
                              onSeekTap(positionToProgress(details.localPosition.dx)),
                          onHorizontalDragStart: (details) => onSeekStart(
                            positionToProgress(details.localPosition.dx),
                          ),
                          onHorizontalDragUpdate: (details) => onSeekUpdate(
                            positionToProgress(details.localPosition.dx),
                          ),
                          onHorizontalDragEnd: (_) => onSeekEnd(progress),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 5,
                            backgroundColor: Colors.white.withValues(alpha: 0.14),
                            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _compactIconButton(
                        onPressed: onTogglePlay,
                        icon: isPlaying ? Icons.pause : Icons.play_arrow_rounded,
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
                        onPressed: onOpenSettings,
                        icon: Icons.settings_outlined,
                      ),
                      _compactIconButton(
                        onPressed: onToggleFullscreen,
                        icon: isFullscreen
                            ? Icons.stay_current_portrait_rounded
                            : Icons.screen_rotation_alt_rounded,
                      ),
                    ],
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
        width: 30,
        height: 30,
        child: Icon(icon, color: active ? accentColor : Colors.white, size: 20),
      ),
    );
  }
}
