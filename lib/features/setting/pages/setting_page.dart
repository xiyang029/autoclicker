import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:open_filex/open_filex.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/platform/app_installer_platform_service.dart';
import '../../../core/services/app_update_service.dart';
import '../../autoclicker/controllers/auto_clicker_controller.dart';

class UpdatePage extends StatefulWidget {
  const UpdatePage({super.key, required this.controller});

  final AutoClickerController controller;

  @override
  State<UpdatePage> createState() => UpdatePageState();
}

class UpdatePageState extends State<UpdatePage> with WidgetsBindingObserver {
  final AppUpdateService _updateService = AppUpdateService();
  final ReceivePort _downloadPort = ReceivePort();

  bool _checkingUpdate = false;
  bool _downloading = false;
  bool _waitingInstallPermission = false;
  String? _pendingInstallApkPath;
  AppDownloadTask? _activeDownloadTask;
  bool _autoCheckedOnStart = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    IsolateNameServer.removePortNameMapping('autoclicker_downloader_port');
    IsolateNameServer.registerPortWithName(
      _downloadPort.sendPort,
      'autoclicker_downloader_port',
    );
    _downloadPort.listen(_handleDownloadUpdate);
  }

  @override
  void dispose() {
    IsolateNameServer.removePortNameMapping('autoclicker_downloader_port');
    _downloadPort.close();
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
    final currentVersion = widget.controller.currentVersion.isEmpty
        ? '--'
        : widget.controller.currentVersion;
    final canCheckUpdate =
        !_checkingUpdate && !_downloading && !_waitingInstallPermission;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        ShadCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _ProfileActionRow(
                label: '当前版本: $currentVersion',
                icon: LucideIcons.info,
                onPressed: null,
              ),
              const Divider(height: 1),
              _ProfileActionRow(
                label: _checkingUpdate
                    ? '检测中...'
                    : _waitingInstallPermission
                    ? '等待授权'
                    : '检测更新',
                icon: LucideIcons.refreshCw,
                onPressed: canCheckUpdate ? checkForUpdates : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> checkForUpdates({bool silentWhenUpToDate = false}) async {
    if (silentWhenUpToDate && _autoCheckedOnStart) return;
    _autoCheckedOnStart = _autoCheckedOnStart || silentWhenUpToDate;

    if (_checkingUpdate || _downloading) return;

    _setStateIfMounted(() {
      _checkingUpdate = true;
    });

    try {
      final release = await _updateService.fetchLatestRelease();
      final currentVersion = widget.controller.currentVersion;
      final hasUpdate =
          currentVersion.isEmpty ||
          _updateService.isNewerVersion(release.version, currentVersion);

      if (!mounted) return;

      if (!hasUpdate) {
        if (!silentWhenUpToDate) {
          _showMessage('当前已是最新版本');
        }
        return;
      }

      final shouldDownload = await _confirmDownload(release);
      if (!mounted || shouldDownload != true) {
        return;
      }

      await _downloadAndInstallRelease(release);
    } catch (_) {
      if (!mounted) return;
      _showMessage('检查更新失败');
    } finally {
      if (mounted) {
        _setStateIfMounted(() => _checkingUpdate = false);
      }
    }
  }

  Future<void> _downloadAndInstallRelease(AppReleaseInfo release) async {
    final hasNotificationPermission =
        await AppInstallerPlatformService.hasNotificationPermission();
    if (!mounted) return;

    if (!hasNotificationPermission) {
      final granted =
          await AppInstallerPlatformService.ensureNotificationPermission();
      if (!mounted) return;

      if (!granted) {
        _showMessage('需要允许通知权限，才能显示后台下载通知');
        return;
      }
    }

    _setStateIfMounted(() => _downloading = true);

    try {
      final task = await _updateService.downloadReleaseApk(release);
      if (!mounted) return;

      _activeDownloadTask = task;
      _showMessage('已开始后台下载，请在系统通知中查看');
    } catch (_) {
      if (!mounted) return;
      _setStateIfMounted(() {
        _downloading = false;
        _activeDownloadTask = null;
      });
      _showMessage('下载失败');
    }
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
      });

      await AppInstallerPlatformService.openInstallPermissionSettings();
      return;
    }

    final result = await OpenFilex.open(
      apkPath,
      type: 'application/vnd.android.package-archive',
    );
    if (!mounted) return;

    if (result.type == ResultType.done) {
      return;
    }

    final message = switch (result.type) {
      ResultType.permissionDenied => '无法打开安装包，请检查文件访问权限',
      ResultType.noAppToOpen => '系统没有可用的安装程序',
      ResultType.fileNotFound => '安装包不存在，请重新下载',
      ResultType.error => '打开安装包失败',
      ResultType.done => '',
    };
    _showMessage(message);
  }

  Future<bool> _confirmDownload(AppReleaseInfo release) async {
    final currentVersion = widget.controller.currentVersion;
    if (!mounted) return false;

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
            '最新版本 ${release.version}',
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
    unawaited(AppInstallerPlatformService.showToast(message));
  }

  void _setStateIfMounted(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  void _handleDownloadUpdate(dynamic data) {
    if (data is! List || data.length < 2) return;

    final task = _activeDownloadTask;
    if (task == null || data[0] != task.taskId) return;

    final status = DownloadTaskStatus.fromInt(data[1] as int);
    if (status == DownloadTaskStatus.complete) {
      _setStateIfMounted(() {
        _downloading = false;
        _activeDownloadTask = null;
      });
      _showMessage('下载完成，准备安装');
      final apkPath = task.filePath;
      if (apkPath.isNotEmpty) {
        unawaited(_openDownloadedApk(apkPath));
      } else {
        _showMessage('下载完成，但未找到安装包路径');
      }
      return;
    }

    if (status == DownloadTaskStatus.failed ||
        status == DownloadTaskStatus.canceled) {
      _setStateIfMounted(() {
        _downloading = false;
        _activeDownloadTask = null;
      });
      _showMessage('下载失败');
    }
  }
}

class _ProfileActionRow extends StatelessWidget {
  const _ProfileActionRow({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final enabled = onPressed != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 13),
        child: Row(
          children: [
            Icon(
              icon,
              color: enabled
                  ? theme.colorScheme.primary
                  : theme.colorScheme.mutedForeground,
              size: 20,
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Text(label, style: enabled ? null : theme.textTheme.muted),
            ),
            if (enabled)
              Icon(
                LucideIcons.chevronRight,
                color: theme.colorScheme.mutedForeground,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
