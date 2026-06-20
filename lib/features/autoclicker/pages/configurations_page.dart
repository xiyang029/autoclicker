import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../controllers/auto_clicker_controller.dart';
import '../models/click_configuration.dart';
import '../services/android_autoclicker_channel.dart';
import '../widgets/autoclicker_components.dart';

class ConfigurationsPage extends StatelessWidget {
  const ConfigurationsPage({super.key, required this.controller});

  /// 标识当前页面共享的自动点击控制器。
  final AutoClickerController controller;

  @override
  Widget build(BuildContext context) {
    final configurations = controller.configurations;

    return ListView(
      padding: autoclickerPagePadding,
      children: [
        ...(configurations.isEmpty
            ? [
                AutoclickerSection(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('还没有配置', style: ShadTheme.of(context).textTheme.h4),
                    ],
                  ),
                ),
              ]
            : [
                for (final entry in configurations.asMap().entries) ...[
                  _ConfigurationListItem(
                    configuration: entry.value,
                    active: controller.isActiveConfiguration(entry.value),
                    canEdit: controller.canStartOverlay,
                    onRename: (name) =>
                        controller.renameConfiguration(entry.value, name),
                    onApply: () => controller.applyConfiguration(entry.value),
                    onBeforeEdit: controller.stopOverlayService,
                    onEdit: (updatedConfiguration) => controller
                        .editConfiguration(entry.value, updatedConfiguration),
                    onDelete: () => controller.deleteConfiguration(entry.value),
                  ),
                  if (entry.key != configurations.length - 1)
                    const SizedBox(height: 12),
                ],
              ]),
      ],
    );
  }
}

class _ConfigurationListItem extends StatefulWidget {
  const _ConfigurationListItem({
    required this.configuration,
    required this.active,
    required this.canEdit,
    required this.onRename,
    required this.onApply,
    required this.onBeforeEdit,
    required this.onEdit,
    required this.onDelete,
  });

  final ClickConfiguration configuration;
  final bool active;
  final bool canEdit;
  final ValueChanged<String> onRename;
  final VoidCallback onApply;
  final Future<void> Function() onBeforeEdit;
  final ValueChanged<ClickConfiguration> onEdit;
  final VoidCallback onDelete;

  @override
  State<_ConfigurationListItem> createState() => _ConfigurationListItemState();
}

class _ConfigurationListItemState extends State<_ConfigurationListItem> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.configuration.name);
  }

  @override
  void didUpdateWidget(covariant _ConfigurationListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.configuration.name != widget.configuration.name) {
      _nameController.text = widget.configuration.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final configuration = widget.configuration;
    final targetSizeOption = closestAutoclickerOption(
      autoclickerTargetSizeOptions,
      configuration.targetSize,
    );

    return AutoclickerSection(
      padding: const EdgeInsets.all(14),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _nameController.text,
              style: theme.textTheme.large.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${configuration.clicksPerSecond.round()} 次/秒 · 准星 ${targetSizeOption.label}',
              style: theme.textTheme.muted,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ShadButton.outline(
                    enabled: !widget.active,
                    onPressed: widget.onApply,
                    child: Text(widget.active ? '已激活' : '激活'),
                  ),
                ),
                const SizedBox(width: 10),
                ShadIconButton.outline(
                  enabled: widget.canEdit,
                  icon: const Icon(LucideIcons.pencil, size: 18),
                  onPressed: () async =>
                      await _openConfigurationEditor(context),
                ),
                const SizedBox(width: 10),
                ShadIconButton.destructive(
                  icon: const Icon(LucideIcons.trash2, size: 18),
                  onPressed: () => _confirmDelete(context),
                ),
              ],
            ),
          ],
        ),
    );
  }

  Future<void> _openConfigurationEditor(BuildContext context) async {
    final navigator = Navigator.of(context);
    await widget.onBeforeEdit();
    if (!mounted) return;

    await navigator.push(
      MaterialPageRoute<void>(
        builder: (context) {
          return _ConfigurationEditorPage(
            configuration: widget.configuration,
            onSave: widget.onEdit,
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final shouldDelete = await showShadDialog<bool>(
      context: context,
      builder: (context) {
        return ShadDialog.alert(
          radius: const BorderRadius.all(Radius.circular(12)),
          removeBorderRadiusWhenTiny: false,
          useSafeArea: false,
          title: const Text('删除配置'),
          description: Text('确定删除「${widget.configuration.name}」吗？'),
          actions: [
            ShadButton.outline(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('取消'),
            ),
            ShadButton.destructive(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      widget.onDelete();
    }
  }
}

class _ConfigurationEditorPage extends StatefulWidget {
  const _ConfigurationEditorPage({
    required this.configuration,
    required this.onSave,
  });

  /// 标识当前正在编辑的配置快照。
  final ClickConfiguration configuration;

  /// 标识保存编辑结果时的回调动作。
  final ValueChanged<ClickConfiguration> onSave;

  @override
  State<_ConfigurationEditorPage> createState() =>
      _ConfigurationEditorPageState();
}

class _ConfigurationEditorPageState extends State<_ConfigurationEditorPage> {
  /// 缓存配置名称输入框控制器，保证编辑态可回显。
  late final TextEditingController _nameController;

  /// 标识当前编辑中的点击频率值。
  late double _clicksPerSecond;

  /// 标识当前编辑中的准星尺寸值。
  late double _targetSize;

  /// 标识当前编辑中的准星横向坐标。
  late double _targetX;

  /// 标识当前编辑中的准星纵向坐标。
  late double _targetY;

  /// 标识编辑页是否已经进入关闭流程，避免重复停服。
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    final configuration = widget.configuration;
    _nameController = TextEditingController(text: configuration.name);
    _clicksPerSecond = configuration.clicksPerSecond;
    _targetSize = configuration.targetSize;
    _targetX = configuration.targetX;
    _targetY = configuration.targetY;
    _syncEditableTarget();
  }

  @override
  void dispose() {
    if (!_closing) {
      AndroidAutoClickerChannel.stopOverlayService();
    }
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _cancel();
      },
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: autoclickerPagePadding,
            child: AutoclickerSection(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ShadInput(
                    controller: _nameController,
                    placeholder: const Text('请输入配置名称'),
                  ),
                  const SizedBox(height: 14),
                  AutoclickerInputSetting(
                    title: '点击频率',
                    value: _clicksPerSecond.round().toString(),
                    suffixText: '次/秒',
                    onChanged: (value) {
                      final parsedValue = double.tryParse(value);
                      if (parsedValue == null) return;
                      setState(() {
                        _clicksPerSecond = parsedValue.clamp(1, 20);
                      });
                    },
                    onSubmitted: (_) {
                      _syncEditableTarget();
                    },
                  ),
                  const SizedBox(height: 12),
                  AutoclickerSelectSetting(
                    title: '准星大小',
                    value: _targetSize,
                    options: autoclickerTargetSizeOptions,
                    onChanged: (value) {
                      setState(() {
                        _targetSize = value;
                      });
                      _syncEditableTarget();
                    },
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: ShadButton.outline(
                          onPressed: _cancel,
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ShadButton(
                          onPressed: _save,
                          child: const Text('保存'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _syncEditableTarget() async {
    /// 标识编辑态下最近一次拖动后的准星坐标快照。
    final latestPosition =
        await AndroidAutoClickerChannel.loadOverlayConfiguration();
    _targetX = latestPosition['targetX'] ?? _targetX;
    _targetY = latestPosition['targetY'] ?? _targetY;
    await AndroidAutoClickerChannel.startOverlayService(
      clicksPerSecond: _clicksPerSecond,
      jitterRadius: autoclickerFixedJitterRadius,
      targetSize: _targetSize,
      targetX: _targetX,
      targetY: _targetY,
      targetOnly: true,
    );
  }

  Future<void> _save() async {
    final latestPosition =
        await AndroidAutoClickerChannel.loadOverlayConfiguration();
    if (!mounted) return;

    final navigator = Navigator.of(context);

    widget.onSave(
      widget.configuration.copyWith(
        name: _nameController.text,
        clicksPerSecond: _clicksPerSecond,
        jitterRadius: autoclickerFixedJitterRadius,
        targetSize: _targetSize,
        targetX: latestPosition['targetX'] ?? _targetX,
        targetY: latestPosition['targetY'] ?? _targetY,
      ),
    );
    await _closeEditorOverlay();
    navigator.pop();
  }

  Future<void> _cancel() async {
    final navigator = Navigator.of(context);

    await _closeEditorOverlay();
    if (!mounted) return;
    navigator.pop();
  }

  Future<void> _closeEditorOverlay() async {
    if (_closing) return;

    _closing = true;
    await AndroidAutoClickerChannel.stopOverlayService();
  }
}
