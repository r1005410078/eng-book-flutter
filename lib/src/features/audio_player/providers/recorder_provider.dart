import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

part 'recorder_provider.g.dart';

class RecorderState {
  final bool isRecording;
  final String? path;
  final bool hasPermission;

  const RecorderState({
    this.isRecording = false,
    this.path,
    this.hasPermission = false,
  });

  RecorderState copyWith({
    bool? isRecording,
    String? path,
    bool? hasPermission,
  }) {
    return RecorderState(
      isRecording: isRecording ?? this.isRecording,
      path: path ?? this.path,
      hasPermission: hasPermission ?? this.hasPermission,
    );
  }
}

@riverpod
class RecorderController extends _$RecorderController {
  late final AudioRecorder _audioRecorder;

  @override
  RecorderState build() {
    _audioRecorder = AudioRecorder();
    ref.onDispose(() {
      _audioRecorder.dispose();
    });
    return const RecorderState();
  }

  Future<void> checkPermission() async {
    final hasPermission = await _audioRecorder.hasPermission();
    state = state.copyWith(hasPermission: hasPermission);
  }

  Future<void> start() async {
    try {
      if (!await _audioRecorder.hasPermission()) {
        state = state.copyWith(hasPermission: false);
        return;
      }
      state = state.copyWith(hasPermission: true);

      final directory = await getApplicationDocumentsDirectory();
      // Use a fixed name for simple practice, or dynamic for history.
      // For now, simple replace.
      final fileName = 'current_practice.m4a';
      final path = '${directory.path}/$fileName';

      const config = RecordConfig();

      // Ensure directory exists (usually does for AppDocsDir)

      await _audioRecorder.start(config, path: path);

      state = state.copyWith(isRecording: true, path: path);
    } catch (e) {
      print("Recorder: Error starting: $e");
    }
  }

  Future<String?> stop() async {
    try {
      final path = await _audioRecorder.stop();
      state = state.copyWith(isRecording: false, path: path);
      return path;
    } catch (e) {
      print("Recorder: Error stopping: $e");
      state = state.copyWith(isRecording: false);
      return null;
    }
  }

  Future<void> toggle() async {
    if (state.isRecording) {
      await stop();
    } else {
      await start();
    }
  }
}
