import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../domain/course.dart';

class CourseDetailScreen extends StatefulWidget {
  final Course course;

  const CourseDetailScreen({super.key, required this.course});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    const kBgColor = Color(0xFF1a120b);
    // Use widget.course instead of course
    final course = widget.course;
    const kCardColor = Color(0xFF282018);
    const kAccentColor = Color(0xFFFF9F29);
    const kTextColor = Colors.white;
    final kSubTextColor = Colors.white.withOpacity(0.6);

    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        backgroundColor: kBgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: const Text(
          "课程详情",
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Header Section ---
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cover Image
                        Hero(
                          tag: 'course_cover_${course.id}',
                          child: Container(
                            width: 100,
                            height: 150,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: kCardColor,
                              image: course.coverUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(course.coverUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: course.coverUrl == null
                                ? const Icon(Icons.book,
                                    color: Colors.white24, size: 40)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 20),
                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  "中级 · B1",
                                  style: TextStyle(
                                      color: kAccentColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                course.title,
                                style: const TextStyle(
                                  color: kTextColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "J.K. Rowling", // Mock author
                                style: TextStyle(
                                    color: kSubTextColor, fontSize: 14),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  _buildStatItem(Icons.layers_outlined, "17 章节",
                                      kSubTextColor),
                                  const SizedBox(width: 16),
                                  _buildStatItem(Icons.access_time, "9.5 小时",
                                      kSubTextColor),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _buildStatItem(
                                  Icons.text_fields, "78,000 词", kSubTextColor),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // --- Plot Section ---
                    _buildSectionTitle("故事情节", kAccentColor),
                    const SizedBox(height: 12),
                    Text(
                      "这是一个关于孤儿哈利·波特的故事，他在11岁生日时发现自己是一名巫师。在霍格沃茨魔法学校，他结识了挚友，并开始揭开他父母死亡背后的神秘真相，同时面对黑魔王伏地魔的威胁。",
                      style: TextStyle(
                          color: kSubTextColor, height: 1.6, fontSize: 14),
                    ),

                    const SizedBox(height: 32),

                    // --- Grammar Section ---
                    _buildSectionTitle("语法重点", kAccentColor),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildTag("一般过去时", kCardColor),
                        _buildTag("定语从句", kCardColor),
                        _buildTag("虚拟语气", kCardColor),
                        _buildTag("情态动词", kCardColor),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // --- Mastery Section ---
                    _buildSectionTitle("你将掌握", kAccentColor),
                    const SizedBox(height: 12),
                    _buildMasteryItem("掌握超过 2000 个核心魔法词汇与英式日常用语", kCardColor,
                        kTextColor, kAccentColor),
                    const SizedBox(height: 10),
                    _buildMasteryItem("提升长难句阅读理解能力，适应原版书阅读节奏", kCardColor,
                        kTextColor, kAccentColor),
                    const SizedBox(height: 10),
                    _buildMasteryItem("深入了解英国文化背景与西方奇幻文学传统", kCardColor,
                        kTextColor, kAccentColor),

                    // Extra spacing for bottom bar
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
            // Bottom Button
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
              //   color: kBgColor, // opaque background behind button
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Navigate to learning screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccentColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "开始学习",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color accentColor) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: color, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildTag(String text, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt, size: 16, color: Color(0xFFFF9F29)),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildMasteryItem(
      String text, Color bgColor, Color textColor, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, color: accentColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  color: textColor.withOpacity(0.9), fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
