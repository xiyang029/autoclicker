import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../controllers/auto_clicker_controller.dart';
import '../widgets/autoclicker_components.dart';

class ControlPage extends StatefulWidget {
  const ControlPage({super.key, required this.controller});

  /// 标识当前页面共享的自动点击控制器。
  final AutoClickerController controller;

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  /// 标识参数自动保存的防抖计时器。
  Timer? _configurationSaveDebounce;

  /// 延迟保存并同步当前参数，避免连续输入时重复触发平台调用。
  void _scheduleDebouncedConfigurationSave() {
    _configurationSaveDebounce?.cancel();
    _configurationSaveDebounce = Timer(const Duration(seconds: 1), () {
      widget.controller.saveOverlayConfiguration();
    });
  }

  @override
  void dispose() {
    _configurationSaveDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: autoclickerPagePadding,
      children: [
        AutoclickerSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PermissionRow(
                label: '无障碍权限',
                description: '负责执行系统点击操作',
                granted: widget.controller.accessibilityPermissionGranted,
                onPressed: widget.controller.openAccessibilitySettings,
              ),
              const SizedBox(height: 12),
              _PermissionRow(
                label: '悬浮窗权限',
                description: '负责展示准星与控制面板',
                granted: widget.controller.overlayPermissionGranted,
                onPressed: widget.controller.openOverlaySettings,
              ),
              const SizedBox(height: 16),
              if (widget.controller.overlayServiceRunning)
                ShadButton.destructive(
                  height: 48,
                  onPressed: widget.controller.stopOverlayService,
                  child: const Text('关闭悬浮控制'),
                )
              else
                ShadButton(
                  height: 48,
                  enabled: widget.controller.canStartOverlay,
                  onPressed: widget.controller.startOverlayService,
                  child: const Text('启动悬浮控制'),
                ),
              const SizedBox(height: 18),
              AutoclickerInputSetting(
                title: '点击频率',
                value: widget.controller.clicksPerSecond.round().toString(),
                suffixText: '次/秒',
                onChanged: (value) {
                  final parsedValue = double.tryParse(value);
                  if (parsedValue == null) return;
                  widget.controller.setClicksPerSecond(
                    parsedValue.clamp(1, 20),
                  );
                  _scheduleDebouncedConfigurationSave();
                },
                onSubmitted: (_) => _scheduleDebouncedConfigurationSave(),
              ),
              const SizedBox(height: 14),
              AutoclickerSelectSetting(
                title: '准星大小',
                value: widget.controller.targetSize,
                options: autoclickerTargetSizeOptions,
                onChanged: (value) {
                  widget.controller.setTargetSize(value);
                  _scheduleDebouncedConfigurationSave();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.label,
    required this.description,
    required this.granted,
    required this.onPressed,
  });

  /// 标识权限项的名称。
  final String label;

  /// 标识权限项的用途说明。
  final String description;

  /// 标识当前权限是否已授权。
  final bool granted;

  /// 标识当前权限项的跳转动作。
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.small),
                const SizedBox(height: 4),
                Text(description, style: theme.textTheme.muted),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ShadButton.outline(
            enabled: !granted,
            onPressed: onPressed,
            child: Text(granted ? '已授权' : '去授权'),
          ),
        ],
      ),
    );
  }
}
