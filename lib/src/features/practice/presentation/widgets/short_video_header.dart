import 'package:flutter/material.dart';

class ShortVideoHeader extends StatelessWidget {
  final int currentIndex;
  final int total;
  final VoidCallback onOpenGrid;
  final VoidCallback onOpenDownloadCenter;

  const ShortVideoHeader({
    super.key,
    required this.currentIndex,
    required this.total,
    required this.onOpenGrid,
    required this.onOpenDownloadCenter,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'LEARNING',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  letterSpacing: 2.2,
                ),
              ),
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                  children: [
                    TextSpan(
                      text: '${currentIndex + 1}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
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
          Row(
            children: [
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
              const SizedBox(width: 8),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.grid_view_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: onOpenGrid,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
