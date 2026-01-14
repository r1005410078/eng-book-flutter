import 'dart:ui';
import 'dart:math' as math; // Import math
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../routing/routes.dart';
import 'course_selection_screen.dart';

// --- Constants ---
const Color kBgColor = Color(0xFF1a120b);
const Color kCardColor = Color(0xFF282018); // Slightly warmer dark
const Color kAccentColor = Color(0xFFFF9F29); // Orange
const Color kTextGrey = Color(0xFF9E9E9E);

// --- Mock Models ---
enum NodeStatus { completed, active, pending, locked }

class LearningNode {
  final String id;
  final String title;
  final String? subtitle;
  final NodeStatus status;
  final String? avatarUrl;

  const LearningNode({
    required this.id,
    required this.title,
    this.subtitle,
    required this.status,
    this.avatarUrl,
  });
}

final List<LearningNode> mockNodes = [
  const LearningNode(
    id: '1',
    title: '基础问候',
    status: NodeStatus.completed,
    avatarUrl: 'assets/image.png',
  ),
  const LearningNode(
    id: '2',
    title: '职场会议表达',
    subtitle: '单元 2 / 15',
    status: NodeStatus.active,
  ),
  const LearningNode(
    id: '3',
    title: '邮件往来技巧',
    status: NodeStatus.pending,
    avatarUrl:
        'https://ui-avatars.com/api/?name=M&background=333&color=666&size=128',
  ),
  const LearningNode(
    id: '4',
    title: '商务谈判入门',
    status: NodeStatus.pending,
    avatarUrl:
        'https://ui-avatars.com/api/?name=B&background=333&color=666&size=128',
  ),
  const LearningNode(
    id: '5',
    title: '行业趋势分析',
    status: NodeStatus.locked,
  ),
];

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                // Top Bar
                SliverToBoxAdapter(child: _buildTopBar(context)),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                // Progress Card
                SliverToBoxAdapter(child: _buildProgressCard()),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
                // Learning Path
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == mockNodes.length) {
                        return const SizedBox(height: 120); // Bottom padding
                      }
                      final node = mockNodes[index];
                      // Calculate River Flow Offset
                      // Use a sine wave to create a meandering path
                      // index 0 -> sin(0) = 0
                      // index 1 -> sin(1.2) ~ 0.93 -> Right
                      // index 2 -> sin(2.4) ~ 0.67 -> Right (Active)
                      // index 3 -> sin(3.6) ~ -0.4 -> Left
                      // index 4 -> sin(4.8) ~ -0.99 -> Left
                      double xOffset = 50.0 * math.sin(index * 1.5);

                      // Use a larger gap for the active node to make it stand out
                      double mb = 30;
                      if (node.status == NodeStatus.active) mb = 50;
                      if (index > 0 &&
                          mockNodes[index - 1].status == NodeStatus.active) {
                        mb = 40;
                      }

                      return Transform.translate(
                        offset: Offset(xOffset, 0),
                        child: Padding(
                          padding: EdgeInsets.only(bottom: mb),
                          child: _buildPathNodeItem(context, node),
                        ),
                      );
                    },
                    childCount: mockNodes.length + 1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Left
          const Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_fire_department_rounded,
                    color: kAccentColor, size: 20),
                SizedBox(width: 4),
                Text(
                  '12天',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Center Title
          const Text(
            '商务英语基础',
            style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),

          // Right
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useRootNavigator: true,
                  builder: (_) {
                    final topSafe = MediaQuery.of(
                      Navigator.of(context).context,
                    ).padding.top;

                    return Container(
                      color: kBgColor,
                      padding: EdgeInsets.only(top: topSafe),
                      child: const CourseSelectionScreen(),
                    );
                  },
                );
              },
              child: Icon(Icons.menu_book_rounded,
                  color: Colors.white.withOpacity(0.8), size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      height: 110,
      decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ]),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Circular Progress
          SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    value: 0.3,
                    strokeWidth: 6,
                    backgroundColor: Colors.white.withOpacity(0.05),
                    color: kAccentColor,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                const Center(
                  child: Text(
                    "30%",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),

          // Right: Stats Info
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Label + Today's Goal
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("当前章节",
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 10)),
                    const Text("今日会话",
                        style: TextStyle(
                            color: kAccentColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 2),

                // Row 2: Title + Count
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("职场会议表达",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    Text("12 / 100",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),

                // Row 3: Total Reps + Progress Bar
                Row(
                  children: [
                    RichText(
                      text: const TextSpan(children: [
                        TextSpan(
                            text: "450 ",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 14)),
                        TextSpan(
                            text: "次练习",
                            style:
                                TextStyle(color: Colors.white70, fontSize: 10)),
                      ]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: 0.4, // Mock progress
                          child: Container(
                            decoration: BoxDecoration(
                              color: kAccentColor,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPathNodeItem(BuildContext context, LearningNode node) {
    if (node.status == NodeStatus.active) {
      return _buildActiveNode(context, node);
    } else if (node.status == NodeStatus.completed) {
      return _buildCompletedNode(node);
    } else if (node.status == NodeStatus.pending) {
      return _buildPendingNode(node, isLocked: false);
    } else {
      return _buildPendingNode(node, isLocked: true);
    }
  }

  // --- Active Node ---
  Widget _buildActiveNode(BuildContext context, LearningNode node) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            // Glow Effects
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kAccentColor.withOpacity(0.05),
              ),
            ),
            Positioned(
              top: 15,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kAccentColor.withOpacity(0.1),
                    boxShadow: [
                      BoxShadow(
                          color: kAccentColor.withOpacity(0.1),
                          blurRadius: 30,
                          spreadRadius: 5),
                    ]),
              ),
            ),

            // Main Circle Button
            GestureDetector(
              onTap: () => context
                  .push(Routes.sentencePractice.replaceFirst(':id', node.id)),
              child: Container(
                margin: const EdgeInsets.only(
                    top: 25), // Center relative to largest glow
                width: 90, height: 90,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black,
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 5)),
                    ]),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 50),
              ),
            ),

            // "Learning" Tag
            Positioned(
              bottom: -12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: kAccentColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('正在学习',
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(node.title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(node.subtitle ?? '',
            style:
                TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
      ],
    );
  }

  // --- Completed Node ---
  Widget _buildCompletedNode(LearningNode node) {
    return Column(
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Avatar
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: kAccentColor.withOpacity(0.6), width: 4),
                  boxShadow: [
                    BoxShadow(
                        color: kAccentColor.withOpacity(0.2),
                        blurRadius: 12,
                        spreadRadius: 1),
                  ],
                  image: node.avatarUrl != null
                      ? DecorationImage(
                          image: node.avatarUrl!.startsWith('assets/')
                              ? AssetImage(node.avatarUrl!) as ImageProvider
                              : NetworkImage(node.avatarUrl!),
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(
                            Colors.black.withOpacity(0.4),
                            BlendMode.darken,
                          ),
                        )
                      : null,
                ),
                child: node.avatarUrl == null
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              // Checkmark Badge
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: kAccentColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: kBgColor, width: 2),
                  ),
                  child: const Icon(Icons.check,
                      size: 14, color: Color(0xFF1a120b)),
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(node.title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  // --- Pending / Locked Node ---
  Widget _buildPendingNode(LearningNode node, {required bool isLocked}) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            // Dashed Circle
            CustomPaint(
              size: const Size(70, 70),
              painter:
                  _DashedCirclePainter(color: Colors.white.withOpacity(0.15)),
              child: Container(
                width: 70,
                height: 70,
                alignment: Alignment.center,
                child: isLocked
                    ? Icon(Icons.lock_rounded,
                        color: Colors.white.withOpacity(0.2), size: 24)
                    : Opacity(
                        opacity: 0.5,
                        child: CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.transparent,
                          backgroundImage: node.avatarUrl != null
                              ? NetworkImage(node.avatarUrl!)
                              : null,
                          child: node.avatarUrl == null
                              ? Icon(Icons.person,
                                  color: Colors.white.withOpacity(0.3))
                              : null,
                        ),
                      ),
              ),
            ),
            // Tag
            if (!isLocked)
              Positioned(
                bottom: -10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text("未开始",
                      style: TextStyle(color: Colors.white54, fontSize: 9)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (isLocked)
          const SizedBox(height: 12), // Extra space because info is simple text
        Text(node.title,
            style:
                TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
      ],
    );
  }
}

// Custom Painter for Dashed Circle
class _DashedCirclePainter extends CustomPainter {
  final Color color;
  _DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final double radius = size.width / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final Path path = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));

    PathMetrics metrics = path.computeMetrics();
    for (PathMetric metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(
            metric.extractPath(distance, distance + 6), // Dash length
            paint);
        distance += 6 + 5; // Dash + Gap
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
