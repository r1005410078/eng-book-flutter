import 'package:engbooks/src/features/practice/application/practice_lesson_index_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = PracticeLessonIndexService();

  group('PracticeLessonIndexService', () {
    test('lessonPageForSentenceIndex finds the correct page', () {
      const starts = [0, 3, 8];
      expect(
        service.lessonPageForSentenceIndex(
          lessonStartIndices: starts,
          sentenceIndex: 0,
        ),
        0,
      );
      expect(
        service.lessonPageForSentenceIndex(
          lessonStartIndices: starts,
          sentenceIndex: 5,
        ),
        1,
      );
      expect(
        service.lessonPageForSentenceIndex(
          lessonStartIndices: starts,
          sentenceIndex: 9,
        ),
        2,
      );
    });

    test('boundsForIndex returns contiguous bounds for the same lesson key',
        () {
      const keys = ['a', 'a', 'a', 'b', 'b', 'c'];
      expect(
        service.boundsForIndex(lessonKeys: keys, index: 1),
        (start: 0, end: 2),
      );
      expect(
        service.boundsForIndex(lessonKeys: keys, index: 4),
        (start: 3, end: 4),
      );
      expect(
        service.boundsForIndex(lessonKeys: keys, index: 5),
        (start: 5, end: 5),
      );
    });

    test('progressForIndex returns 1-based index and lesson total', () {
      const keys = ['a', 'a', 'a', 'b', 'b', 'c'];
      expect(
        service.progressForIndex(lessonKeys: keys, index: 1),
        (indexInLesson: 2, totalInLesson: 3),
      );
      expect(
        service.progressForIndex(lessonKeys: keys, index: 4),
        (indexInLesson: 2, totalInLesson: 2),
      );
    });

    test('targetSentenceIndexForLessonPage prefers remembered valid index', () {
      const starts = [0, 3, 5];
      const keys = ['a', 'a', 'a', 'b', 'b', 'c'];
      const remembered = {'b': 4, 'c': 5};
      expect(
        service.targetSentenceIndexForLessonPage(
          page: 1,
          lessonStartIndices: starts,
          lessonKeys: keys,
          lessonLastSentenceIndex: remembered,
        ),
        4,
      );
      expect(
        service.targetSentenceIndexForLessonPage(
          page: 2,
          lessonStartIndices: starts,
          lessonKeys: keys,
          lessonLastSentenceIndex: remembered,
        ),
        5,
      );
    });

    test('targetSentenceIndexForLessonPage falls back to start index', () {
      const starts = [0, 3, 5];
      const keys = ['a', 'a', 'a', 'b', 'b', 'c'];

      expect(
        service.targetSentenceIndexForLessonPage(
          page: 1,
          lessonStartIndices: starts,
          lessonKeys: keys,
          lessonLastSentenceIndex: const {'b': 1},
        ),
        3,
      );

      expect(
        service.targetSentenceIndexForLessonPage(
          page: 1,
          lessonStartIndices: starts,
          lessonKeys: keys,
          lessonLastSentenceIndex: const {'b': 99},
        ),
        3,
      );

      expect(
        service.targetSentenceIndexForLessonPage(
          page: 99,
          lessonStartIndices: starts,
          lessonKeys: keys,
          lessonLastSentenceIndex: const {},
        ),
        0,
      );
    });
  });
}
