import 'package:flutter/services.dart';

class AndroidOverlayDefaults {
  AndroidOverlayDefaults._();

  static const clicksPerSecond = 8.0;
  static const jitterRadius = 6.0;
  static const targetSize = 32.0;
  static const targetX = 180.0;
  static const targetY = 300.0;

  static const configuration = {
    'clicksPerSecond': clicksPerSecond,
    'jitterRadius': jitterRadius,
    'targetSize': targetSize,
    'targetX': targetX,
    'targetY': targetY,
  };
}

class AndroidAutoClickerChannel {
  AndroidAutoClickerChannel._();

  static const _channel = MethodChannel('autoclicker/android');

  static void setConfigurationListChangedHandler(VoidCallback? handler) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'configurationListChanged') {
        handler?.call();
      }
    });
  }

  static Future<bool> isOverlayPermissionGranted() {
    return _invokeBool('isOverlayPermissionGranted');
  }

  static Future<bool> isAccessibilityPermissionGranted() {
    return _invokeBool('isAccessibilityPermissionGranted');
  }

  static Future<void> openOverlaySettings() {
    return _invokeVoid('openOverlaySettings');
  }

  static Future<void> openAccessibilitySettings() {
    return _invokeVoid('openAccessibilitySettings');
  }

  static Future<bool> startOverlayService({
    required double clicksPerSecond,
    required double jitterRadius,
    required double targetSize,
    required double targetX,
    required double targetY,
    bool targetOnly = false,
  }) {
    return _invokeBool('startOverlayService', {
      'clicksPerSecond': clicksPerSecond,
      'jitterRadius': jitterRadius,
      'targetSize': targetSize,
      'targetX': targetX,
      'targetY': targetY,
      'targetOnly': targetOnly,
    });
  }

  static Future<Map<String, double>> loadOverlayConfiguration() async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'loadOverlayConfiguration',
      );
      return {
        'clicksPerSecond':
            (result?['clicksPerSecond'] as num?)?.toDouble() ??
            AndroidOverlayDefaults.configuration['clicksPerSecond']!,
        'jitterRadius':
            (result?['jitterRadius'] as num?)?.toDouble() ??
            AndroidOverlayDefaults.configuration['jitterRadius']!,
        'targetSize':
            (result?['targetSize'] as num?)?.toDouble() ??
            AndroidOverlayDefaults.configuration['targetSize']!,
        'targetX':
            (result?['targetX'] as num?)?.toDouble() ??
            AndroidOverlayDefaults.configuration['targetX']!,
        'targetY':
            (result?['targetY'] as num?)?.toDouble() ??
            AndroidOverlayDefaults.configuration['targetY']!,
      };
    } on MissingPluginException {
      return AndroidOverlayDefaults.configuration;
    }
  }

  static Future<List<Map<String, Object?>>> loadConfigurationList() async {
    try {
      final result = await _channel.invokeListMethod<Map<Object?, Object?>>(
        'loadConfigurationList',
      );
      return result
              ?.map(
                (item) =>
                    item.map((key, value) => MapEntry(key.toString(), value)),
              )
              .toList() ??
          const [];
    } on MissingPluginException {
      return const [];
    }
  }

  static Future<void> saveConfigurationList(
    List<Map<String, Object?>> configurations,
  ) {
    return _invokeVoid('saveConfigurationList', {
      'configurations': configurations,
    });
  }

  static Future<void> saveOverlayConfiguration({
    required double clicksPerSecond,
    required double jitterRadius,
    required double targetSize,
    required double targetX,
    required double targetY,
  }) {
    return _invokeVoid('saveOverlayConfiguration', {
      'clicksPerSecond': clicksPerSecond,
      'jitterRadius': jitterRadius,
      'targetSize': targetSize,
      'targetX': targetX,
      'targetY': targetY,
    });
  }

  static Future<void> stopOverlayService() {
    return _invokeVoid('stopOverlayService');
  }

  static Future<String> getAppVersionName() async {
    try {
      return await _channel.invokeMethod<String>('getAppVersionName') ?? '';
    } on MissingPluginException {
      return '';
    }
  }

  static Future<bool> _invokeBool(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      return await _channel.invokeMethod<bool>(method, arguments) ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> _invokeVoid(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      return;
    }
  }
}
