import 'package:flutter/material.dart';

class ShortVideoCaption extends StatefulWidget {
  final String text;
  final String phonetic;
  final String translation;
  final bool showEnglish;
  final bool showChinese;
  final bool blurTranslationByDefault;
  final double subtitleScale;
  final bool compact;

  const ShortVideoCaption({
    super.key,
    required this.text,
    required this.phonetic,
    required this.translation,
    required this.showEnglish,
    required this.showChinese,
    required this.blurTranslationByDefault,
    required this.subtitleScale,
    this.compact = false,
  });

  @override
  State<ShortVideoCaption> createState() => _ShortVideoCaptionState();
}

class _ShortVideoCaptionState extends State<ShortVideoCaption> {
  bool _translationRevealed = false;

  @override
  void didUpdateWidget(covariant ShortVideoCaption oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.translation != widget.translation ||
        oldWidget.blurTranslationByDefault != widget.blurTranslationByDefault) {
      _translationRevealed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = 0.85 + (widget.subtitleScale * 0.5);
    final headlineSize = (widget.compact ? 20.0 : 22.0) * scale;
    final phoneticSize = (widget.compact ? 11.0 : 12.0) * scale;
    final translationSize = (widget.compact ? 13.0 : 14.0) * scale;
    final shouldBlurTranslation = widget.blurTranslationByDefault &&
        widget.showChinese &&
        !_translationRevealed;

    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          if (widget.showEnglish)
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 160),
              style: TextStyle(
                color: Colors.white,
                fontSize: headlineSize,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
              child: Text(
                widget.text,
                textAlign: TextAlign.center,
              ),
            ),
          if (widget.showEnglish) SizedBox(height: widget.compact ? 6 : 8),
          if (widget.showEnglish)
            Text(
              widget.phonetic,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: phoneticSize,
                fontFamily: 'Courier',
              ),
            ),
          if (widget.showChinese) SizedBox(height: widget.compact ? 6 : 8),
          if (widget.showChinese)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: shouldBlurTranslation
                  ? () {
                      setState(() {
                        _translationRevealed = true;
                      });
                    }
                  : null,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: shouldBlurTranslation ? 0.45 : 1,
                child: Text(
                  shouldBlurTranslation ? '••••••••••' : widget.translation,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: translationSize,
                    height: 1.25,
                  ),
                ),
              ),
            ),
          SizedBox(height: widget.compact ? 4 : 8),
        ],
      ),
    );
  }
}
