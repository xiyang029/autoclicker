import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';

import '../../../core/services/app_update_service.dart';
import '../../../platform/android_autoclicker_channel.dart';
import '../models/click_configuration.dart';

class UpdatePrompt {
  const UpdatePrompt({required this.currentVersion, required this.release});

  final String currentVersion;
  final AppReleaseInfo release;
}

class AutoClickerController extends ChangeNotifier with WidgetsBindingObserver {
  AutoClickerController({AppUpdateService? updateService})
    : _updateService = updateService ?? AppUpdateService();

  final AppUpdateService _updateService;
  bool _disposed = false;

  bool overlayServiceRunning = false;
  bool overlayPermissionGranted = false;
  bool accessibilityPermissionGranted = false;
  bool checkingForUpdate = false;
  bool downloadingUpdate = false;
  int? downloadProgress;
  String currentVersion = '';
  String? updateStatusText;
  double clicksPerSecond = AndroidOverlayDefaults.clicksPerSecond;
  double jitterRadius = AndroidOverlayDefaults.jitterRadius;
  double targetSize = AndroidOverlayDefaults.targetSize;
  double targetX = AndroidOverlayDefaults.targetX;
  double targetY = AndroidOverlayDefaults.targetY;
  List<ClickConfiguration> configurations = const [];

  bool get canStartOverlay =>
      overlayPermissionGranted && accessibilityPermissionGranted;

  void init() {
    WidgetsBinding.instance.addObserver(this);
    AndroidAutoClickerChannel.setConfigurationListChangedHandler(
      loadConfigurationList,
    );
    loadAppVersionName();
    loadSavedConfiguration();
    loadConfigurationList();
    refreshPermissions();
  }

  @override
  void dispose() {
    _disposed = true;
    AndroidAutoClickerChannel.setConfigurationListChangedHandler(null);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refreshPermissions();
      loadSavedConfiguration();
      loadConfigurationList();
    }
  }

  Future<void> refreshPermissions() async {
    final overlayGranted =
        await AndroidAutoClickerChannel.isOverlayPermissionGranted();
    final accessibilityGranted =
        await AndroidAutoClickerChannel.isAccessibilityPermissionGranted();

    if (_disposed) return;
    overlayPermissionGranted = overlayGranted;
    accessibilityPermissionGranted = accessibilityGranted;
    notifyListeners();
  }

  Future<void> loadAppVersionName() async {
    final version = await AndroidAutoClickerChannel.getAppVersionName();
    if (_disposed) return;
    currentVersion = version;
    notifyListeners();
  }

  Future<void> openOverlaySettings() {
    return AndroidAutoClickerChannel.openOverlaySettings();
  }

  Future<void> openAccessibilitySettings() {
    return AndroidAutoClickerChannel.openAccessibilitySettings();
  }

  Future<void> loadSavedConfiguration() async {
    final configuration =
        await AndroidAutoClickerChannel.loadOverlayConfiguration();

    if (_disposed) return;
    clicksPerSecond = configuration['clicksPerSecond']!;
    jitterRadius = configuration['jitterRadius']!;
    targetSize = configuration['targetSize']!;
    targetX = configuration['targetX']!;
    targetY = configuration['targetY']!;
    notifyListeners();
  }

  Future<void> loadConfigurationList() async {
    final loadedConfigurations =
        await AndroidAutoClickerChannel.loadConfigurationList();

    if (_disposed) return;
    configurations = loadedConfigurations
        .map(ClickConfiguration.fromChannelMap)
        .where((configuration) => configuration.id.isNotEmpty)
        .toList();
    notifyListeners();
  }

  void setClicksPerSecond(double value) {
    clicksPerSecond = value;
    notifyListeners();
  }

  void setJitterRadius(double value) {
    jitterRadius = value;
    notifyListeners();
  }

  void setTargetSize(double value) {
    targetSize = value;
    notifyListeners();
  }

  Future<void> saveOverlayConfiguration() async {
    await AndroidAutoClickerChannel.saveOverlayConfiguration(
      clicksPerSecond: clicksPerSecond,
      jitterRadius: jitterRadius,
      targetSize: targetSize,
      targetX: targetX,
      targetY: targetY,
    );
    await syncOverlayConfiguration();
  }

  Future<void> renameConfiguration(
    ClickConfiguration configuration,
    String name,
  ) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty || trimmedName == configuration.name) return;

    configurations = [
      for (final item in configurations)
        if (item.id == configuration.id)
          item.copyWith(name: trimmedName)
        else
          item,
    ];
    notifyListeners();
    await _saveConfigurationList();
  }

  Future<void> applyConfiguration(ClickConfiguration configuration) async {
    clicksPerSecond = configuration.clicksPerSecond;
    jitterRadius = configuration.jitterRadius;
    targetSize = configuration.targetSize;
    targetX = configuration.targetX;
    targetY = configuration.targetY;
    notifyListeners();
    await saveOverlayConfiguration();
  }

  Future<void> editConfiguration(
    ClickConfiguration configuration,
    ClickConfiguration updatedConfiguration,
  ) async {
    final trimmedName = updatedConfiguration.name.trim();
    if (trimmedName.isEmpty) return;

    final normalizedConfiguration = updatedConfiguration.copyWith(
      name: trimmedName,
    );

    configurations = [
      for (final item in configurations)
        if (item.id == configuration.id) normalizedConfiguration else item,
    ];
    if (configuration.matches(
      clicksPerSecond: clicksPerSecond,
      jitterRadius: jitterRadius,
      targetSize: targetSize,
      targetX: targetX,
      targetY: targetY,
    )) {
      clicksPerSecond = normalizedConfiguration.clicksPerSecond;
      jitterRadius = normalizedConfiguration.jitterRadius;
      targetSize = normalizedConfiguration.targetSize;
      targetX = normalizedConfiguration.targetX;
      targetY = normalizedConfiguration.targetY;
    }
    notifyListeners();
    await _saveConfigurationList();
  }

  Future<void> deleteConfiguration(ClickConfiguration configuration) async {
    configurations = [
      for (final item in configurations)
        if (item.id != configuration.id) item,
    ];
    notifyListeners();
    await _saveConfigurationList();
  }

  Future<void> startOverlayService() async {
    await refreshPermissions();

    if (!canStartOverlay) return;

    final started = await AndroidAutoClickerChannel.startOverlayService(
      clicksPerSecond: clicksPerSecond,
      jitterRadius: jitterRadius,
      targetSize: targetSize,
      targetX: targetX,
      targetY: targetY,
    );

    if (_disposed) return;
    overlayServiceRunning = started;
    notifyListeners();
  }

  Future<void> stopOverlayService() async {
    await AndroidAutoClickerChannel.stopOverlayService();
    if (_disposed) return;
    overlayServiceRunning = false;
    notifyListeners();
  }

  Future<void> syncOverlayConfiguration() async {
    if (!overlayServiceRunning || !canStartOverlay) return;

    await AndroidAutoClickerChannel.startOverlayService(
      clicksPerSecond: clicksPerSecond,
      jitterRadius: jitterRadius,
      targetSize: targetSize,
      targetX: targetX,
      targetY: targetY,
    );
  }

  Future<void> checkForUpdates({
    required Future<bool> Function(UpdatePrompt prompt) confirmDownload,
    required void Function(String message) showMessage,
  }) async {
    if (checkingForUpdate || downloadingUpdate) return;

    checkingForUpdate = true;
    updateStatusText = '正在检查更新...';
    notifyListeners();

    try {
      final release = await _updateService.fetchLatestRelease();
      final resolvedCurrentVersion = currentVersion.isEmpty
          ? await AndroidAutoClickerChannel.getAppVersionName()
          : currentVersion;
      final hasUpdate =
          resolvedCurrentVersion.isEmpty ||
          _updateService.isNewerVersion(
            release.version,
            resolvedCurrentVersion,
          );

      if (_disposed) return;
      if (!hasUpdate) {
        updateStatusText = '当前已是最新版本';
        notifyListeners();
        showMessage('当前已是最新版本');
        return;
      }

      final shouldDownload = await confirmDownload(
        UpdatePrompt(currentVersion: resolvedCurrentVersion, release: release),
      );

      if (shouldDownload) {
        await downloadAndInstallRelease(release, showMessage: showMessage);
      } else if (!_disposed) {
        updateStatusText = '发现新版本 ${release.version}';
        notifyListeners();
      }
    } catch (error) {
      if (!_disposed) {
        updateStatusText = '检查更新失败';
        notifyListeners();
        showMessage('检查更新失败：$error');
      }
    } finally {
      if (!_disposed) {
        checkingForUpdate = false;
        notifyListeners();
      }
    }
  }

  Future<void> downloadAndInstallRelease(
    AppReleaseInfo release, {
    required void Function(String message) showMessage,
  }) async {
    downloadingUpdate = true;
    downloadProgress = null;
    updateStatusText = '准备下载 ${release.version}';
    notifyListeners();

    try {
      await for (final event in OtaUpdate().execute(
        release.apkUrl,
        destinationFilename: release.fileName,
      )) {
        if (_disposed) return;
        _handleOtaEvent(event, release, showMessage);
        if (event.status == OtaStatus.INSTALLING) {
          break;
        }
      }
    } catch (error) {
      if (!_disposed) {
        updateStatusText = '下载更新失败';
        notifyListeners();
        showMessage('下载更新失败：$error');
      }
    } finally {
      if (!_disposed) {
        downloadingUpdate = false;
        downloadProgress = null;
        notifyListeners();
      }
    }
  }

  void _handleOtaEvent(
    OtaEvent event,
    AppReleaseInfo release,
    void Function(String message) showMessage,
  ) {
    switch (event.status) {
      case OtaStatus.DOWNLOADING:
        final progress = int.tryParse(event.value ?? '');
        downloadProgress = progress?.clamp(0, 100);
        updateStatusText = downloadProgress == null
            ? '正在下载 ${release.version}'
            : '正在下载 ${release.version}，$downloadProgress%';
        notifyListeners();
      case OtaStatus.INSTALLING:
        downloadProgress = 100;
        updateStatusText = '下载完成，正在打开系统安装器';
        notifyListeners();
      case OtaStatus.INSTALLATION_DONE:
        downloadProgress = 100;
        updateStatusText = '安装已完成';
        notifyListeners();
      case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
        updateStatusText = '请允许安装未知来源应用后重新更新';
        downloadingUpdate = false;
        notifyListeners();
        showMessage('请在系统设置中允许安装未知来源应用');
      case OtaStatus.DOWNLOAD_ERROR:
      case OtaStatus.INTERNAL_ERROR:
      case OtaStatus.ALREADY_RUNNING_ERROR:
      case OtaStatus.CHECKSUM_ERROR:
      case OtaStatus.INSTALLATION_ERROR:
        updateStatusText = '下载更新失败';
        downloadingUpdate = false;
        notifyListeners();
        showMessage(event.value?.isNotEmpty == true ? event.value! : '下载更新失败');
      case OtaStatus.CANCELED:
        updateStatusText = '更新已取消';
        downloadingUpdate = false;
        notifyListeners();
    }
  }

  Future<void> _saveConfigurationList() {
    return AndroidAutoClickerChannel.saveConfigurationList(
      configurations
          .map((configuration) => configuration.toChannelMap())
          .toList(),
    );
  }
}
