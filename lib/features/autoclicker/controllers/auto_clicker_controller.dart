import 'dart:async';

import 'package:flutter/material.dart';

import '../models/click_configuration.dart';
import '../services/android_autoclicker_channel.dart';
import '../services/click_configuration_storage.dart';

class AutoClickerController extends ChangeNotifier with WidgetsBindingObserver {
  AutoClickerController();

  /// 标识控制器是否已经释放，避免异步回调继续写状态。
  bool _disposed = false;

  /// 标识悬浮点击服务当前是否运行。
  bool overlayServiceRunning = false;

  /// 标识系统悬浮窗权限是否已授权。
  bool overlayPermissionGranted = false;

  /// 标识无障碍权限是否已授权。
  bool accessibilityPermissionGranted = false;

  /// 标识当前手动选中的配置 ID。
  String? selectedConfigurationId;

  // 只保留一个核心数据：供 UI 渲染展示的当前版本号
  String currentVersion = '';

  /// 标识当前点击频率参数。
  double clicksPerSecond = AndroidOverlayDefaults.clicksPerSecond;

  /// 标识当前固定点击偏移参数。
  double jitterRadius = AndroidOverlayDefaults.jitterRadius;

  /// 标识当前准星尺寸参数。
  double targetSize = AndroidOverlayDefaults.targetSize;

  /// 标识当前准星横向坐标。
  double targetX = AndroidOverlayDefaults.targetX;

  /// 标识当前准星纵向坐标。
  double targetY = AndroidOverlayDefaults.targetY;

  /// 标识当前已保存的配置列表。
  List<ClickConfiguration> configurations = const [];

  bool get canStartOverlay =>
      overlayPermissionGranted && accessibilityPermissionGranted;

  String? get activeConfigurationId {
    final selectedConfigurationId = this.selectedConfigurationId;
    if (selectedConfigurationId != null &&
        configurations.any((configuration) {
          return configuration.id == selectedConfigurationId;
        })) {
      return selectedConfigurationId;
    }

    for (final configuration in configurations) {
      if (configuration.matches(
        clicksPerSecond: clicksPerSecond,
        jitterRadius: jitterRadius,
        targetSize: targetSize,
        targetX: targetX,
        targetY: targetY,
      )) {
        return configuration.id;
      }
    }
    return null;
  }

  bool isActiveConfiguration(ClickConfiguration configuration) {
    return configuration.id == activeConfigurationId;
  }

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    AndroidAutoClickerChannel.setEventHandlers(
      onConfigurationListChanged: loadConfigurationList,
      onOverlayServiceStopped: _handleOverlayServiceStopped,
    );
    await Future.wait([
      loadAppVersionName(),
      loadSavedConfiguration(),
      loadConfigurationList(),
      refreshPermissions(),
    ]);
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
        await ClickConfigurationStorage.loadConfigurations();

    if (_disposed) return;
    configurations = loadedConfigurations;
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
    /// 标识平台侧最近一次拖动后的准星坐标快照。
    final latestConfiguration =
        await AndroidAutoClickerChannel.loadOverlayConfiguration();
    if (_disposed) return;

    _updateOverlayValues(
      targetX: latestConfiguration['targetX'],
      targetY: latestConfiguration['targetY'],
      notify: false,
    );
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
    selectedConfigurationId = configuration.id;
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
    if (selectedConfigurationId == configuration.id) {
      selectedConfigurationId = null;
    }
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
    return ClickConfigurationStorage.saveConfigurations(configurations);
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

    if (selectedConfigurationId != null) {
      ClickConfiguration? selectedConfiguration;
      for (final configuration in configurations) {
        if (configuration.id == selectedConfigurationId) {
          selectedConfiguration = configuration;
          break;
        }
      }
      if (selectedConfiguration == null ||
          !selectedConfiguration.matches(
            clicksPerSecond: this.clicksPerSecond,
            jitterRadius: this.jitterRadius,
            targetSize: this.targetSize,
            targetX: this.targetX,
            targetY: this.targetY,
          )) {
        selectedConfigurationId = null;
      }
    }

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
