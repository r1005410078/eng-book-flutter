import 'package:flutter/material.dart';

class HomeEmptyState extends StatelessWidget {
  final VoidCallback onGoToDownloadCenter;

  const HomeEmptyState({
    super.key,
    required this.onGoToDownloadCenter,
  });

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF04070E);
    const gold = Color(0xFFD2B13E);

    return Scaffold(
      body: Container(
        color: background,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: 400,
                      height: 760,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const _HeroCard(size: 320),
                          const SizedBox(height: 26),
                          const Text(
                            '静谧学习，循序渐进',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFF2F2EF),
                              fontSize: 34,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            '沉浸式心流体验，\n让外语学习变得更自然。',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color(0xFF8D97A8)
                                  .withValues(alpha: 0.92),
                              fontSize: 17,
                              height: 1.55,
                            ),
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            width: 250,
                            height: 56,
                            child: FilledButton(
                              onPressed: onGoToDownloadCenter,
                              style: FilledButton.styleFrom(
                                backgroundColor: gold,
                                foregroundColor: const Color(0xFF0B0D11),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(32),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                              child: const Text('前往下载中心'),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.local_cafe_outlined,
                                color: gold.withValues(alpha: 0.35),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'FOCUSED FLOW',
                                style: TextStyle(
                                  color: const Color(0xFF6A7485)
                                      .withValues(alpha: 0.55),
                                  fontSize: 13,
                                  letterSpacing: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final double size;

  const _HeroCard({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: const Color(0x33D2B13E)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0E4C2), Color(0xFF0F1725)],
          stops: [0.06, 0.84],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 20,
            right: 20,
            bottom: 18,
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: const Color(0x66E9C17A),
              ),
            ),
          ),
          Center(
            child: Icon(
              Icons.smart_toy_rounded,
              size: size * 0.41,
              color: const Color(0xFFCDD4DF).withValues(alpha: 0.9),
            ),
          ),
          Positioned(
            right: size * 0.23,
            bottom: size * 0.27,
            child: Transform.rotate(
              angle: -0.16,
              child: Icon(
                Icons.menu_book_rounded,
                size: size * 0.2,
                color: const Color(0xFFA22420).withValues(alpha: 0.96),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
