import 'package:engbooks/src/features/practice/application/practice_playback_flow_policy.dart';
import 'package:flutter_test/flutter_test.dart';

class _GrantedProbe implements AutoRecordPermissionProbe {
  @override
  Future<bool> hasPermission() async => true;
}

class _DeniedProbe implements AutoRecordPermissionProbe {
  @override
  Future<bool> hasPermission() async => false;
}

class _UnsupportedProbe implements AutoRecordPermissionProbe {
  @override
  Future<bool> hasPermission() async {
    throw UnsupportedError('not supported');
  }
}

void main() {
  test('sentence end loops first and then advances', () {
    var remaining = 3;

    final first = decideSentenceEndAction(
      remainingLoops: remaining,
    );
    expect(first.action, SentenceEndAction.loopCurrent);
    remaining = first.nextRemainingLoops;

    final second = decideSentenceEndAction(
      remainingLoops: remaining,
    );
    expect(second.action, SentenceEndAction.loopCurrent);
    remaining = second.nextRemainingLoops;

    final third = decideSentenceEndAction(
      remainingLoops: remaining,
    );
    expect(third.action, SentenceEndAction.advance);
  });

  test('sentence end advances when remaining loops is one', () {
    final result = decideSentenceEndAction(
      remainingLoops: 1,
    );
    expect(result.action, SentenceEndAction.advance);
    expect(result.nextRemainingLoops, 1);
  });

  test('auto record availability detects permission denied and unsupported',
      () async {
    expect(
      await detectAutoRecordAvailability(_GrantedProbe()),
      AutoRecordAvailability.available,
    );
    expect(
      await detectAutoRecordAvailability(_DeniedProbe()),
      AutoRecordAvailability.permissionDenied,
    );
    expect(
      await detectAutoRecordAvailability(_UnsupportedProbe()),
      AutoRecordAvailability.unsupported,
    );
  });
}
