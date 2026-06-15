import 'dart:async';

import 'package:flutter/material.dart';

import '../models/click_configuration.dart';
import '../../../platform/android_autoclicker_channel.dart';

class AutoClickerController extends ChangeNotifier with WidgetsBindingObserver {
  AutoClickerController();

  bool _disposed = false;

  bool overlayServiceRunning = false;
  bool overlayPermissionGranted = false;
  bool accessibilityPermissionGranted = false;

  // 只保留一个核心数据：供 UI 渲染展示的当前版本号
  String currentVersion = '';

  double clicksPerSecond = AndroidOverlayDefaults.clicksPerSecond;
  double jitterRadius = AndroidOverlayDefaults.jitterRadius;
  double targetSize = AndroidOverlayDefaults.targetSize;
  double targetX = AndroidOverlayDefaults.targetX;
  double targetY = AndroidOverlayDefaults.targetY;
  List<ClickConfiguration> configurations = const [];

  bool get canStartOverlay =>
      overlayPermissionGranted && accessibilityPermissionGranted;

  bool isActiveConfiguration(ClickConfiguration configuration) {
    return configuration.matches(
      clicksPerSecond: clicksPerSecond,
      jitterRadius: jitterRadius,
      targetSize: targetSize,
      targetX: targetX,
      targetY: targetY,
    );
  }

  void init() {
    WidgetsBinding.instance.addObserver(this);
    AndroidAutoClickerChannel.setEventHandlers(
      onConfigurationListChanged: loadConfigurationList,
      onOverlayServiceStopped: _handleOverlayServiceStopped,
    );
    loadAppVersionName();
    loadSavedConfiguration();
    loadConfigurationList();
    refreshPermissions();
  }

  @override
  void dispose() {
    _disposed = true;
    AndroidAutoClickerChannel.setEventHandlers();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refreshOverlayRunningState();
      refreshPermissions();
      loadSavedConfiguration();
      loadConfigurationList();
    }
  }

  Future<void> refreshPermissions() async {
    final permissions = await Future.wait<bool>([
      AndroidAutoClickerChannel.isOverlayPermissionGranted(),
      AndroidAutoClickerChannel.isAccessibilityPermissionGranted(),
    ]);

    if (_disposed) return;
    overlayPermissionGranted = permissions[0];
    accessibilityPermissionGranted = permissions[1];
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
    _updateFromConfiguration(ClickConfiguration.fromChannelMap(configuration));
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
    _updateOverlayValues(clicksPerSecond: value);
  }

  void setJitterRadius(double value) {
    _updateOverlayValues(jitterRadius: value);
  }

  void setTargetSize(double value) {
    _updateOverlayValues(targetSize: value);
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

    await _replaceConfiguration(
      configuration.id,
      (item) => item.copyWith(name: trimmedName),
    );
  }

  Future<void> applyConfiguration(ClickConfiguration configuration) async {
    _updateFromConfiguration(configuration);
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

    final shouldSyncCurrentValues = configuration.matches(
      clicksPerSecond: clicksPerSecond,
      jitterRadius: jitterRadius,
      targetSize: targetSize,
      targetX: targetX,
      targetY: targetY,
    );
    await _replaceConfiguration(
      configuration.id,
      (_) => normalizedConfiguration,
      syncCurrentValues: shouldSyncCurrentValues
          ? normalizedConfiguration
          : null,
    );
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

  Future<void> refreshOverlayRunningState() async {
    final running = await AndroidAutoClickerChannel.isOverlayServiceRunning();
    if (_disposed) return;
    if (overlayServiceRunning == running) return;

    overlayServiceRunning = running;
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

  Future<void> _saveConfigurationList() {
    return AndroidAutoClickerChannel.saveConfigurationList(
      configurations
          .map((configuration) => configuration.toChannelMap())
          .toList(),
    );
  }

  void _updateFromConfiguration(ClickConfiguration configuration) {
    _updateOverlayValues(
      clicksPerSecond: configuration.clicksPerSecond,
      jitterRadius: configuration.jitterRadius,
      targetSize: configuration.targetSize,
      targetX: configuration.targetX,
      targetY: configuration.targetY,
    );
  }

  void _updateOverlayValues({
    double? clicksPerSecond,
    double? jitterRadius,
    double? targetSize,
    double? targetX,
    double? targetY,
    bool notify = true,
  }) {
    this.clicksPerSecond = clicksPerSecond ?? this.clicksPerSecond;
    this.jitterRadius = jitterRadius ?? this.jitterRadius;
    this.targetSize = targetSize ?? this.targetSize;
    this.targetX = targetX ?? this.targetX;
    this.targetY = targetY ?? this.targetY;
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> _replaceConfiguration(
    String configurationId,
    ClickConfiguration Function(ClickConfiguration current) transform, {
    ClickConfiguration? syncCurrentValues,
  }) async {
    configurations = [
      for (final item in configurations)
        if (item.id == configurationId) transform(item) else item,
    ];
    if (syncCurrentValues != null) {
      _updateFromConfiguration(syncCurrentValues);
      return _saveConfigurationList();
    }
    notifyListeners();
    await _saveConfigurationList();
  }

  void _handleOverlayServiceStopped() {
    if (_disposed || !overlayServiceRunning) return;

    overlayServiceRunning = false;
    notifyListeners();
  }
}
