import 'package:engbooks/src/features/practice/data/local_course_package_loader.dart';
import 'package:engbooks/src/features/practice/domain/sentence_detail.dart';
import 'package:engbooks/src/features/practice/presentation/sentence_practice_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  LocalSentenceLoadResult buildResult(List<SentenceDetail> sentences) {
    return LocalSentenceLoadResult(sentences: sentences);
  }

  const pkgA = '/pkg/a';
  const pkgB = '/pkg/b';

  const courseASentences = <SentenceDetail>[
    SentenceDetail(
      id: 'a-1',
      text: 'A sentence 1',
      translation: 'A 1',
      phonetic: 'a1',
      grammarNotes: {},
      startTime: Duration.zero,
      endTime: Duration(seconds: 1),
      lessonId: 'a_l1',
      lessonTitle: 'A单元1',
      courseTitle: '课程A',
      packageRoot: pkgA,
      mediaType: 'video',
      mediaPath: '/tmp/a.mp4',
    ),
    SentenceDetail(
      id: 'a-2',
      text: 'A sentence 2',
      translation: 'A 2',
      phonetic: 'a2',
      grammarNotes: {},
      startTime: Duration(seconds: 2),
      endTime: Duration(seconds: 3),
      lessonId: 'a_l2',
      lessonTitle: 'A单元2',
      courseTitle: '课程A',
      packageRoot: pkgA,
      mediaType: 'video',
      mediaPath: '/tmp/a.mp4',
    ),
  ];

  const courseBSentences = <SentenceDetail>[
    SentenceDetail(
      id: 'b-1',
      text: 'B sentence 1',
      translation: 'B 1',
      phonetic: 'b1',
      grammarNotes: {},
      startTime: Duration.zero,
      endTime: Duration(seconds: 1),
      lessonId: 'b_l1',
      lessonTitle: 'B单元1',
      courseTitle: '课程B',
      packageRoot: pkgB,
      mediaType: 'video',
      mediaPath: '/tmp/b.mp4',
    ),
  ];

  final catalogs = <LocalCourseCatalog>[
    const LocalCourseCatalog(
      courseId: 'course_a',
      title: '课程A',
      packageRoot: pkgA,
      units: [
        LocalCourseUnitSummary(
          lessonId: 'a_l1',
          title: 'A单元1',
          firstSentenceId: 'a-1',
          sentenceCount: 1,
        ),
        LocalCourseUnitSummary(
          lessonId: 'a_l2',
          title: 'A单元2',
          firstSentenceId: 'a-2',
          sentenceCount: 1,
        ),
      ],
    ),
    const LocalCourseCatalog(
      courseId: 'course_b',
      title: '课程B',
      packageRoot: pkgB,
      units: [
        LocalCourseUnitSummary(
          lessonId: 'b_l1',
          title: 'B单元1',
          firstSentenceId: 'b-1',
          sentenceCount: 1,
        ),
      ],
    ),
  ];

  Future<LocalSentenceLoadResult> loader(String packageRoot) async {
    if (packageRoot == pkgB) {
      return buildResult(courseBSentences);
    }
    return buildResult(courseASentences);
  }

  Widget buildApp() {
    return ProviderScope(
      child: MaterialApp(
        home: SentencePracticeScreen(
          sentenceId: 'a-1',
          packageRoot: pkgA,
          courseTitle: '课程A',
          loadSentencesOverride: loader,
          loadCourseCatalogsOverride: () async => catalogs,
          skipMediaSetupForTest: true,
        ),
      ),
    );
  }

  testWidgets('selecting another course unit switches content', (tester) async {
    await tester.pumpWidget(buildApp());
    await settle(tester);

    expect(find.text('课程A'), findsOneWidget);
    expect(find.text('A sentence 1'), findsOneWidget);

    await tester.tap(find.text('课程A'));
    await settle(tester);
    expect(find.textContaining('练习 1 次'), findsWidgets);
    expect(find.textContaining('练习 0 次 · 0% · 熟练度 0'), findsWidgets);
    expect(find.textContaining('已完成 · 练习 1 次'), findsOneWidget);

    await tester.tap(find.text('课程B'));
    await settle(tester);
    expect(find.textContaining('未开始 · 练习 0 次 · 0% · 熟练度 0'), findsOneWidget);
    await tester.tap(find.text('B单元1'));
    await settle(tester);
    await tester.tap(find.text('继续学习'));
    await settle(tester);

    expect(find.text('课程B'), findsOneWidget);
    expect(find.text('B sentence 1'), findsOneWidget);
    expect(find.text('A sentence 1'), findsNothing);
  });

  testWidgets('dismiss picker keeps current course and unit unchanged',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await settle(tester);

    expect(find.text('课程A'), findsOneWidget);
    expect(find.text('A sentence 1'), findsOneWidget);

    await tester.tap(find.text('课程A'));
    await settle(tester);

    await tester.tapAt(const Offset(8, 8));
    await settle(tester);

    expect(find.text('课程A'), findsOneWidget);
    expect(find.text('A sentence 1'), findsOneWidget);
    expect(find.text('B sentence 1'), findsNothing);
  });
}
