import 'package:engbooks/src/features/practice/application/practice_lesson_page_change_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const planner = PracticeLessonPageChangePlanner();

  group('PracticeLessonPageChangePlanner', () {
    test('returns ignore for invalid page inputs', () {
      expect(
        planner
            .plan(
              page: -1,
              pageCount: 3,
              isProgrammaticPageJump: false,
              currentSentenceIndex: 1,
              targetSentenceIndex: 2,
            )
            .action,
        LessonPageChangeAction.ignore,
      );
      expect(
        planner
            .plan(
              page: 3,
              pageCount: 3,
              isProgrammaticPageJump: false,
              currentSentenceIndex: 1,
              targetSentenceIndex: 2,
            )
            .action,
        LessonPageChangeAction.ignore,
      );
    });

    test('returns ignore when page jump is programmatic', () {
      expect(
        planner
            .plan(
              page: 1,
              pageCount: 3,
              isProgrammaticPageJump: true,
              currentSentenceIndex: 1,
              targetSentenceIndex: 2,
            )
            .action,
        LessonPageChangeAction.ignore,
      );
    });

    test('returns warmPreviewsOnly when target is current sentence', () {
      final plan = planner.plan(
        page: 1,
        pageCount: 3,
        isProgrammaticPageJump: false,
        currentSentenceIndex: 2,
        targetSentenceIndex: 2,
      );

      expect(plan.action, LessonPageChangeAction.warmPreviewsOnly);
      expect(plan.targetSentenceIndex, isNull);
    });

    test('returns seekToSentence for different target sentence', () {
      final plan = planner.plan(
        page: 1,
        pageCount: 3,
        isProgrammaticPageJump: false,
        currentSentenceIndex: 2,
        targetSentenceIndex: 4,
      );

      expect(plan.action, LessonPageChangeAction.seekToSentence);
      expect(plan.targetSentenceIndex, 4);
    });
  });
}
