import 'dart:convert';

import '../models/click_configuration.dart';
import 'android_autoclicker_channel.dart';

class ClickConfigurationStorage {
  ClickConfigurationStorage._();

  /// 读取平台共享偏好中的配置列表，并在 Flutter 侧补齐默认值。
  static Future<List<ClickConfiguration>> loadConfigurations() async {
    final payload =
        await AndroidAutoClickerChannel.loadConfigurationListPayload();
    if (payload.trim().isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is! List) {
        return const [];
      }

      return decoded
          .whereType<Map<Object?, Object?>>()
          .map(
            (item) => ClickConfiguration.fromChannelMap(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .where((configuration) => configuration.id.isNotEmpty)
          .toList();
    } on FormatException {
      return const [];
    }
  }

  /// 将 Flutter 侧配置列表编码为 JSON 后写回平台共享偏好。
  static Future<void> saveConfigurations(
    List<ClickConfiguration> configurations,
  ) {
    // 统一只保留当前配置结构，移除旧数据格式兼容写回。
    return AndroidAutoClickerChannel.saveConfigurationListPayload(
      jsonEncode(
        configurations
            .map((configuration) => configuration.toChannelMap())
            .toList(),
      ),
    );
  }
}
