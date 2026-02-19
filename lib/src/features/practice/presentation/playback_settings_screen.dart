import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PlaybackSettingsScreen extends ConsumerStatefulWidget {
  final bool asBottomSheet;

  const PlaybackSettingsScreen({
    super.key,
    this.asBottomSheet = false,
  });

  @override
  ConsumerState<PlaybackSettingsScreen> createState() =>
      _PlaybackSettingsScreenState();
}

class _PlaybackSettingsScreenState
    extends ConsumerState<PlaybackSettingsScreen> {
  // Mock State
  double _playbackSpeed = 1.0;
  bool _showEnglish = true;
  bool _showChinese = true;
  bool _blurTranslation = false;
  int _loopCount = 3;
  bool _autoPause = true;
  bool _autoRecord = false;
  double _fontSize = 0.5; // Slider value 0.0 to 1.0

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF1a120b); // Dark brown/black as per latest design
    const accentColor = Color(0xFFFF9F29); // Orange

    final content = ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSpeedSection(accentColor),
        const SizedBox(height: 32),
        _buildSubtitleSection(accentColor),
        const SizedBox(height: 32),
        _buildBehaviorSection(accentColor),
        const SizedBox(height: 32),
        _buildInterfaceSection(accentColor),
        const SizedBox(height: 32),
        Center(
          child: Text(
            'PLAYER VERSION 2.4.0 (100LS BUILD)',
            style:
                TextStyle(color: Colors.white.withOpacity(0.1), fontSize: 10),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );

    if (widget.asBottomSheet) {
      return ColoredBox(color: bgColor, child: content);
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildPageAppBar(accentColor),
      body: content,
    );
  }

  PreferredSizeWidget _buildPageAppBar(Color accentColor) {
    return AppBar(
      backgroundColor: const Color(0xFF1a120b),
      elevation: 0,
      centerTitle: true,
      title: const Text(
        '播放设置',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      leading: IconButton(
        icon:
            const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
        onPressed: () => context.pop(),
      ),
      actions: [
        TextButton(
          onPressed: () {
            // TODO: Reset logic
          },
          child: Text(
            '重置',
            style: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
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

  Widget _buildSpeedSection(Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('播放语速'),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _buildSpeedButton(0.5, accentColor),
              _buildSpeedButton(0.75, accentColor),
              _buildSpeedButton(1.0, accentColor),
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

  Widget _buildSpeedButton(double speed, Color accentColor) {
    final isSelected = _playbackSpeed == speed;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _playbackSpeed = speed;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF3E3524)
                : Colors.transparent, // Dark yellowish brown for selected
            borderRadius: BorderRadius.circular(8),
            // border: isSelected ? Border.all(color: accentColor.withOpacity(0.5)) : null,
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

  Widget _buildSubtitleSection(Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('字幕显示'),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _buildSwitchTile(
                title: '显示原文 (英文)',
                icon: Icons.translate,
                value: _showEnglish,
                onChanged: (v) => setState(() => _showEnglish = v),
                accentColor: accentColor,
              ),
              Divider(height: 1, color: Colors.white.withOpacity(0.05)),
              _buildSwitchTile(
                title: '显示译文 (中文)',
                icon: Icons.subtitles,
                value: _showChinese,
                onChanged: (v) => setState(() => _showChinese = v),
                accentColor: accentColor,
              ),
              Divider(height: 1, color: Colors.white.withOpacity(0.05)),
              _buildSwitchTile(
                title: '默认模糊译文',
                subtitle: '点击译文区域才显示，辅助主动回忆',
                icon: Icons.blur_on,
                value: _blurTranslation,
                onChanged: (v) => setState(() => _blurTranslation = v),
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
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.grey, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(color: Colors.white, fontSize: 16)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(subtitle,
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.7,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.white,
              activeTrackColor: accentColor,
              inactiveThumbColor: Colors.grey,
              inactiveTrackColor: Colors.grey.withOpacity(0.2),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBehaviorSection(Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('播放行为'),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // Loop Counter
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.repeat_one,
                          color: Colors.grey, size: 20),
                    ),
                    const SizedBox(width: 16),
                    const Text('单句循环次数',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          _buildCounterButton(Icons.remove, () {
                            if (_loopCount > 1) setState(() => _loopCount--);
                          }),
                          Container(
                            width: 32,
                            alignment: Alignment.center,
                            child: Text(
                              '$_loopCount',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14),
                            ),
                          ),
                          _buildCounterButton(Icons.add, () {
                            setState(() => _loopCount++);
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.white.withOpacity(0.05)),
              _buildSwitchTile(
                title: '句末自动暂停',
                subtitle: '留出跟读时间',
                icon: Icons.timer_outlined,
                value: _autoPause,
                onChanged: (v) => setState(() => _autoPause = v),
                accentColor: accentColor,
              ),
              Divider(height: 1, color: Colors.white.withOpacity(0.05)),
              _buildSwitchTile(
                title: '自动录音',
                icon: Icons.mic_none,
                value: _autoRecord,
                onChanged: (v) => setState(() => _autoRecord = v),
                accentColor: accentColor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCounterButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: Colors.transparent,
        child: Icon(icon, color: Colors.grey, size: 16),
      ),
    );
  }

  Widget _buildInterfaceSection(Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('界面设置'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
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
                      Text('字幕大小',
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                    ],
                  ),
                  Text('标准',
                      style: TextStyle(color: accentColor, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('A',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: accentColor,
                        inactiveTrackColor: Colors.grey.withOpacity(0.2),
                        thumbColor: Colors.white,
                        overlayColor: accentColor.withOpacity(0.2),
                        trackHeight: 4,
                      ),
                      child: Slider(
                        value: _fontSize,
                        onChanged: (v) => setState(() => _fontSize = v),
                        min: 0.0,
                        max: 1.0,
                        divisions: 10,
                      ),
                    ),
                  ),
                  const Text('A',
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
