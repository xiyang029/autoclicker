import 'package:flutter/services.dart';

class AppInstallerPlatformService {
  static const MethodChannel _channel = MethodChannel('autoclicker/installer');

  static Future<bool> hasNotificationPermission() async {
    try {
      final allowed = await _channel.invokeMethod<bool>(
        'hasNotificationPermission',
      );
      return allowed ?? true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> canRequestPackageInstalls() async {
    try {
      final allowed = await _channel.invokeMethod<bool>(
        'canRequestPackageInstalls',
      );
      return allowed ?? false;
    } catch (_) {
      return true;
    }
  }

  static Future<void> openInstallPermissionSettings() {
    return _channel.invokeMethod<void>('openInstallPermissionSettings');
  }

  static Future<bool> ensureNotificationPermission() async {
    try {
      final allowed = await _channel.invokeMethod<bool>(
        'ensureNotificationPermission',
      );
      return allowed ?? true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> showToast(String message) async {
    try {
      await _channel.invokeMethod<void>('showToast', {'message': message});
    } catch (_) {
      // Toast 不可用时不影响下载与安装流程。
    }
  }
}
