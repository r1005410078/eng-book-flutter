import 'package:engbooks/src/features/practice/application/practice_sentence_end_action_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const planner = PracticeSentenceEndActionPlanner();

  group('PracticeSentenceEndActionPlanner', () {
    test('returns none when not eligible to advance', () {
      expect(
        planner.plan(
          isShadowingMode: false,
          isShadowingBusy: false,
          isPlaying: false,
          isSeeking: false,
          shouldAdvanceAtSentenceEnd: true,
        ),
        SentenceEndAction.none,
      );
      expect(
        planner.plan(
          isShadowingMode: false,
          isShadowingBusy: false,
          isPlaying: true,
          isSeeking: true,
          shouldAdvanceAtSentenceEnd: true,
        ),
        SentenceEndAction.none,
      );
      expect(
        planner.plan(
          isShadowingMode: false,
          isShadowingBusy: false,
          isPlaying: true,
          isSeeking: false,
          shouldAdvanceAtSentenceEnd: false,
        ),
        SentenceEndAction.none,
      );
    });

    test('returns runShadowingStep in active non-busy shadowing mode', () {
      expect(
        planner.plan(
          isShadowingMode: true,
          isShadowingBusy: false,
          isPlaying: true,
          isSeeking: false,
          shouldAdvanceAtSentenceEnd: true,
        ),
        SentenceEndAction.runShadowingStep,
      );
    });

    test('returns none in shadowing mode when busy', () {
      expect(
        planner.plan(
          isShadowingMode: true,
          isShadowingBusy: true,
          isPlaying: true,
          isSeeking: false,
          shouldAdvanceAtSentenceEnd: true,
        ),
        SentenceEndAction.none,
      );
    });

    test('returns handleSentenceEnd in normal playback mode', () {
      expect(
        planner.plan(
          isShadowingMode: false,
          isShadowingBusy: false,
          isPlaying: true,
          isSeeking: false,
          shouldAdvanceAtSentenceEnd: true,
        ),
        SentenceEndAction.handleSentenceEnd,
      );
    });
  });
}
