enum LessonPageChangeAction {
  ignore,
  warmPreviewsOnly,
  seekToSentence,
}

class LessonPageChangePlan {
  final LessonPageChangeAction action;
  final int? targetSentenceIndex;

  const LessonPageChangePlan._({
    required this.action,
    this.targetSentenceIndex,
  });

  const LessonPageChangePlan.ignore()
      : this._(action: LessonPageChangeAction.ignore);

  const LessonPageChangePlan.warmPreviewsOnly()
      : this._(action: LessonPageChangeAction.warmPreviewsOnly);

  const LessonPageChangePlan.seekToSentence(int targetSentenceIndex)
      : this._(
          action: LessonPageChangeAction.seekToSentence,
          targetSentenceIndex: targetSentenceIndex,
        );
}

class PracticeLessonPageChangePlanner {
  const PracticeLessonPageChangePlanner();

  LessonPageChangePlan plan({
    required int page,
    required int pageCount,
    required bool isProgrammaticPageJump,
    required int currentSentenceIndex,
    required int targetSentenceIndex,
  }) {
    if (pageCount <= 0) {
      return const LessonPageChangePlan.ignore();
    }
    if (page < 0 || page >= pageCount) {
      return const LessonPageChangePlan.ignore();
    }
    if (isProgrammaticPageJump) {
      return const LessonPageChangePlan.ignore();
    }
    if (targetSentenceIndex == currentSentenceIndex) {
      return const LessonPageChangePlan.warmPreviewsOnly();
    }
    return LessonPageChangePlan.seekToSentence(targetSentenceIndex);
  }
}
