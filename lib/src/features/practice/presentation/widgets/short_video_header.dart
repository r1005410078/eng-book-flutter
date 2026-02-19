import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ShortVideoHeader extends StatelessWidget {
  final int currentIndex;
  final int total;
  final String courseTitle;
  final String lessonTitle;
  final VoidCallback onTapCourseUnitPicker;
  final VoidCallback onOpenDownloadCenter;

  const ShortVideoHeader({
    super.key,
    required this.currentIndex,
    required this.total,
    required this.courseTitle,
    required this.lessonTitle,
    required this.onTapCourseUnitPicker,
    required this.onOpenDownloadCenter,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const _MascotBadge(),
          const SizedBox(width: 10),
          Expanded(
            child: _HeaderTapTrigger(
              lessonTitle: lessonTitle,
              currentIndex: currentIndex,
              total: total,
              onTap: onTapCourseUnitPicker,
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onOpenDownloadCenter,
            child: const SizedBox(
              width: 34,
              height: 34,
              child: Center(
                child: Icon(
                  CupertinoIcons.book_fill,
                  size: 19,
                  color: Color(0xFFE6E9EF),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MascotBadge extends StatelessWidget {
  const _MascotBadge();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 44,
      height: 44,
      child: Center(
        child: Text(
          '🐶',
          style: TextStyle(fontSize: 26),
        ),
      ),
    );
  }
}

class _HeaderTapTrigger extends StatefulWidget {
  final String lessonTitle;
  final int currentIndex;
  final int total;
  final VoidCallback onTap;

  const _HeaderTapTrigger({
    required this.lessonTitle,
    required this.currentIndex,
    required this.total,
    required this.onTap,
  });

  @override
  State<_HeaderTapTrigger> createState() => _HeaderTapTriggerState();
}

class _HeaderTapTriggerState extends State<_HeaderTapTrigger> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final textAlpha = _pressed ? 0.76 : 0.9;
    final valueAlpha = _pressed ? 0.74 : 0.88;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(12),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) {
          if (_pressed) return;
          setState(() {
            _pressed = true;
          });
        },
        onTapUp: (_) {
          if (!_pressed) return;
          setState(() {
            _pressed = false;
          });
        },
        onTapCancel: () {
          if (!_pressed) return;
          setState(() {
            _pressed = false;
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: textAlpha),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
                child: Text(
                  widget.lessonTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 3),
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: Colors.white.withValues(alpha: valueAlpha),
                  ),
                  children: [
                    TextSpan(text: '${widget.currentIndex + 1}'),
                    const TextSpan(
                      text: ' / ',
                      style: TextStyle(color: Colors.white54),
                    ),
                    TextSpan(
                      text: '${widget.total}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
