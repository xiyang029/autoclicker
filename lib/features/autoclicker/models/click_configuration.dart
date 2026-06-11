import '../../../platform/android_autoclicker_channel.dart';

class ClickConfiguration {
  const ClickConfiguration({
    required this.id,
    required this.name,
    required this.clicksPerSecond,
    required this.jitterRadius,
    required this.targetSize,
    required this.targetX,
    required this.targetY,
  });

  factory ClickConfiguration.fromChannelMap(Map<String, Object?> map) {
    return ClickConfiguration(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      clicksPerSecond:
          (map['clicksPerSecond'] as num?)?.toDouble() ??
          AndroidOverlayDefaults.clicksPerSecond,
      jitterRadius:
          (map['jitterRadius'] as num?)?.toDouble() ??
          AndroidOverlayDefaults.jitterRadius,
      targetSize:
          (map['targetSize'] as num?)?.toDouble() ??
          AndroidOverlayDefaults.targetSize,
      targetX:
          (map['targetX'] as num?)?.toDouble() ??
          AndroidOverlayDefaults.targetX,
      targetY:
          (map['targetY'] as num?)?.toDouble() ??
          AndroidOverlayDefaults.targetY,
    );
  }

  final String id;
  final String name;
  final double clicksPerSecond;
  final double jitterRadius;
  final double targetSize;
  final double targetX;
  final double targetY;

  Map<String, Object?> toChannelMap() {
    return {
      'id': id,
      'name': name,
      'clicksPerSecond': clicksPerSecond,
      'jitterRadius': jitterRadius,
      'targetSize': targetSize,
      'targetX': targetX,
      'targetY': targetY,
    };
  }

  ClickConfiguration copyWith({
    String? name,
    double? clicksPerSecond,
    double? jitterRadius,
    double? targetSize,
    double? targetX,
    double? targetY,
  }) {
    return ClickConfiguration(
      id: id,
      name: name ?? this.name,
      clicksPerSecond: clicksPerSecond ?? this.clicksPerSecond,
      jitterRadius: jitterRadius ?? this.jitterRadius,
      targetSize: targetSize ?? this.targetSize,
      targetX: targetX ?? this.targetX,
      targetY: targetY ?? this.targetY,
    );
  }

  bool matches({
    required double clicksPerSecond,
    required double jitterRadius,
    required double targetSize,
    required double targetX,
    required double targetY,
  }) {
    return this.clicksPerSecond.round() == clicksPerSecond.round() &&
        this.jitterRadius.round() == jitterRadius.round() &&
        this.targetSize.round() == targetSize.round() &&
        this.targetX.round() == targetX.round() &&
        this.targetY.round() == targetY.round();
  }
}
