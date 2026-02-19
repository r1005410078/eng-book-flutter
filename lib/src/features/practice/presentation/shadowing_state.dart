class ShadowingState {
  final bool isMode;
  final bool locked;
  final bool busy;
  final bool recording;
  final ShadowingPhase phase;
  final Duration remaining;

  const ShadowingState({
    required this.isMode,
    required this.locked,
    required this.busy,
    required this.recording,
    required this.phase,
    required this.remaining,
  });

  static const idle = ShadowingState(
    isMode: false,
    locked: false,
    busy: false,
    recording: false,
    phase: ShadowingPhase.idle,
    remaining: Duration.zero,
  );

  ShadowingState copyWith({
    bool? isMode,
    bool? locked,
    bool? busy,
    bool? recording,
    ShadowingPhase? phase,
    Duration? remaining,
  }) {
    return ShadowingState(
      isMode: isMode ?? this.isMode,
      locked: locked ?? this.locked,
      busy: busy ?? this.busy,
      recording: recording ?? this.recording,
      phase: phase ?? this.phase,
      remaining: remaining ?? this.remaining,
    );
  }
}

enum ShadowingPhase { idle, listening, recording, advancing }
