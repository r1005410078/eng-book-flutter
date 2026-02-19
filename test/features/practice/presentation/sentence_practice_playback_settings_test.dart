import 'package:engbooks/src/features/practice/application/practice_playback_settings_provider.dart';
import 'package:engbooks/src/features/practice/data/local_course_package_loader.dart';
import 'package:engbooks/src/features/practice/domain/sentence_detail.dart';
import 'package:engbooks/src/features/practice/presentation/sentence_practice_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const pkgA = '/pkg/a';

  const sentences = <SentenceDetail>[
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
      ],
    ),
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Widget buildApp() {
    return ProviderScope(
      child: MaterialApp(
        home: SentencePracticeScreen(
          sentenceId: 'a-1',
          packageRoot: pkgA,
          courseTitle: '课程A',
          loadSentencesOverride: (_) async =>
              const LocalSentenceLoadResult(sentences: sentences),
          loadCourseCatalogsOverride: () async => catalogs,
          skipMediaSetupForTest: true,
        ),
      ),
    );
  }

  testWidgets('playback settings changes apply in current session immediately',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await settle(tester);

    expect(find.text('A sentence 1'), findsOneWidget);
    expect(find.text('A 1'), findsOneWidget);

    final container = ProviderScope.containerOf(
        tester.element(find.byType(SentencePracticeScreen)));

    await container
        .read(practicePlaybackSettingsProvider.notifier)
        .setShowChinese(false);
    await settle(tester);
    expect(find.text('A 1'), findsNothing);

    await container
        .read(practicePlaybackSettingsProvider.notifier)
        .setShowEnglish(false);
    await settle(tester);
    expect(find.text('A sentence 1'), findsNothing);

    await container
        .read(practicePlaybackSettingsProvider.notifier)
        .setShowEnglish(true);
    await container
        .read(practicePlaybackSettingsProvider.notifier)
        .setShowChinese(true);
    await container
        .read(practicePlaybackSettingsProvider.notifier)
        .setBlurTranslationByDefault(true);
    await settle(tester);

    expect(find.text('••••••••••'), findsOneWidget);
  });
}
