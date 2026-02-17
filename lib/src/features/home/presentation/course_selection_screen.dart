import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../routing/routes.dart';
import '../../practice/application/local_course_provider.dart';

// --- Mock Models ---
import '../domain/course.dart';

// --- Mock Models ---
// Course and CourseType defined in domain/course.dart

final List<Course> mockCourses = [
  const Course(
    id: '1',
    title: "Harry Potter and the Sorcerer's Stone",
    subtitle: "17 章节",
    coverUrl:
        "https://m.media-amazon.com/images/I/81iqZ2HHD-L._AC_UF1000,1000_QL80_.jpg", // Web image
    progress: 45,
    isContinue: true,
    type: CourseType.book,
  ),
  const Course(
    id: '2',
    title: "Friends: The Complete Season 1",
    subtitle: "24 章节",
    coverUrl:
        "https://m.media-amazon.com/images/M/MV5BNDVkYjU0MzctMzg1MS00NzE3LTkyZWQtMTdiMDgxNDFlZDcwXkEyXkFqcGdeQXVyNzkwMjQ5NzM@._V1_FMjpg_UX1000_.jpg",
    type: CourseType.video,
  ),
  const Course(
    id: '3',
    title: "The Daily Podcast",
    subtitle: "320 章节",
    coverUrl:
        "https://upload.wikimedia.org/wikipedia/en/3/3b/The_Daily_logo.jpg",
    type: CourseType.audio,
  ),
  const Course(
    id: '4',
    title: "Ted Talks: Future Trends",
    subtitle: "12 章节",
    // No exact url, use color placeholder logic if needed, or generic
    coverUrl: null,
    type: CourseType.video,
  ),
];

// --- Categories ---
const List<String> kCategories = ['全部', '我的', '视频', '书籍', '入门', '进阶'];

// --- Colors ---
const Color kBgColor = Color(0xFF1a120b);
const Color kCardColor = Color(0xFF282018);
const Color kAccentColor = Color(0xFFFF9F29);

class CourseSelectionScreen extends ConsumerStatefulWidget {
  const CourseSelectionScreen({super.key});

  @override
  ConsumerState<CourseSelectionScreen> createState() =>
      _CourseSelectionScreenState();
}

class _CourseSelectionScreenState extends ConsumerState<CourseSelectionScreen> {
  int _selectedCategoryIndex = 0;

  @override
  Widget build(BuildContext context) {
    final localCoursesAsync = ref.watch(localCourseListProvider);
    final hasLocalCourses = localCoursesAsync.asData != null &&
        localCoursesAsync.asData!.value.isNotEmpty;
    final courses = hasLocalCourses
        ? localCoursesAsync.asData!.value
            .map(
              (c) => Course(
                id: c.courseId,
                title: c.title,
                subtitle: '${c.lessonCount} 章节',
                coverUrl: null,
                progress: 0,
                isContinue: false,
                type: c.mediaType == 'audio'
                    ? CourseType.audio
                    : CourseType.video,
                packageRoot: c.packageRoot,
                firstSentenceId: c.firstSentenceId,
              ),
            )
            .toList()
        : mockCourses;
    final warning = localCoursesAsync.isLoading || hasLocalCourses
        ? null
        : '未发现本地课程包，已回退到示例课程。';

    // Basic filter logic (mock)
    final filteredCourses = _selectedCategoryIndex == 0
        ? courses
        : _selectedCategoryIndex == 2 // Video
            ? courses.where((c) => c.type == CourseType.video).toList()
            : _selectedCategoryIndex == 3 // Book
                ? courses.where((c) => c.type == CourseType.book).toList()
                : courses; // Fallback for others

    return SafeArea(
      child: Container(
        color: kBgColor,
        padding: const EdgeInsets.only(top: 47),
        child: Scaffold(
          backgroundColor: kBgColor,
          appBar: AppBar(
            backgroundColor: kBgColor,
            elevation: 0,
            centerTitle: false,
            automaticallyImplyLeading: false,
            title: Container(
              padding: const EdgeInsets.only(right: 16, top: 4, bottom: 4),
              decoration: BoxDecoration(
                color: kCardColor,
                borderRadius:
                    const BorderRadius.horizontal(right: Radius.circular(24)),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The "tag" color strip
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      color: kAccentColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "选择课程",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            titleSpacing:
                0, // Align with left edge more closely if needed, or keep default
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        color: Colors.white70, size: 20),
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              // Category Filter
              SizedBox(
                height: 36,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: kCategories.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final isSelected = index == _selectedCategoryIndex;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategoryIndex = index;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? kAccentColor
                              : Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          kCategories[index],
                          style: TextStyle(
                            color: isSelected
                                ? Colors.black
                                : Colors.white.withOpacity(0.6),
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              if (warning != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    warning,
                    style: TextStyle(
                      color: Colors.orange.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ),

              if (warning != null) const SizedBox(height: 8),

              // Count
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      "共找到 ${filteredCourses.length} 个教程",
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4), fontSize: 12),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Container(
                            height: 1, color: Colors.white.withOpacity(0.05))),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Grid
              Expanded(
                child: localCoursesAsync.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: kAccentColor))
                    : GridView.builder(
                        padding: EdgeInsets.only(
                          left: 20,
                          right: 20,
                          top: 10,
                          bottom: MediaQuery.of(context).padding.bottom + 20,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.65, // Taller cards
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 20,
                        ),
                        itemCount: filteredCourses.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () async {
                              await context.push(Routes.courseDetail,
                                  extra: filteredCourses[index]);
                            },
                            child: _buildCourseCard(filteredCourses[index]),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourseCard(Course course) {
    return Container(
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Background Image
          Positioned.fill(
            bottom: 60, // Leave space for text
            child: course.coverUrl != null
                ? Image.network(
                    course.coverUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: Colors.grey[800]),
                  )
                : Container(
                    color: Colors.grey[800],
                    child: const Icon(Icons.movie_filter,
                        color: Colors.white24, size: 40),
                  ),
          ),

          // Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    kCardColor.withOpacity(0.9), // Fade to card color
                    kCardColor,
                  ],
                  stops: const [0.4, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  course.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.layers,
                            size: 14, color: Colors.white.withOpacity(0.5)),
                        const SizedBox(width: 4),
                        Text(
                          course.subtitle,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12),
                        ),
                      ],
                    ),
                    if (course.isContinue)
                      Text(
                        "${course.progress}%",
                        style: const TextStyle(
                            color: kAccentColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      )
                    else
                      Icon(Icons.add_circle_outline,
                          color: Colors.white.withOpacity(0.3), size: 20),
                  ],
                ),
              ],
            ),
          ),

          // Continue Tag
          if (course.isContinue)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: kAccentColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow, size: 10, color: Colors.black),
                    SizedBox(width: 4),
                    Text(
                      "继续学习",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Media Type Icon
          if (!course.isContinue)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  course.type == CourseType.video
                      ? Icons.videocam
                      : course.type == CourseType.audio
                          ? Icons.mic
                          : Icons.menu_book,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
