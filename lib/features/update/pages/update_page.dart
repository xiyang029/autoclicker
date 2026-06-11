import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/platform/app_installer_platform_service.dart';
import '../../../core/services/app_update_service.dart';
import '../../autoclicker/controllers/auto_clicker_controller.dart';
import '../../autoclicker/widgets/panel_styles.dart';

class UpdatePage extends StatefulWidget {
  const UpdatePage({super.key, required this.controller});

  final AutoClickerController controller;

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> with WidgetsBindingObserver {
  final AppUpdateService _updateService = AppUpdateService();

  bool _checkingUpdate = false;
  String? _pendingInstallApkPath;
  bool _waitingInstallPermission = false;
  String? _statusText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resumePendingInstallIfPossible();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final currentVersion = widget.controller.currentVersion.isEmpty
        ? '--'
        : widget.controller.currentVersion;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        ShadCard(
          title: Text('版本更新', style: theme.textTheme.h4),
          child: Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: mutedPanelDecoration(theme),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.download,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '当前版本 $currentVersion',
                              style: theme.textTheme.small,
                            ),
                            if (_statusText != null) ...[
                              const SizedBox(height: 4),
                              Text(_statusText!, style: theme.textTheme.muted),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ShadButton.outline(
                  enabled: !_checkingUpdate && !_waitingInstallPermission,
                  leading: const Icon(LucideIcons.download),
                  onPressed: _checkForUpdates,
                  child: Text(
                    _checkingUpdate
                        ? '检查中...'
                        : _waitingInstallPermission
                        ? '等待授权'
                        : '检查更新',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _checkForUpdates() async {
    if (_checkingUpdate) return;

    _setStateIfMounted(() {
      _checkingUpdate = true;
      _statusText = '正在检查更新...';
    });

    try {
      final release = await _updateService.fetchLatestRelease();
      final currentVersion = widget.controller.currentVersion;
      final hasUpdate =
          currentVersion.isEmpty ||
          _updateService.isNewerVersion(release.version, currentVersion);

      if (!mounted) return;

      if (!hasUpdate) {
        _setStateIfMounted(() => _statusText = '当前已是最新版本');
        _showMessage('当前已是最新版本');
        return;
      }

      final shouldDownload = await _confirmDownload(release);
      if (!mounted || !shouldDownload) {
        if (mounted) {
          _setStateIfMounted(() => _statusText = '发现新版本 ${release.version}');
        }
        return;
      }

      await _downloadAndInstallRelease(release);
    } catch (_) {
      if (!mounted) return;
      _setStateIfMounted(() => _statusText = '检查更新失败');
      _showMessage('检查更新失败');
    } finally {
      if (mounted) {
        _setStateIfMounted(() => _checkingUpdate = false);
      }
    }
  }

  Future<void> _downloadAndInstallRelease(AppReleaseInfo release) async {
    _setStateIfMounted(() => _statusText = '准备下载 ${release.version}');

    try {
      final file = await _downloadRelease(release);
      _setStateIfMounted(() => _statusText = '下载完成，正在打开安装包');
      await _openDownloadedApk(file.path);
    } catch (_) {
      if (!mounted) return;
      _setStateIfMounted(() => _statusText = '下载更新失败');
      unawaited(AppInstallerPlatformService.showToast('下载失败'));
    }
  }

  Future<File> _downloadRelease(AppReleaseInfo release) {
    return _updateService.downloadReleaseApk(
      release,
      onProgress: (receivedBytes, totalBytes) {
        final progress = (receivedBytes / totalBytes * 100)
            .clamp(0, 100)
            .round();
        _setStateIfMounted(
          () => _statusText = '正在下载 ${release.version} ($progress%)',
        );
      },
    );
  }

  Future<void> _resumePendingInstallIfPossible() async {
    if (!_waitingInstallPermission || _pendingInstallApkPath == null) return;

    final allowed =
        await AppInstallerPlatformService.canRequestPackageInstalls();
    if (!allowed) return;

    final apkPath = _pendingInstallApkPath;
    _setStateIfMounted(() {
      _waitingInstallPermission = false;
      _pendingInstallApkPath = null;
      _statusText = '权限已授权，正在打开系统安装器';
    });

    if (apkPath != null) {
      await _openDownloadedApk(apkPath);
    }
  }

  Future<void> _openDownloadedApk(String apkPath) async {
    final allowed =
        await AppInstallerPlatformService.canRequestPackageInstalls();
    if (!mounted) return;

    if (!allowed) {
      _setStateIfMounted(() {
        _pendingInstallApkPath = apkPath;
        _waitingInstallPermission = true;
        _statusText = '请先允许安装未知来源应用';
      });
      await AppInstallerPlatformService.openInstallPermissionSettings();
      return;
    }

    _setStateIfMounted(() => _statusText = '正在打开系统安装器');

    final result = await OpenFilex.open(
      apkPath,
      type: 'application/vnd.android.package-archive',
    );
    if (!mounted) return;

    if (result.type == ResultType.done) {
      _setStateIfMounted(() => _statusText = '请在系统安装器中完成安装');
      return;
    }

    final message = switch (result.type) {
      ResultType.permissionDenied => '无法打开安装包，请检查文件访问权限',
      ResultType.noAppToOpen => '系统没有可用的安装程序',
      ResultType.fileNotFound => '安装包不存在，请重新下载',
      ResultType.error => '打开安装包失败',
      ResultType.done => '',
    };
    _setStateIfMounted(() => _statusText = message);
    _showMessage(message);
  }

  Future<bool> _confirmDownload(AppReleaseInfo release) async {
    final currentVersion = widget.controller.currentVersion;
    final shouldDownload = await showShadDialog<bool>(
      context: context,
      builder: (context) {
        return ShadDialog.alert(
          radius: const BorderRadius.all(Radius.circular(12)),
          removeBorderRadiusWhenTiny: false,
          useSafeArea: false,
          title: const Text('发现新版本'),
          description: Text(
            '当前版本 ${currentVersion.isEmpty ? '未知' : currentVersion}，'
            '最新版本 ${release.version}。',
          ),
          actions: [
            ShadButton.outline(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('稍后'),
            ),
            ShadButton(
              leading: const Icon(LucideIcons.download),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('下载更新'),
            ),
          ],
        );
      },
    );
    return shouldDownload == true;
  }

  void _showMessage(String message) {
    ShadToaster.of(context).show(ShadToast(description: Text(message)));
  }

  void _setStateIfMounted(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }
}
