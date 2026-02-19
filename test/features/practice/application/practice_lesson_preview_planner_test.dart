import 'package:engbooks/src/features/practice/application/practice_lesson_preview_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const planner = PracticeLessonPreviewPlanner();

  group('PracticeLessonPreviewPlanner', () {
    test('keepIndices returns current and adjacent pages', () {
      final keep = planner.keepIndices(
        currentPage: 2,
        pageCount: 5,
        sentenceIndexForPage: (page) => page * 10,
      );

      expect(keep, {10, 20, 30});
    });

    test('keepIndices handles boundaries', () {
      final first = planner.keepIndices(
        currentPage: 0,
        pageCount: 3,
        sentenceIndexForPage: (page) => page,
      );
      expect(first, {0, 1});

      final last = planner.keepIndices(
        currentPage: 2,
        pageCount: 3,
        sentenceIndexForPage: (page) => page,
      );
      expect(last, {1, 2});
    });

    test('keepIndices returns empty for invalid page input', () {
      expect(
        planner.keepIndices(
          currentPage: -1,
          pageCount: 3,
          sentenceIndexForPage: (page) => page,
        ),
        isEmpty,
      );
      expect(
        planner.keepIndices(
          currentPage: 3,
          pageCount: 3,
          sentenceIndexForPage: (page) => page,
        ),
        isEmpty,
      );
    });

    test('staleIndices returns cached indices that are not in keep set', () {
      final stale = planner.staleIndices(
        cachedIndices: const [1, 2, 3, 7],
        keepIndices: const {2, 7},
      );

      expect(stale, [1, 3]);
    });
  });
}
