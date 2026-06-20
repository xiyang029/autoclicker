import 'dart:async';
import 'package:flutter/services.dart';

class AndroidOverlayDefaults {
  AndroidOverlayDefaults._();

  /// 标识悬浮点击服务使用的默认点击频率。
  static const clicksPerSecond = 8.0;

  /// 标识悬浮点击服务使用的固定点击偏移。
  static const jitterRadius = 4.0;

  /// 标识悬浮准星的默认尺寸。
  static const targetSize = 64.0;

  /// 标识悬浮准星的默认横向坐标。
  static const targetX = 180.0;

  /// 标识悬浮准星的默认纵向坐标。
  static const targetY = 300.0;

  /// 将平台侧配置补齐为可直接消费的默认配置。
  static Map<String, double> merge(Map<String, Object?>? configuration) {
    return {
      'clicksPerSecond':
          (configuration?['clicksPerSecond'] as num?)?.toDouble() ??
          clicksPerSecond,
      'jitterRadius':
          (configuration?['jitterRadius'] as num?)?.toDouble() ?? jitterRadius,
      'targetSize':
          (configuration?['targetSize'] as num?)?.toDouble() ?? targetSize,
      'targetX': (configuration?['targetX'] as num?)?.toDouble() ?? targetX,
      'targetY': (configuration?['targetY'] as num?)?.toDouble() ?? targetY,
    };
  }

  /// 生成一份完整配置映射，作为 Flutter 与原生通道共享结构。
  static Map<String, Object?> toChannelMap({
    required double clicksPerSecond,
    required double jitterRadius,
    required double targetSize,
    required double targetX,
    required double targetY,
  }) {
    return {
      'clicksPerSecond': clicksPerSecond,
      'jitterRadius': jitterRadius,
      'targetSize': targetSize,
      'targetX': targetX,
      'targetY': targetY,
    };
  }
}

class AndroidAutoClickerChannel {
  AndroidAutoClickerChannel._();

  static const MethodChannel _channel = MethodChannel('autoclicker/android');
  static FutureOr<void> Function()? _onConfigurationListChanged;
  static VoidCallback? _onOverlayServiceStopped;

  /// 注册平台事件回调，用于同步配置变化与悬浮窗关闭状态。
  static void setEventHandlers({
    FutureOr<void> Function()? onConfigurationListChanged,
    VoidCallback? onOverlayServiceStopped,
  }) {
    _onConfigurationListChanged = onConfigurationListChanged;
    _onOverlayServiceStopped = onOverlayServiceStopped;
    if (_onConfigurationListChanged == null &&
        _onOverlayServiceStopped == null) {
      _channel.setMethodCallHandler(null);
      return;
    }
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'configurationListChanged':
          await _onConfigurationListChanged?.call();
          break;
        case 'overlayServiceStopped':
          _onOverlayServiceStopped?.call();
          break;
      }
    });
  }

  /// 查询悬浮窗权限状态。
  static Future<bool> isOverlayPermissionGranted() {
    return _invokeBool('isOverlayPermissionGranted');
  }

  /// 查询无障碍权限状态。
  static Future<bool> isAccessibilityPermissionGranted() {
    return _invokeBool('isAccessibilityPermissionGranted');
  }

  /// 打开系统悬浮窗设置页。
  static Future<void> openOverlaySettings() {
    return _invokeVoid('openOverlaySettings');
  }

  /// 打开系统无障碍设置页。
  static Future<void> openAccessibilitySettings() {
    return _invokeVoid('openAccessibilitySettings');
  }

  /// 启动自动点击悬浮服务，并下发当前参数。
  static Future<bool> startOverlayService({
    required double clicksPerSecond,
    required double jitterRadius,
    required double targetSize,
    required double targetX,
    required double targetY,
    bool targetOnly = false,
  }) {
    return _invokeBool('startOverlayService', {
      ...AndroidOverlayDefaults.toChannelMap(
        clicksPerSecond: clicksPerSecond,
        jitterRadius: jitterRadius,
        targetSize: targetSize,
        targetX: targetX,
        targetY: targetY,
      ),
      'targetOnly': targetOnly,
    });
  }

  /// 读取平台持久化的悬浮配置。
  static Future<Map<String, double>> loadOverlayConfiguration() async {
    return AndroidOverlayDefaults.merge(
      await _channel.invokeMapMethod<String, Object?>(
        'loadOverlayConfiguration',
      ),
    );
  }

  /// 读取平台持久化的原始配置列表。
  static Future<String> loadConfigurationListPayload() async {
    return await _channel.invokeMethod<String>(
          'loadConfigurationListPayload',
        ) ??
        '';
  }

  /// 保存原始配置列表 JSON。
  static Future<void> saveConfigurationListPayload(String payload) {
    return _invokeVoid('saveConfigurationListPayload', {'payload': payload});
  }

  /// 保存当前悬浮配置。
  static Future<void> saveOverlayConfiguration({
    required double clicksPerSecond,
    required double jitterRadius,
    required double targetSize,
    required double targetX,
    required double targetY,
  }) {
    return _invokeVoid(
      'saveOverlayConfiguration',
      AndroidOverlayDefaults.toChannelMap(
        clicksPerSecond: clicksPerSecond,
        jitterRadius: jitterRadius,
        targetSize: targetSize,
        targetX: targetX,
        targetY: targetY,
      ),
    );
  }

  /// 停止悬浮服务。
  static Future<void> stopOverlayService() {
    return _invokeVoid('stopOverlayService');
  }

  /// 查询悬浮服务当前运行状态。
  static Future<bool> isOverlayServiceRunning() {
    return _invokeBool('isOverlayServiceRunning');
  }

  /// 获取应用当前版本号。
  static Future<String> getAppVersionName() async {
    return await _channel.invokeMethod<String>('getAppVersionName') ?? '';
  }

  /// 调用平台布尔方法并返回方法结果。
  static Future<bool> _invokeBool(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    return await _channel.invokeMethod<bool>(method, arguments) ?? false;
  }

  /// 调用平台无返回值方法。
  static Future<void> _invokeVoid(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    await _channel.invokeMethod<void>(method, arguments);
  }
}
