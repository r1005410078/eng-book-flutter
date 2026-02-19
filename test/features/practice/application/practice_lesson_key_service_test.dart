import 'package:engbooks/src/features/practice/application/practice_lesson_key_service.dart';
import 'package:engbooks/src/features/practice/domain/sentence_detail.dart';
import 'package:flutter_test/flutter_test.dart';

SentenceDetail _sentence({
  String? lessonId,
  String? lessonTitle,
  String? mediaPath,
  String? courseTitle,
  String? packageRoot,
}) {
  return SentenceDetail(
    id: 's1',
    text: 'hello',
    translation: '你好',
    phonetic: 'həˈləʊ',
    grammarNotes: const {},
    startTime: Duration.zero,
    endTime: const Duration(seconds: 1),
    lessonId: lessonId,
    lessonTitle: lessonTitle,
    mediaPath: mediaPath,
    courseTitle: courseTitle,
    packageRoot: packageRoot,
  );
}

void main() {
  const service = PracticeLessonKeyService();

  group('PracticeLessonKeyService', () {
    test('keyFromParts builds scope and fallbacks deterministically', () {
      expect(
        service.keyFromParts(
          packageRoot: '/pkg',
          lessonId: 'U1',
        ),
        'pkg:/pkg|lesson:U1',
      );
      expect(
        service.keyFromParts(
          courseTitle: 'Course X',
          lessonTitle: 'Unit A',
        ),
        'course:Course X|title:Unit A',
      );
    });

    test('prefers package root scope and lesson id', () {
      final sentence = _sentence(
        packageRoot: '/tmp/pkg',
        lessonId: 'L01',
        courseTitle: 'ignored',
      );

      expect(service.keyFromSentence(sentence), 'pkg:/tmp/pkg|lesson:L01');
    });

    test('uses fallback package root when sentence package root is empty', () {
      final sentence = _sentence(lessonTitle: 'Unit A');

      expect(
        service.keyFromSentence(sentence, fallbackPackageRoot: '/root'),
        'pkg:/root|title:Unit A',
      );
      expect(
        service.keyFromSentence(sentence, fallbackCourseTitle: 'Course Y'),
        'course:Course Y|title:Unit A',
      );
    });

    test('falls back to course scope and media/default keys', () {
      final withMedia = _sentence(courseTitle: 'Course X', mediaPath: 'a.mp3');
      final noInfo = _sentence(courseTitle: 'Course X');

      expect(
        service.keyFromSentence(withMedia),
        'course:Course X|media:a.mp3',
      );
      expect(
        service.keyFromSentence(noInfo),
        'course:Course X|default',
      );
    });

    test('keysFromSentences maps each sentence key with fallback scope', () {
      final list = [
        _sentence(lessonId: 'L1'),
        _sentence(lessonTitle: 'L2'),
      ];

      expect(
        service.keysFromSentences(list, fallbackPackageRoot: '/pkg'),
        ['pkg:/pkg|lesson:L1', 'pkg:/pkg|title:L2'],
      );
    });
  });
}
