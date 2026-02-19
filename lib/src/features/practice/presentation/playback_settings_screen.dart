import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/practice_playback_settings_provider.dart';
import '../data/practice_playback_settings_store.dart';

class PlaybackSettingsScreen extends ConsumerWidget {
  const PlaybackSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const bgColor = Color(0xFF1a120b);
    const accentColor = Color(0xFFFF9F29);

    final settings = ref.watch(practicePlaybackSettingsProvider);
    final controller = ref.read(practicePlaybackSettingsProvider.notifier);

    final content = ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSpeedSection(settings, controller, accentColor),
        const SizedBox(height: 32),
        _buildSubtitleSection(settings, controller, accentColor),
        const SizedBox(height: 32),
        _buildBehaviorSection(settings, controller, accentColor),
        const SizedBox(height: 32),
        _buildInterfaceSection(settings, controller, accentColor),
        const SizedBox(height: 32),
        Center(
          child: Text(
            'PLAYER VERSION 2.4.0 (100LS BUILD)',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.1),
              fontSize: 10,
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );

    return ColoredBox(color: bgColor, child: content);
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSpeedSection(
    PracticePlaybackSettings settings,
    PracticePlaybackSettingsController controller,
    Color accentColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('播放语速'),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _buildSpeedButton(0.5, settings.playbackSpeed, accentColor, () {
                controller.setPlaybackSpeed(0.5);
              }),
              _buildSpeedButton(0.75, settings.playbackSpeed, accentColor, () {
                controller.setPlaybackSpeed(0.75);
              }),
              _buildSpeedButton(1.0, settings.playbackSpeed, accentColor, () {
                controller.setPlaybackSpeed(1.0);
              }),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '降低语速有助于听清连读和弱读细节。',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSpeedButton(
    double speed,
    double current,
    Color accentColor,
    VoidCallback onTap,
  ) {
    final isSelected = current == speed;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF3E3524) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            '${speed}x',
            style: TextStyle(
              color: isSelected ? accentColor : Colors.grey,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitleSection(
    PracticePlaybackSettings settings,
    PracticePlaybackSettingsController controller,
    Color accentColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('字幕显示'),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _buildSwitchTile(
                title: '显示原文 (英文)',
                icon: Icons.translate,
                value: settings.showEnglish,
                onChanged: controller.setShowEnglish,
                accentColor: accentColor,
              ),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
              _buildSwitchTile(
                title: '显示译文 (中文)',
                icon: Icons.subtitles,
                value: settings.showChinese,
                onChanged: controller.setShowChinese,
                accentColor: accentColor,
              ),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
              _buildSwitchTile(
                title: '默认模糊译文',
                subtitle: '点击译文区域才显示，辅助主动回忆',
                icon: Icons.blur_on,
                value: settings.blurTranslationByDefault,
                onChanged: controller.setBlurTranslationByDefault,
                accentColor: accentColor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    String? subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color accentColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.grey, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.7,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: accentColor,
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return Colors.grey;
              }),
              inactiveTrackColor: Colors.grey.withValues(alpha: 0.2),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBehaviorSection(
    PracticePlaybackSettings settings,
    PracticePlaybackSettingsController controller,
    Color accentColor,
  ) {
    final modeLabels = <PlaybackCompletionMode, String>{
      PlaybackCompletionMode.unitLoop: '单元循环',
      PlaybackCompletionMode.courseLoop: '课程循环',
      PlaybackCompletionMode.pauseAfterFinish: '播放完暂停',
      PlaybackCompletionMode.allCoursesLoop: '所有课程循环',
    };
    final modeIcons = <PlaybackCompletionMode, IconData>{
      PlaybackCompletionMode.unitLoop: Icons.repeat,
      PlaybackCompletionMode.courseLoop: Icons.menu_book_rounded,
      PlaybackCompletionMode.pauseAfterFinish: Icons.pause_circle_outline,
      PlaybackCompletionMode.allCoursesLoop: Icons.all_inclusive_rounded,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('播放行为'),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '播放完成后',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final itemWidth = (constraints.maxWidth - 8) / 2;
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: PlaybackCompletionMode.values.map((mode) {
                            final selected = settings.completionMode == mode;
                            return SizedBox(
                              width: itemWidth,
                              child: GestureDetector(
                                onTap: () => controller.setCompletionMode(mode),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 130),
                                  curve: Curves.easeOut,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? accentColor.withValues(alpha: 0.2)
                                        : Colors.white.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(11),
                                    border: Border.all(
                                      color: selected
                                          ? accentColor.withValues(alpha: 0.72)
                                          : Colors.white
                                              .withValues(alpha: 0.08),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: _buildCompletionModeChip(
                                    selected: selected,
                                    icon: modeIcons[mode]!,
                                    label: modeLabels[mode]!,
                                    accentColor: accentColor,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
              _buildSwitchTile(
                title: '自动录音',
                icon: Icons.mic_none,
                value: settings.autoRecord,
                onChanged: controller.setAutoRecord,
                accentColor: accentColor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionModeChip({
    required bool selected,
    required IconData icon,
    required String label,
    required Color accentColor,
  }) {
    final color = selected ? accentColor : Colors.white.withValues(alpha: 0.78);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInterfaceSection(
    PracticePlaybackSettings settings,
    PracticePlaybackSettingsController controller,
    Color accentColor,
  ) {
    final scale = settings.subtitleScale;
    final scaleLabel = scale < 0.34 ? '较小' : (scale < 0.67 ? '标准' : '较大');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('界面设置'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.format_size, color: Colors.grey, size: 20),
                      SizedBox(width: 12),
                      Text(
                        '字幕大小',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                  Text(
                    scaleLabel,
                    style: TextStyle(color: accentColor, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    'A',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: accentColor,
                        inactiveTrackColor: Colors.grey.withValues(alpha: 0.2),
                        thumbColor: Colors.white,
                        overlayColor: accentColor.withValues(alpha: 0.2),
                        trackHeight: 4,
                      ),
                      child: Slider(
                        value: scale,
                        onChanged: controller.setSubtitleScale,
                        min: 0.0,
                        max: 1.0,
                        divisions: 10,
                      ),
                    ),
                  ),
                  const Text(
                    'A',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
