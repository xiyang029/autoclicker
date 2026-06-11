import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../autoclicker/controllers/auto_clicker_controller.dart';
import '../../autoclicker/widgets/panel_styles.dart';

class UpdatePage extends StatelessWidget {
  const UpdatePage({super.key, required this.controller});

  final AutoClickerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

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
                              '当前版本 ${controller.currentVersion.isEmpty ? '--' : controller.currentVersion}',
                              style: theme.textTheme.small,
                            ),
                            if (controller.updateStatusText != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                controller.updateStatusText!,
                                style: theme.textTheme.muted,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (controller.downloadingUpdate &&
                    controller.downloadProgress != null) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: controller.downloadProgress! / 100,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ],
                const SizedBox(height: 14),
                ShadButton.outline(
                  enabled:
                      !controller.checkingForUpdate &&
                      !controller.downloadingUpdate,
                  leading: const Icon(LucideIcons.download),
                  onPressed: () {
                    controller.checkForUpdates(
                      confirmDownload: (prompt) {
                        return _confirmDownload(context, prompt);
                      },
                      showMessage: (message) {
                        _showMessage(context, message);
                      },
                    );
                  },
                  child: Text(
                    controller.downloadingUpdate
                        ? '下载中...'
                        : controller.checkingForUpdate
                        ? '检查中...'
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

  Future<bool> _confirmDownload(
    BuildContext context,
    UpdatePrompt prompt,
  ) async {
    final shouldDownload = await showShadDialog<bool>(
      context: context,
      builder: (context) {
        return ShadDialog.alert(
          radius: const BorderRadius.all(Radius.circular(12)),
          removeBorderRadiusWhenTiny: false,
          useSafeArea: false,
          title: const Text('发现新版本'),
          description: Text(
            '当前版本 ${prompt.currentVersion.isEmpty ? '未知' : prompt.currentVersion}，'
            '最新版本 ${prompt.release.version}。',
          ),
          actions: [
            ShadButton.outline(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('稍后'),
            ),
            ShadButton(
              leading: const Icon(LucideIcons.download),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('下载更新'),
            ),
          ],
        );
      },
    );
    return shouldDownload == true;
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
