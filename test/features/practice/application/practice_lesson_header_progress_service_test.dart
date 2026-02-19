import 'package:engbooks/src/features/practice/application/practice_lesson_header_progress_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = PracticeLessonHeaderProgressService();

  group('PracticeLessonHeaderProgressService', () {
    test('returns lesson start for empty inputs', () {
      expect(
        service.displaySentenceIndex(
          currentLessonPage: 0,
          lessonStartIndices: const [],
          lessonKeys: const [],
          lessonLastSentenceIndex: const {},
        ),
        0,
      );
    });

    test('returns remembered index when valid and same lesson', () {
      final index = service.displaySentenceIndex(
        currentLessonPage: 1,
        lessonStartIndices: const [0, 3],
        lessonKeys: const ['a', 'a', 'a', 'b', 'b'],
        lessonLastSentenceIndex: const {'b': 4},
      );
      expect(index, 4);
    });

    test('falls back to lesson start when remembered is invalid', () {
      expect(
        service.displaySentenceIndex(
          currentLessonPage: 1,
          lessonStartIndices: const [0, 3],
          lessonKeys: const ['a', 'a', 'a', 'b', 'b'],
          lessonLastSentenceIndex: const {'b': 99},
        ),
        3,
      );
      expect(
        service.displaySentenceIndex(
          currentLessonPage: 1,
          lessonStartIndices: const [0, 3],
          lessonKeys: const ['a', 'a', 'a', 'b', 'b'],
          lessonLastSentenceIndex: const {'b': 1},
        ),
        3,
      );
    });
  });
}
