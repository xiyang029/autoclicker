import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../platform/android_autoclicker_channel.dart';
import '../controllers/auto_clicker_controller.dart';
import '../models/click_configuration.dart';
import '../widgets/panel_styles.dart';
import '../widgets/slider_setting.dart';

class ConfigurationsPage extends StatelessWidget {
  const ConfigurationsPage({super.key, required this.controller});

  final AutoClickerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        ShadCard(
          title: Text('配置管理', style: theme.textTheme.h4),
          child: Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (controller.configurations.isEmpty)
                  _EmptyConfigurationList(theme: theme)
                else
                  for (final configuration in controller.configurations) ...[
                    _ConfigurationListItem(
                      configuration: configuration,
                      active: configuration.matches(
                        clicksPerSecond: controller.clicksPerSecond,
                        jitterRadius: controller.jitterRadius,
                        targetSize: controller.targetSize,
                        targetX: controller.targetX,
                        targetY: controller.targetY,
                      ),
                      canEdit: controller.canStartOverlay,
                      onRename: (name) {
                        controller.renameConfiguration(configuration, name);
                      },
                      onApply: () {
                        controller.applyConfiguration(configuration);
                      },
                      onBeforeEdit: controller.stopOverlayService,
                      onEdit: (updatedConfiguration) {
                        controller.editConfiguration(
                          configuration,
                          updatedConfiguration,
                        );
                      },
                      onDelete: () {
                        controller.deleteConfiguration(configuration);
                      },
                    ),
                    if (configuration != controller.configurations.last)
                      const SizedBox(height: 10),
                  ],
              ],
            ),
          ),
        ),
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

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: mutedPanelDecoration(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
            ),
            style: theme.textTheme.small,
            onSubmitted: widget.onRename,
            onEditingComplete: () {
              widget.onRename(_nameController.text);
              FocusScope.of(context).unfocus();
            },
          ),
          const SizedBox(height: 8),
          Text(
            '${configuration.clicksPerSecond.round()} 次/秒 · '
            '${configuration.jitterRadius.round()} px 偏移 · '
            '${configuration.targetSize.round()} px 准星 · '
            '(${configuration.targetX.round()}, ${configuration.targetY.round()})',
            style: theme.textTheme.muted,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ShadButton.outline(
                  enabled: !widget.active,
                  leading: const Icon(LucideIcons.check),
                  onPressed: widget.onApply,
                  child: Text(widget.active ? '已激活' : '应用'),
                ),
              ),
              const SizedBox(width: 8),
              ShadIconButton.outline(
                enabled: widget.canEdit,
                icon: const Icon(LucideIcons.pencil),
                onPressed: () async {
                  await _openConfigurationEditor(context);
                },
              ),
              const SizedBox(width: 8),
              ShadIconButton.destructive(
                icon: const Icon(LucideIcons.trash2),
                onPressed: () {
                  _confirmDelete(context);
                },
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
              leading: const Icon(LucideIcons.trash2),
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

  final ClickConfiguration configuration;
  final ValueChanged<ClickConfiguration> onSave;

  @override
  State<_ConfigurationEditorPage> createState() =>
      _ConfigurationEditorPageState();
}

class _ConfigurationEditorPageState extends State<_ConfigurationEditorPage> {
  late final TextEditingController _nameController;
  late double _clicksPerSecond;
  late double _jitterRadius;
  late double _targetSize;
  late double _targetX;
  late double _targetY;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    final configuration = widget.configuration;
    _nameController = TextEditingController(text: configuration.name);
    _clicksPerSecond = configuration.clicksPerSecond;
    _jitterRadius = configuration.jitterRadius;
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
    final theme = ShadTheme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _cancel();
      },
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: ShadCard(
              title: Text('编辑配置', style: theme.textTheme.h4),
              child: Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '配置名称',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SliderSetting(
                      title: '点击频率',
                      valueText: '${_clicksPerSecond.round()} 次/秒',
                      value: _clicksPerSecond,
                      min: 1,
                      max: 20,
                      divisions: 19,
                      onChanged: (value) {
                        setState(() {
                          _clicksPerSecond = value;
                        });
                      },
                      onChangeEnd: (_) {
                        _syncEditableTarget();
                      },
                    ),
                    const SizedBox(height: 18),
                    SliderSetting(
                      title: '默认偏移范围',
                      valueText: '${_jitterRadius.round()} px',
                      value: _jitterRadius,
                      min: 0,
                      max: 24,
                      divisions: 24,
                      onChanged: (value) {
                        setState(() {
                          _jitterRadius = value;
                        });
                      },
                      onChangeEnd: (_) {
                        _syncEditableTarget();
                      },
                    ),
                    const SizedBox(height: 18),
                    SliderSetting(
                      title: '准星大小',
                      valueText: '${_targetSize.round()} px',
                      value: _targetSize,
                      min: 32,
                      max: 64,
                      divisions: 22,
                      onChanged: (value) {
                        setState(() {
                          _targetSize = value;
                        });
                      },
                      onChangeEnd: (_) {
                        _syncEditableTarget();
                      },
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: mutedPanelDecoration(theme),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.crosshair,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '拖动屏幕上的悬浮光标来设置点击位置',
                              style: theme.textTheme.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
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
                            leading: const Icon(LucideIcons.save),
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
      ),
    );
  }

  Future<void> _syncEditableTarget() async {
    await AndroidAutoClickerChannel.startOverlayService(
      clicksPerSecond: _clicksPerSecond,
      jitterRadius: _jitterRadius,
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
        jitterRadius: _jitterRadius,
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

class _EmptyConfigurationList extends StatelessWidget {
  const _EmptyConfigurationList({required this.theme});

  final ShadThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: mutedPanelDecoration(theme),
      child: Row(
        children: [
          Icon(LucideIcons.listPlus, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text('还没有保存的配置', style: theme.textTheme.muted)),
        ],
      ),
    );
  }
}
