import 'package:flutter/material.dart';

import '../data/learning_metrics_store.dart';

class _PickerStyle {
  static const sheetBg = Color(0xFF1a120b);
  static const topRadius = Radius.circular(14);

  static const divider = Color(0xFF3A2611);
  static const footerBg = Color(0xFF18100A);

  static const cardSelectedBg = Color(0xFF2A1D10);
  static const cardNormalBg = Color(0xFF19110B);
  static const cardSelectedBorder = Color(0xFF8A581A);

  static const headerAccent = Color(0xFFB47A23);
  static const titleAccent = Color(0xFFFFB02E);
  static const titleStrong = Color(0xFFFFB239);
  static const titleMuted = Color(0xFFB47A23);
  static const indexMuted = Color(0xFF7B5A2C);

  static const inProgress = Color(0xFFFFA726);
  static const completed = Color(0xFF48D48A);
  static const ready = Color(0xFF4ADE80);
  static const continueBtn = Color(0xFFFFAA2B);

  static const horizontalPadding = 22.0;
  static const sectionGapLarge = 14.0;
  static const sectionGap = 12.0;
  static const sectionGapSmall = 10.0;
  static const itemGap = 10.0;
  static const footerGap = 12.0;

  static const courseListHeight = 56.0;
  static const courseCardWidth = 182.0;
  static const unitIndexWidth = 46.0;
  static const footerButtonWidth = 148.0;
  static const footerButtonHeight = 48.0;

  static const courseCardPadding =
      EdgeInsets.symmetric(horizontal: 10, vertical: 7);
  static const unitTilePadding =
      EdgeInsets.symmetric(horizontal: 12, vertical: 10);
  static const footerPadding = EdgeInsets.fromLTRB(
    _PickerStyle.horizontalPadding,
    12,
    _PickerStyle.horizontalPadding,
    8,
  );

  static const statusDotSize = 12.0;
  static const completedIconSize = 28.0;
  static const notStartedIconSize = 18.0;
  static const unitMetaGap = 3.0;

  static const alphaHeader = 0.85;
  static const alphaNotStarted = 0.35;
  static const alphaNotStartedIcon = 0.34;
  static const alphaCourseMeta = 0.46;
  static const alphaUnitMeta = 0.5;
  static const alphaSelectedMeta = 0.46;
  static const alphaCardBorder = 0.09;
  static const alphaUnitBorder = 0.06;
  static const alphaCompletedUnselected = 0.92;

  static const catalogTitle = TextStyle(
    fontSize: 12,
    letterSpacing: 2.0,
    fontWeight: FontWeight.w700,
  );

  static const sectionTitle = TextStyle(
    color: _PickerStyle.titleAccent,
    fontSize: 15,
    fontWeight: FontWeight.w800,
  );

  static const legendText = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );

  static const continueText = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w800,
  );

  static TextStyle courseName(bool selected) => TextStyle(
        color: selected ? _PickerStyle.titleStrong : _PickerStyle.titleMuted,
        fontWeight: FontWeight.w700,
        fontSize: 13.5,
      );

  static TextStyle courseMeta() => TextStyle(
        color: Colors.white.withValues(alpha: _PickerStyle.alphaCourseMeta),
        fontSize: 9,
      );

  static TextStyle indexText(bool active) => TextStyle(
        color: active ? _PickerStyle.titleStrong : _PickerStyle.indexMuted,
        fontSize: active ? 15 : 13,
        fontWeight: FontWeight.w700,
      );

  static TextStyle unitTitle(bool active) => TextStyle(
        color: active ? _PickerStyle.titleStrong : _PickerStyle.titleMuted,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      );

  static TextStyle unitMeta() => TextStyle(
        color: Colors.white.withValues(alpha: _PickerStyle.alphaUnitMeta),
        fontSize: 10.5,
      );

  static TextStyle selectionMeta() => TextStyle(
        color: Colors.white.withValues(alpha: _PickerStyle.alphaSelectedMeta),
        fontSize: 11.5,
      );
}

class _PickerText {
  static const catalog = 'COURSE CATALOG';
  static const statusNotStarted = '未开始';
  static const statusInProgress = '学习中';
  static const statusCompleted = '已完成';
  static const legendCompleted = '● 已完成';
  static const legendInProgress = '● 当前在学';
  static const continueLearning = '继续学习';
  static const selectedPrefix = '已选择:';

  static String unitSectionTitle(String courseTitle) => '$courseTitle — 单元';

  static String selectedCourse({
    required String courseTitle,
    String? lessonTitle,
  }) {
    if (lessonTitle == null || lessonTitle.isEmpty) {
      return '$selectedPrefix$courseTitle';
    }
    return '$selectedPrefix$courseTitle / $lessonTitle';
  }

  static String unitMetrics({
    required String statusLabel,
    required int practiceCount,
    required double progressPercent,
    required int proficiency,
  }) {
    return '$statusLabel · 练习 $practiceCount 次 · ${progressPercent.round()}% · 熟练度 $proficiency';
  }
}

extension _PracticeStatusView on PracticeStatus {
  String get label => switch (this) {
        PracticeStatus.notStarted => _PickerText.statusNotStarted,
        PracticeStatus.inProgress => _PickerText.statusInProgress,
        PracticeStatus.completed => _PickerText.statusCompleted,
      };

  Color get color => switch (this) {
        PracticeStatus.completed => _PickerStyle.completed,
        PracticeStatus.inProgress => _PickerStyle.inProgress,
        PracticeStatus.notStarted =>
          Colors.white.withValues(alpha: _PickerStyle.alphaNotStarted),
      };

  Widget trailing({required bool selected}) {
    if (this == PracticeStatus.completed) {
      return Icon(
        Icons.check_circle_rounded,
        size: _PickerStyle.completedIconSize,
        color: _PickerStyle.completed.withValues(
          alpha: selected ? 1 : _PickerStyle.alphaCompletedUnselected,
        ),
      );
    }
    if (this == PracticeStatus.inProgress) {
      return Container(
        width: _PickerStyle.statusDotSize,
        height: _PickerStyle.statusDotSize,
        decoration: BoxDecoration(
          color: _PickerStyle.inProgress,
          borderRadius: BorderRadius.circular(6),
        ),
      );
    }
    return Icon(
      Icons.radio_button_unchecked_rounded,
      size: _PickerStyle.notStartedIconSize,
      color: Colors.white.withValues(alpha: _PickerStyle.alphaNotStartedIcon),
    );
  }
}

class CourseUnitPickerUnit {
  final String lessonKey;
  final String lessonId;
  final String lessonTitle;
  final String firstSentenceId;
  final int sentenceCount;
  final int practiceCount;
  final double progressPercent;
  final int proficiency;
  final PracticeStatus status;

  const CourseUnitPickerUnit({
    required this.lessonKey,
    required this.lessonId,
    required this.lessonTitle,
    required this.firstSentenceId,
    required this.sentenceCount,
    required this.practiceCount,
    required this.progressPercent,
    required this.proficiency,
    required this.status,
  });
}

class CourseUnitPickerCourse {
  final String packageRoot;
  final String courseTitle;
  final List<CourseUnitPickerUnit> units;
  final int practiceCount;
  final double progressPercent;
  final int proficiency;

  const CourseUnitPickerCourse({
    required this.packageRoot,
    required this.courseTitle,
    required this.units,
    required this.practiceCount,
    required this.progressPercent,
    required this.proficiency,
  });
}

class CourseUnitPickerSelection {
  final String packageRoot;
  final String courseTitle;
  final String lessonKey;
  final String firstSentenceId;

  const CourseUnitPickerSelection({
    required this.packageRoot,
    required this.courseTitle,
    required this.lessonKey,
    required this.firstSentenceId,
  });
}

Future<CourseUnitPickerSelection?> showCourseUnitPickerSheet(
  BuildContext context, {
  required List<CourseUnitPickerCourse> courses,
  required String currentPackageRoot,
  required String currentLessonKey,
}) {
  return showModalBottomSheet<CourseUnitPickerSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: true,
    isDismissible: true,
    showDragHandle: true,
    backgroundColor: _PickerStyle.sheetBg,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.94,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: _PickerStyle.topRadius),
    ),
    builder: (_) => CourseUnitPickerSheet(
      courses: courses,
      currentPackageRoot: currentPackageRoot,
      currentLessonKey: currentLessonKey,
    ),
  );
}

class CourseUnitPickerSheet extends StatefulWidget {
  final List<CourseUnitPickerCourse> courses;
  final String currentPackageRoot;
  final String currentLessonKey;

  const CourseUnitPickerSheet({
    super.key,
    required this.courses,
    required this.currentPackageRoot,
    required this.currentLessonKey,
  });

  @override
  State<CourseUnitPickerSheet> createState() => _CourseUnitPickerSheetState();
}

class _CourseUnitPickerSheetState extends State<CourseUnitPickerSheet> {
  late String _selectedPackageRoot;
  String? _selectedLessonKey;

  @override
  void initState() {
    super.initState();
    final exists = widget.courses.any(
      (course) => course.packageRoot == widget.currentPackageRoot,
    );
    _selectedPackageRoot =
        exists ? widget.currentPackageRoot : widget.courses.first.packageRoot;
    _selectedLessonKey = widget.currentLessonKey;
  }

  CourseUnitPickerUnit? _selectedUnitForCourse(CourseUnitPickerCourse course) {
    if (course.units.isEmpty) return null;
    final selected = _selectedLessonKey;
    if (selected != null) {
      for (final unit in course.units) {
        if (unit.lessonKey == selected) return unit;
      }
    }
    return course.units.first;
  }

  void _confirmSelection(CourseUnitPickerCourse selectedCourse) {
    final selectedUnit = _selectedUnitForCourse(selectedCourse);
    if (selectedUnit == null) return;
    Navigator.of(context).pop(
      CourseUnitPickerSelection(
        packageRoot: selectedCourse.packageRoot,
        courseTitle: selectedCourse.courseTitle,
        lessonKey: selectedUnit.lessonKey,
        firstSentenceId: selectedUnit.firstSentenceId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final selectedCourse = widget.courses.firstWhere(
      (course) => course.packageRoot == _selectedPackageRoot,
      orElse: () => widget.courses.first,
    );
    final selectedUnit = _selectedUnitForCourse(selectedCourse);

    return Padding(
      padding: EdgeInsets.fromLTRB(0, 0, 0, bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CourseCatalogSection(
            courses: widget.courses,
            selectedPackageRoot: _selectedPackageRoot,
            onSelectCourse: (course) {
              final selected = course.packageRoot == _selectedPackageRoot;
              if (selected) return;
              setState(() {
                _selectedPackageRoot = course.packageRoot;
                _selectedLessonKey = null;
              });
            },
          ),
          const SizedBox(height: _PickerStyle.sectionGapSmall),
          Container(height: 1, color: _PickerStyle.divider),
          const SizedBox(height: _PickerStyle.sectionGap),
          _UnitSectionHeader(
            courseTitle: selectedCourse.courseTitle,
          ),
          const SizedBox(height: _PickerStyle.sectionGap),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: _PickerStyle.horizontalPadding,
              ),
              itemCount: selectedCourse.units.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: _PickerStyle.itemGap),
              itemBuilder: (context, index) {
                final unit = selectedCourse.units[index];
                final active = selectedUnit?.lessonKey == unit.lessonKey;
                return _UnitTile(
                  unit: unit,
                  index: index,
                  active: active,
                  onTap: () {
                    setState(() {
                      _selectedLessonKey = unit.lessonKey;
                    });
                  },
                );
              },
            ),
          ),
          _SelectionFooter(
            selectedCourse: selectedCourse,
            selectedUnit: selectedUnit,
            onConfirm: () => _confirmSelection(selectedCourse),
          ),
        ],
      ),
    );
  }
}

class _CourseChip extends StatelessWidget {
  final CourseUnitPickerCourse course;
  final bool selected;
  final VoidCallback onTap;

  const _CourseChip({
    required this.course,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: _PickerStyle.courseCardWidth,
        padding: _PickerStyle.courseCardPadding,
        decoration: BoxDecoration(
          color: selected
              ? _PickerStyle.cardSelectedBg
              : _PickerStyle.cardNormalBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? _PickerStyle.cardSelectedBorder
                : Colors.white.withValues(alpha: _PickerStyle.alphaCardBorder),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.circle,
                  size: _PickerStyle.statusDotSize,
                  color:
                      selected ? _PickerStyle.inProgress : _PickerStyle.ready,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    course.courseTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _PickerStyle.courseName(selected),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              '${course.practiceCount} 次 · ${course.progressPercent.round()}% · 熟练度 ${course.proficiency}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _PickerStyle.courseMeta(),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseCatalogSection extends StatelessWidget {
  final List<CourseUnitPickerCourse> courses;
  final String selectedPackageRoot;
  final ValueChanged<CourseUnitPickerCourse> onSelectCourse;

  const _CourseCatalogSection({
    required this.courses,
    required this.selectedPackageRoot,
    required this.onSelectCourse,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: _PickerStyle.sectionGapLarge),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _PickerStyle.horizontalPadding,
          ),
          child: Text(
            _PickerText.catalog,
            style: _PickerStyle.catalogTitle.copyWith(
              color: _PickerStyle.headerAccent.withValues(
                alpha: _PickerStyle.alphaHeader,
              ),
            ),
          ),
        ),
        const SizedBox(height: _PickerStyle.sectionGapLarge),
        SizedBox(
          height: _PickerStyle.courseListHeight,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: _PickerStyle.horizontalPadding,
            ),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            primary: false,
            itemCount: courses.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: _PickerStyle.itemGap),
            itemBuilder: (context, index) {
              final course = courses[index];
              final selected = course.packageRoot == selectedPackageRoot;
              return _CourseChip(
                course: course,
                selected: selected,
                onTap: () => onSelectCourse(course),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UnitTile extends StatelessWidget {
  final CourseUnitPickerUnit unit;
  final int index;
  final bool active;
  final VoidCallback onTap;

  const _UnitTile({
    required this.unit,
    required this.index,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: _PickerStyle.unitTilePadding,
        decoration: BoxDecoration(
          color:
              active ? _PickerStyle.cardSelectedBg : _PickerStyle.cardNormalBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active
                ? _PickerStyle.cardSelectedBorder
                : Colors.white.withValues(alpha: _PickerStyle.alphaUnitBorder),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: _PickerStyle.unitIndexWidth,
              child: Text(
                (index + 1).toString().padLeft(2, '0'),
                style: _PickerStyle.indexText(active),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    unit.lessonTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _PickerStyle.unitTitle(active),
                  ),
                  const SizedBox(height: _PickerStyle.unitMetaGap),
                  Text(
                    _PickerText.unitMetrics(
                      statusLabel: unit.status.label,
                      practiceCount: unit.practiceCount,
                      progressPercent: unit.progressPercent,
                      proficiency: unit.proficiency,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _PickerStyle.unitMeta(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: _PickerStyle.itemGap),
            unit.status.trailing(selected: active),
          ],
        ),
      ),
    );
  }
}

class _UnitSectionHeader extends StatelessWidget {
  final String courseTitle;

  const _UnitSectionHeader({
    required this.courseTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _PickerStyle.horizontalPadding,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _PickerText.unitSectionTitle(courseTitle),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _PickerStyle.sectionTitle,
            ),
          ),
          Text(
            _PickerText.legendCompleted,
            style: _PickerStyle.legendText.copyWith(
              color: PracticeStatus.completed.color,
            ),
          ),
          const SizedBox(width: _PickerStyle.itemGap),
          Text(
            _PickerText.legendInProgress,
            style: _PickerStyle.legendText.copyWith(
              color: PracticeStatus.inProgress.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionFooter extends StatelessWidget {
  final CourseUnitPickerCourse selectedCourse;
  final CourseUnitPickerUnit? selectedUnit;
  final VoidCallback onConfirm;

  const _SelectionFooter({
    required this.selectedCourse,
    required this.selectedUnit,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _PickerStyle.footerBg,
        border: Border(top: BorderSide(color: _PickerStyle.divider)),
      ),
      padding: _PickerStyle.footerPadding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              _PickerText.selectedCourse(
                courseTitle: selectedCourse.courseTitle,
                lessonTitle: selectedUnit?.lessonTitle,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _PickerStyle.selectionMeta(),
            ),
          ),
          const SizedBox(width: _PickerStyle.footerGap),
          SizedBox(
            width: _PickerStyle.footerButtonWidth,
            height: _PickerStyle.footerButtonHeight,
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: _PickerStyle.continueBtn,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                _PickerText.continueLearning,
                style: _PickerStyle.continueText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
