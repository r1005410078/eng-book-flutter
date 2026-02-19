import 'package:flutter/material.dart';

import 'playback_settings_screen.dart';

Future<void> showPracticePlaybackSettingsSheet(BuildContext context) async {
  final height = MediaQuery.of(context).size.height;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: true,
    isDismissible: true,
    showDragHandle: true,
    backgroundColor: const Color(0xFF1a120b),
    constraints: BoxConstraints(maxHeight: height * 0.9),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const PlaybackSettingsScreen(),
  );
}
