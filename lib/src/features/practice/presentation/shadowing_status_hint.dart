import 'package:flutter/material.dart';

class ShadowingStatusHint extends StatelessWidget {
  final bool isShadowingMode;
  final bool isRecordingPhase;
  final bool isAdvancingPhase;
  final Duration remaining;
  final bool locked;
  final VoidCallback onToggleLock;

  const ShadowingStatusHint({
    super.key,
    required this.isShadowingMode,
    required this.isRecordingPhase,
    required this.isAdvancingPhase,
    required this.remaining,
    required this.locked,
    required this.onToggleLock,
  });

  String _statusText() {
    if (!isShadowingMode) return '';
    if (isRecordingPhase) {
      final seconds = (remaining.inMilliseconds / 1000).toStringAsFixed(1);
      return '跟读中 ${seconds}s';
    }
    if (isAdvancingPhase) {
      return '切换下一句...';
    }
    return '跟读模式（已锁定）';
  }

  @override
  Widget build(BuildContext context) {
    if (!isShadowingMode) return const SizedBox.shrink();
    final color = isRecordingPhase ? Colors.redAccent : const Color(0xFFFF9F29);
    final statusIcon = isRecordingPhase
        ? TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.78, end: 1.05),
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeInOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value.clamp(0.0, 1.0),
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
                opacity: value.clamp(0.0, 1.0),
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
          _statusText(),
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
          onTap: onToggleLock,
          child: Icon(
            locked ? Icons.lock_rounded : Icons.lock_open_rounded,
            size: 16,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }
}
