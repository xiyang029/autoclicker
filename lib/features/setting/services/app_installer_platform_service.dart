import 'package:flutter/services.dart';

class AppInstallerPlatformService {
  static const MethodChannel _channel = MethodChannel('autoclicker/installer');

  /// 检查通知权限是否已授权，用于后台下载通知展示。
  static Future<bool> hasNotificationPermission() async {
    return await _channel.invokeMethod<bool>('hasNotificationPermission') ??
        false;
  }

  /// 检查当前系统是否允许安装未知来源应用。
  static Future<bool> canRequestPackageInstalls() async {
    return await _channel.invokeMethod<bool>('canRequestPackageInstalls') ??
        false;
  }

  /// 打开系统安装未知来源权限设置页。
  static Future<void> openInstallPermissionSettings() {
    return _channel.invokeMethod<void>('openInstallPermissionSettings');
  }

  /// 主动请求通知权限，保障下载过程可见。
  static Future<bool> ensureNotificationPermission() async {
    return await _channel.invokeMethod<bool>('ensureNotificationPermission') ??
        false;
  }

  /// 展示原生提示消息，不阻断主流程。
  static Future<void> showToast(String message) {
    return _channel.invokeMethod<void>('showToast', {'message': message});
  }
}
