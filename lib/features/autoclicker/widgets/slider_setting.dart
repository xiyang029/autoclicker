import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SliderSetting extends StatefulWidget {
  const SliderSetting({
    super.key,
    required this.title,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.onChangeEnd,
    this.showDivisions = false,
  });

  final String title;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final bool showDivisions;

  @override
  State<SliderSetting> createState() => _SliderSettingState();
}

class _SliderSettingState extends State<SliderSetting> {
  late final ShadSliderController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ShadSliderController(initialValue: widget.value);
  }

  @override
  void didUpdateWidget(covariant SliderSetting oldWidget) {
    super.didUpdateWidget(oldWidget);
    final snappedValue = _snapValue(widget.value);
    if (_controller.value != snappedValue) {
      _controller.value = snappedValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _stepSize() {
    if (widget.divisions <= 0) return 0;
    return (widget.max - widget.min) / widget.divisions;
  }

  double _snapValue(double value) {
    if (widget.divisions <= 0) return value.clamp(widget.min, widget.max);

    final step = _stepSize();
    if (step == 0) return widget.min;

    final clampedValue = value.clamp(widget.min, widget.max);
    final snapped =
        ((clampedValue - widget.min) / step).round() * step + widget.min;

    return snapped.clamp(widget.min, widget.max);
  }

  void _handleChanged(double value) {
    final snappedValue = _snapValue(value);
    if (_controller.value != snappedValue) {
      _controller.value = snappedValue;
    }
    widget.onChanged(snappedValue);
  }

  void _handleChangeEnd(double value) {
    final snappedValue = _snapValue(value);
    if (_controller.value != snappedValue) {
      _controller.value = snappedValue;
    }
    widget.onChangeEnd?.call(snappedValue);
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
            Text(widget.valueText, style: theme.textTheme.muted),
          ],
        ),
        const SizedBox(height: 12),
        ShadSlider(
          controller: _controller,
          min: widget.min,
          max: widget.max,
          divisions: widget.showDivisions ? widget.divisions : null,
          onChanged: _handleChanged,
          onChangeEnd: _handleChangeEnd,
        ),
      ],
    );
  }
}
