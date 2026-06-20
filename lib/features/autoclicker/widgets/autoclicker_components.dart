import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const autoclickerPagePadding = EdgeInsets.fromLTRB(16, 16, 16, 24);
const autoclickerCardPadding = EdgeInsets.all(16);
const autoclickerSectionGap = SizedBox(height: 12);

/// 标识自动点击偏移的固定默认值，避免界面继续暴露冗余选择。
const double autoclickerFixedJitterRadius = 4.0;

class AutoclickerSection extends StatelessWidget {
  const AutoclickerSection({
    super.key,
    required this.child,
    this.padding = autoclickerCardPadding,
  });

  /// 承载当前分组的核心内容区域。
  final Widget child;

  /// 标识当前分组容器的内边距。
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.border.withValues(alpha: 0.8),
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class AutoclickerInputSetting extends StatefulWidget {
  const AutoclickerInputSetting({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.onSubmitted,
    this.suffixText,
  });

  /// 标识输入项的名称。
  final String title;

  /// 标识输入项当前展示值。
  final String value;

  /// 标识输入项尾部的单位文本。
  final String? suffixText;

  /// 标识输入内容变化时的同步动作。
  final ValueChanged<String> onChanged;

  /// 标识输入提交后的同步动作。
  final ValueChanged<String>? onSubmitted;

  @override
  State<AutoclickerInputSetting> createState() =>
      _AutoclickerInputSettingState();
}

class _AutoclickerInputSettingState extends State<AutoclickerInputSetting> {
  /// 缓存输入框控制器，保证外部值变化时可同步回显。
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant AutoclickerInputSetting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.title, style: theme.textTheme.small),
        const SizedBox(height: 8),
        ShadInput(
          controller: _controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          placeholder: Text(widget.title),
          decoration: autoclickerFieldDecoration(context),
          trailing: widget.suffixText == null
              ? null
              : Text(widget.suffixText!, style: theme.textTheme.muted),
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
        ),
      ],
    );
  }
}

class AutoclickerSelectOption {
  const AutoclickerSelectOption({required this.label, required this.value});

  /// 标识当前档位在界面中的展示文案。
  final String label;

  /// 标识当前档位对应的实际参数值。
  final double value;
}

const autoclickerTargetSizeOptions = <AutoclickerSelectOption>[
  AutoclickerSelectOption(label: '小', value: 64),
  AutoclickerSelectOption(label: '正常', value: 80),
  AutoclickerSelectOption(label: '大', value: 96),
];

class AutoclickerSelectSetting extends StatelessWidget {
  const AutoclickerSelectSetting({
    super.key,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  /// 标识下拉项的名称。
  final String title;

  /// 标识选中值变化时的同步动作。
  final ValueChanged<double> onChanged;

  /// 标识当前选中的实际参数值。
  final double value;

  /// 标识当前下拉项可选的档位列表。
  final List<AutoclickerSelectOption> options;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final selectedOption = closestAutoclickerOption(options, value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: theme.textTheme.small),
        const SizedBox(height: 8),
        ShadSelect<String>(
          initialValue: selectedOption.label,
          placeholder: const Text('请选择'),
          decoration: autoclickerFieldDecoration(context),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          options: options
              .map(
                (option) => ShadOption<String>(
                  value: option.label,
                  child: Text(option.label),
                ),
              )
              .toList(),
          selectedOptionBuilder: (context, value) => Text(value),
          onChanged: (selectedLabel) {
            if (selectedLabel == null) return;
            for (final option in options) {
              if (option.label == selectedLabel) {
                onChanged(option.value);
                break;
              }
            }
          },
        ),
      ],
    );
  }
}

/// 根据当前值匹配最接近的预设档位，保证旧数据也能落到可选项上。
AutoclickerSelectOption closestAutoclickerOption(
  List<AutoclickerSelectOption> options,
  double value,
) {
  var matchedOption = options.first;
  var minDistance = (matchedOption.value - value).abs();

  for (final option in options.skip(1)) {
    final distance = (option.value - value).abs();
    if (distance < minDistance) {
      matchedOption = option;
      minDistance = distance;
    }
  }

  return matchedOption;
}

/// 构建紧凑焦点样式，避免 shad 默认 secondary ring 产生额外外边距。
ShadDecoration autoclickerFieldDecoration(BuildContext context) {
  final theme = ShadTheme.of(context);

  return ShadDecoration(
    color: theme.colorScheme.background,
    border: ShadBorder.all(
      width: 1,
      color: theme.colorScheme.border,
      radius: BorderRadius.circular(14),
    ),
    focusedBorder: ShadBorder.all(
      width: 1,
      color: theme.colorScheme.primary.withValues(alpha: 0.55),
      radius: BorderRadius.circular(14),
    ),
    secondaryBorder: ShadBorder.none,
    secondaryFocusedBorder: ShadBorder.none,
    disableSecondaryBorder: true,
  );
}

/// 构建更紧凑的文本输入框样式，减少冗余留白。
InputDecoration autoclickerInputDecoration(
  BuildContext context, {
  String? labelText,
  String? hintText,
}) {
  final theme = ShadTheme.of(context);

  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    isDense: true,
    filled: true,
    fillColor: theme.colorScheme.secondary.withValues(alpha: 0.12),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: theme.colorScheme.primary.withValues(alpha: 0.45),
        width: 1,
      ),
    ),
  );
}
