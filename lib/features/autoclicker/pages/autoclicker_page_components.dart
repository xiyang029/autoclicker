import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const autoclickerPagePadding = EdgeInsets.fromLTRB(16, 16, 16, 24);

class AutoclickerSliderSetting extends StatefulWidget {
  const AutoclickerSliderSetting({
    super.key,
    required this.title,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.onChangeEnd,
  });

  final String title;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  State<AutoclickerSliderSetting> createState() =>
      _AutoclickerSliderSettingState();
}

class _AutoclickerSliderSettingState extends State<AutoclickerSliderSetting> {
  late final ShadSliderController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ShadSliderController(initialValue: widget.value);
  }

  @override
  void didUpdateWidget(covariant AutoclickerSliderSetting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.value != widget.value) {
      _controller.value = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged(double value) {
    final clampedValue = value.clamp(widget.min, widget.max);
    if (_controller.value != clampedValue) {
      _controller.value = clampedValue;
    }
    widget.onChanged(clampedValue);
  }

  void _handleChangeEnd(double value) {
    final clampedValue = value.clamp(widget.min, widget.max);
    if (_controller.value != clampedValue) {
      _controller.value = clampedValue;
    }
    widget.onChangeEnd?.call(clampedValue);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(widget.title, style: theme.textTheme.small)),
            const SizedBox(width: 12),
            Text(widget.valueText, style: theme.textTheme.muted),
          ],
        ),
        const SizedBox(height: 10),
        ShadSlider(
          controller: _controller,
          min: widget.min,
          max: widget.max,
          onChanged: _handleChanged,
          onChangeEnd: _handleChangeEnd,
        ),
      ],
    );
  }
}

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
    fillColor: theme.colorScheme.secondary.withValues(alpha: 0.16),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: theme.colorScheme.primary.withValues(alpha: 0.4),
        width: 1,
      ),
    ),
  );
}
