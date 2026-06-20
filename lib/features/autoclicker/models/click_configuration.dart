import '../services/android_autoclicker_channel.dart';

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
    // 统一复用平台默认值合并逻辑，避免模型层重复兜底分支。
    final configuration = AndroidOverlayDefaults.merge(map);
    return ClickConfiguration(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      clicksPerSecond: configuration['clicksPerSecond']!,
      jitterRadius: configuration['jitterRadius']!,
      targetSize: configuration['targetSize']!,
      targetX: configuration['targetX']!,
      targetY: configuration['targetY']!,
    );
  }

  /// 标识配置的唯一主键。
  final String id;

  /// 标识配置的展示名称。
  final String name;

  /// 标识配置使用的点击频率。
  final double clicksPerSecond;

  /// 标识配置使用的点击偏移。
  final double jitterRadius;

  /// 标识配置使用的准星尺寸。
  final double targetSize;

  /// 标识配置使用的准星横向坐标。
  final double targetX;

  /// 标识配置使用的准星纵向坐标。
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
