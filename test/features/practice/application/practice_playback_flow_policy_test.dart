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
  test('auto record availability detects available/denied/unsupported',
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
