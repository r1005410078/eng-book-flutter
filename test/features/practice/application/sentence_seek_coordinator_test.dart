import 'package:engbooks/src/features/practice/application/sentence_seek_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SentenceSeekCoordinator', () {
    const coordinator = SentenceSeekCoordinator();

    test('returns false for out-of-range index and skips callbacks', () async {
      var prepared = false;
      var finalized = false;
      var finallyCalled = false;

      final result = await coordinator.perform(
        index: -1,
        sentenceCount: 3,
        prepareTransition: () => prepared = true,
        isRequestCurrent: () => true,
        seekActiveMedia: () async => true,
        finalizeSeek: () => finalized = true,
        onFinally: () => finallyCalled = true,
      );

      expect(result, isFalse);
      expect(prepared, isFalse);
      expect(finalized, isFalse);
      expect(finallyCalled, isFalse);
    });

    test('runs full happy path and executes callbacks in expected order',
        () async {
      final events = <String>[];

      final result = await coordinator.perform(
        index: 1,
        sentenceCount: 3,
        prepareTransition: () => events.add('prepare'),
        beforeSeek: () async => events.add('beforeSeek'),
        isRequestCurrent: () {
          events.add('isCurrent');
          return true;
        },
        seekActiveMedia: () async {
          events.add('seek');
          return true;
        },
        finalizeSeek: () => events.add('finalize'),
        onFinally: () => events.add('finally'),
      );

      expect(result, isTrue);
      expect(
        events,
        [
          'prepare',
          'beforeSeek',
          'isCurrent',
          'seek',
          'isCurrent',
          'finalize',
          'finally',
        ],
      );
    });

    test(
        'returns true but skips seek/finalize when request is stale before seek',
        () async {
      var checkCount = 0;
      var seekCalled = false;
      var finalized = false;
      var finallyCalled = false;

      final result = await coordinator.perform(
        index: 1,
        sentenceCount: 3,
        prepareTransition: () {},
        isRequestCurrent: () {
          checkCount++;
          return false;
        },
        seekActiveMedia: () async {
          seekCalled = true;
          return true;
        },
        finalizeSeek: () => finalized = true,
        onFinally: () => finallyCalled = true,
      );

      expect(result, isTrue);
      expect(checkCount, 1);
      expect(seekCalled, isFalse);
      expect(finalized, isFalse);
      expect(finallyCalled, isTrue);
    });

    test('returns false when seek fails and still calls finally', () async {
      var finalized = false;
      var finallyCalled = false;

      final result = await coordinator.perform(
        index: 1,
        sentenceCount: 3,
        prepareTransition: () {},
        isRequestCurrent: () => true,
        seekActiveMedia: () async => false,
        finalizeSeek: () => finalized = true,
        onFinally: () => finallyCalled = true,
      );

      expect(result, isFalse);
      expect(finalized, isFalse);
      expect(finallyCalled, isTrue);
    });

    test('skips finalize when request turns stale after seek', () async {
      var finalized = false;
      var finallyCalled = false;
      var checkCount = 0;

      final result = await coordinator.perform(
        index: 1,
        sentenceCount: 3,
        prepareTransition: () {},
        isRequestCurrent: () {
          checkCount++;
          return checkCount == 1;
        },
        seekActiveMedia: () async => true,
        finalizeSeek: () => finalized = true,
        onFinally: () => finallyCalled = true,
      );

      expect(result, isTrue);
      expect(finalized, isFalse);
      expect(finallyCalled, isTrue);
      expect(checkCount, 2);
    });
  });
}
