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
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text(
              '🦊',
              style: TextStyle(fontSize: 22),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTapCourseUnitPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      lessonTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                        children: [
                          TextSpan(text: '${currentIndex + 1}'),
                          const TextSpan(
                            text: ' / ',
                            style: TextStyle(color: Colors.white54),
                          ),
                          TextSpan(
                            text: '$total',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.download_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: onOpenDownloadCenter,
            ),
          ),
        ],
      ),
    );
  }
}
