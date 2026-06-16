import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../controllers/auto_clicker_controller.dart';
import '../widgets/autoclicker_components.dart';

class ControlPage extends StatelessWidget {
  const ControlPage({super.key, required this.controller});

  final AutoClickerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ListView(
      padding: autoclickerPagePadding,
      children: [
        ShadCard(
          padding: const EdgeInsets.all(16),
          title: const Text('启动控制'),
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('无障碍权限', style: theme.textTheme.small),
                    ),
                    const SizedBox(width: 12),
                    ShadButton.outline(
                      enabled: !controller.accessibilityPermissionGranted,
                      onPressed: controller.openAccessibilitySettings,
                      child: Text(
                        controller.accessibilityPermissionGranted
                            ? '已授权'
                            : '去授权',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text('悬浮窗权限', style: theme.textTheme.small),
                    ),
                    const SizedBox(width: 12),
                    ShadButton.outline(
                      enabled: !controller.overlayPermissionGranted,
                      onPressed: controller.openOverlaySettings,
                      child: Text(
                        controller.overlayPermissionGranted ? '已授权' : '去授权',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (controller.overlayServiceRunning)
                  ShadButton.destructive(
                    height: 50,
                    onPressed: controller.stopOverlayService,
                    child: const Text('关闭悬浮控制'),
                  )
                else
                  ShadButton(
                    height: 50,
                    enabled: controller.canStartOverlay,
                    onPressed: controller.startOverlayService,
                    child: const Text('启动悬浮控制'),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ShadCard(
          padding: const EdgeInsets.all(16),
          title: const Text('参数设置'),
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AutoclickerSliderSetting(
                  title: '点击频率',
                  valueText: '${controller.clicksPerSecond.round()} 次/秒',
                  value: controller.clicksPerSecond,
                  min: 1,
                  max: 20,
                  onChanged: controller.setClicksPerSecond,
                  onChangeEnd: (_) => controller.syncOverlayConfiguration(),
                ),
                const SizedBox(height: 12),
                AutoclickerSliderSetting(
                  title: '默认偏移范围',
                  valueText: '${controller.jitterRadius.round()} px',
                  value: controller.jitterRadius,
                  min: 0,
                  max: 24,
                  onChanged: controller.setJitterRadius,
                  onChangeEnd: (_) => controller.syncOverlayConfiguration(),
                ),
                const SizedBox(height: 12),
                AutoclickerSliderSetting(
                  title: '准星大小',
                  valueText: '${controller.targetSize.round()} px',
                  value: controller.targetSize,
                  min: 32,
                  max: 64,
                  onChanged: controller.setTargetSize,
                  onChangeEnd: (_) => controller.syncOverlayConfiguration(),
                ),
                const SizedBox(height: 16),
                ShadButton.outline(
                  onPressed: controller.saveOverlayConfiguration,
                  child: const Text('保存当前参数'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
