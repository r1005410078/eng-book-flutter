import 'package:record/record.dart';

enum AutoRecordAvailability {
  available,
  permissionDenied,
  unsupported,
}

abstract class AutoRecordPermissionProbe {
  Future<bool> hasPermission();
}

class AudioRecorderPermissionProbe implements AutoRecordPermissionProbe {
  final AudioRecorder recorder;

  AudioRecorderPermissionProbe(this.recorder);

  @override
  Future<bool> hasPermission() {
    return recorder.hasPermission();
  }
}

Future<AutoRecordAvailability> detectAutoRecordAvailability(
  AutoRecordPermissionProbe probe,
) async {
  try {
    final granted = await probe.hasPermission();
    return granted
        ? AutoRecordAvailability.available
        : AutoRecordAvailability.permissionDenied;
  } catch (_) {
    return AutoRecordAvailability.unsupported;
  }
}
