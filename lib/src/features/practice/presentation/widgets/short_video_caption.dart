import 'package:flutter/material.dart';

class ShortVideoCaption extends StatelessWidget {
  final String text;
  final String phonetic;
  final String translation;
  final bool showEnglish;
  final bool showChinese;
  final bool compact;

  const ShortVideoCaption({
    super.key,
    required this.text,
    required this.phonetic,
    required this.translation,
    required this.showEnglish,
    required this.showChinese,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final headlineSize = compact ? 20.0 : 22.0;
    final phoneticSize = compact ? 11.0 : 12.0;
    final translationSize = compact ? 13.0 : 14.0;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: Column(
        children: [
          if (showEnglish)
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 160),
              style: TextStyle(
                color: Colors.white,
                fontSize: headlineSize,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
              child: Text(
                text,
                textAlign: TextAlign.center,
              ),
            ),
          if (showEnglish) SizedBox(height: compact ? 6 : 8),
          if (showEnglish)
            Text(
              phonetic,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: phoneticSize,
                fontFamily: 'Courier',
              ),
            ),
          if (showChinese) SizedBox(height: compact ? 6 : 8),
          if (showChinese)
            Text(
              translation,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: translationSize,
                height: 1.25,
              ),
            ),
          SizedBox(height: compact ? 4 : 8),
        ],
      ),
    );
  }
}
