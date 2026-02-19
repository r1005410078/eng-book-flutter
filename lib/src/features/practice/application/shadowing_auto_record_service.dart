import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'practice_playback_flow_policy.dart';

class ShadowingAutoRecordStartResult {
  final bool started;
  final String? warning;

  const ShadowingAutoRecordStartResult({
    required this.started,
    this.warning,
  });
}

class ShadowingAutoRecordService {
  final AudioRecorder recorder;
  final Future<Directory> Function() tempDirProvider;

  ShadowingAutoRecordService(
    this.recorder, {
    Future<Directory> Function()? tempDirProvider,
  }) : tempDirProvider = tempDirProvider ?? getTemporaryDirectory;

  Future<ShadowingAutoRecordStartResult> tryStart({
    required String sentenceId,
  }) async {
    final availability = await detectAutoRecordAvailability(
      AudioRecorderPermissionProbe(recorder),
    );
    if (availability == AutoRecordAvailability.permissionDenied) {
      return const ShadowingAutoRecordStartResult(
        started: false,
        warning: '录音权限未开启，自动录音已跳过。',
      );
    }
    if (availability == AutoRecordAvailability.unsupported) {
      return const ShadowingAutoRecordStartResult(
        started: false,
        warning: '当前设备不支持自动录音，已跳过录音。',
      );
    }

    try {
      final recordPath = await _nextRecordPath(sentenceId);
      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          bitRate: 64000,
        ),
        path: recordPath,
      );
      return const ShadowingAutoRecordStartResult(started: true);
    } catch (_) {
      return const ShadowingAutoRecordStartResult(
        started: false,
        warning: '录音启动失败，已跳过本句录音。',
      );
    }
  }

  Future<void> stop() async {
    try {
      await recorder.stop();
    } catch (_) {
      // Ignore stop failures to keep pipeline flowing.
    }
  }

  Future<String> _nextRecordPath(String sentenceId) async {
    final baseDir = await tempDirProvider();
    final folder = Directory('${baseDir.path}/shadowing_records');
    if (!folder.existsSync()) {
      folder.createSync(recursive: true);
    }
    final ts = DateTime.now().millisecondsSinceEpoch;
    final safeId = sentenceId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return '${folder.path}/${safeId}_$ts.m4a';
  }
}
