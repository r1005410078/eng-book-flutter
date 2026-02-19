import 'package:flutter/material.dart';

class HomeEmptyState extends StatelessWidget {
  final VoidCallback onGoToDownloadCenter;

  const HomeEmptyState({
    super.key,
    required this.onGoToDownloadCenter,
  });

  @override
  Widget build(BuildContext context) {
    const titleColor = Color(0xFFF5F5F2);
    const subtitleColor = Color(0xFFD6D7DB);
    const highlightColor = Color(0xFFF9C431);
    const iconColor = Color(0xFFD5C995);
    const buttonColor = Color(0xFFEC9000);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(color: Color(0xFF0C0C10)),
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(0, -1.1),
                    end: Alignment(0, 1.0),
                    colors: [
                      Color(0xFF656A60),
                      Color(0xFF8D7A5F),
                      Color(0xFF171923),
                      Color(0xFF09090D),
                    ],
                    stops: [0.0, 0.44, 0.77, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              left: -90,
              top: -80,
              child: IgnorePointer(
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFCED1C4).withValues(alpha: 0.12),
                  ),
                ),
              ),
            ),
            Positioned(
              right: -120,
              top: -40,
              child: IgnorePointer(
                child: Container(
                  width: 380,
                  height: 380,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFCCB48F).withValues(alpha: 0.2),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.62),
                    ],
                    stops: const [0.28, 0.62, 1.0],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  children: [
                    const Spacer(flex: 7),
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 48,
                      color: iconColor.withValues(alpha: 0.96),
                    ),
                    const SizedBox(height: 34),
                    Text(
                      '开启你的',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 38 / 2,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 16,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '语言学习之旅',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: highlightColor,
                        fontSize: 33,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                            color: Color(0xCC000000),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 44),
                    Text(
                      '基于 Krashen 可理解输入与 100LS 训练法',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: subtitleColor.withValues(alpha: 0.94),
                        fontSize: 21,
                        height: 1.4,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: 92,
                      height: 2,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: const Color(0xFFC58A1C).withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '带你进入沉浸式学习心流',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: subtitleColor.withValues(alpha: 0.9),
                        fontSize: 20,
                        height: 1.5,
                      ),
                    ),
                    const Spacer(flex: 3),
                    SizedBox(
                      width: double.infinity,
                      height: 68,
                      child: FilledButton(
                        onPressed: onGoToDownloadCenter,
                        style: FilledButton.styleFrom(
                          backgroundColor: buttonColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 0,
                          textStyle: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('前往下载中心'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
