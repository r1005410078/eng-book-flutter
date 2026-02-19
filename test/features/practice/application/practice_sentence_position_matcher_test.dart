import 'package:engbooks/src/features/practice/application/practice_sentence_position_matcher.dart';
import 'package:engbooks/src/features/practice/domain/sentence_detail.dart';
import 'package:flutter_test/flutter_test.dart';

SentenceDetail _s(int startMs, int endMs) {
  return SentenceDetail(
    id: '$startMs-$endMs',
    text: 't',
    translation: 'tr',
    phonetic: 'p',
    grammarNotes: const {},
    startTime: Duration(milliseconds: startMs),
    endTime: Duration(milliseconds: endMs),
  );
}

void main() {
  const matcher = PracticeSentencePositionMatcher();
  final list = <SentenceDetail>[
    _s(0, 1000),
    _s(1000, 2000),
    _s(2000, 3000),
  ];

  group('PracticeSentencePositionMatcher', () {
    test('returns matching sentence index inside bounds', () {
      expect(
        matcher.findIndexInBounds(
          position: const Duration(milliseconds: 1200),
          sentences: list,
          start: 0,
          end: 2,
        ),
        1,
      );
    });

    test('returns null when position does not match any sentence', () {
      expect(
        matcher.findIndexInBounds(
          position: const Duration(milliseconds: 3500),
          sentences: list,
          start: 0,
          end: 2,
        ),
        isNull,
      );
    });

    test('respects start/end bounds', () {
      expect(
        matcher.findIndexInBounds(
          position: const Duration(milliseconds: 1200),
          sentences: list,
          start: 2,
          end: 2,
        ),
        isNull,
      );
    });

    test('returns null for invalid bounds', () {
      expect(
        matcher.findIndexInBounds(
          position: const Duration(milliseconds: 1200),
          sentences: list,
          start: -1,
          end: 2,
        ),
        isNull,
      );
      expect(
        matcher.findIndexInBounds(
          position: const Duration(milliseconds: 1200),
          sentences: list,
          start: 2,
          end: 1,
        ),
        isNull,
      );
      expect(
        matcher.findIndexInBounds(
          position: const Duration(milliseconds: 1200),
          sentences: list,
          start: 0,
          end: 9,
        ),
        isNull,
      );
    });
  });
}
