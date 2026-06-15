import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../controllers/auto_clicker_controller.dart';
import '../widgets/panel_styles.dart';
import '../widgets/slider_setting.dart';

class ControlPage extends StatelessWidget {
  const ControlPage({super.key, required this.controller});

  final AutoClickerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final sliderSections = [
      _ControlSliderSection(
        title: '点击频率',
        valueText: '${controller.clicksPerSecond.round()} 次/秒',
        value: controller.clicksPerSecond,
        min: 1,
        max: 20,
        divisions: 19,
        onChanged: controller.setClicksPerSecond,
      ),
      _ControlSliderSection(
        title: '默认偏移范围',
        valueText: '${controller.jitterRadius.round()} px',
        value: controller.jitterRadius,
        min: 0,
        max: 24,
        divisions: 24,
        onChanged: controller.setJitterRadius,
      ),
      _ControlSliderSection(
        title: '准星大小',
        valueText: '${controller.targetSize.round()} px',
        value: controller.targetSize,
        min: 32,
        max: 64,
        divisions: 22,
        onChanged: controller.setTargetSize,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        ShadCard(
          title: Text('启动面板', style: theme.textTheme.h4),
          child: Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PermissionRow(
                  icon: LucideIcons.shield,
                  title: '无障碍权限',
                  actionText: controller.accessibilityPermissionGranted
                      ? '已开启'
                      : '去开启',
                  granted: controller.accessibilityPermissionGranted,
                  onPressed: controller.openAccessibilitySettings,
                ),
                const SizedBox(height: 12),
                _PermissionRow(
                  icon: LucideIcons.panelsTopLeft,
                  title: '悬浮窗权限',
                  actionText: controller.overlayPermissionGranted
                      ? '已授权'
                      : '去授权',
                  granted: controller.overlayPermissionGranted,
                  onPressed: controller.openOverlaySettings,
                ),
                const SizedBox(height: 20),
                if (controller.overlayServiceRunning)
                  ShadButton.destructive(
                    height: 48,
                    leading: const Icon(LucideIcons.x),
                    onPressed: controller.stopOverlayService,
                    child: const Text('关闭悬浮控制'),
                  )
                else
                  ShadButton(
                    height: 48,
                    enabled: controller.canStartOverlay,
                    leading: const Icon(LucideIcons.play),
                    onPressed: controller.startOverlayService,
                    child: const Text('启动悬浮控制'),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ShadCard(
          title: Text('设置', style: theme.textTheme.h4),
          child: Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final indexedSlider in sliderSections.indexed) ...[
                  SliderSetting(
                    title: indexedSlider.$2.title,
                    valueText: indexedSlider.$2.valueText,
                    value: indexedSlider.$2.value,
                    min: indexedSlider.$2.min,
                    max: indexedSlider.$2.max,
                    divisions: indexedSlider.$2.divisions,
                    onChanged: indexedSlider.$2.onChanged,
                    onChangeEnd: (_) {
                      controller.syncOverlayConfiguration();
                    },
                  ),
                  if (indexedSlider.$1 != sliderSections.length - 1)
                    const SizedBox(height: 22),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ShadButton.outline(
                    leading: const Icon(LucideIcons.save),
                    onPressed: controller.saveOverlayConfiguration,
                    child: const Text('保存当前参数'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ControlSliderSection {
  const _ControlSliderSection({
    required this.title,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String title;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.actionText,
    required this.granted,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String actionText;
  final bool granted;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: mutedPanelDecoration(theme),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: theme.textTheme.small)),
          const SizedBox(width: 12),
          ShadButton.outline(
            enabled: !granted,
            onPressed: onPressed,
            child: Text(actionText),
          ),
        ],
      ),
    );
  }
}
