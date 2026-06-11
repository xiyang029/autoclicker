import 'dart:convert';
import 'dart:io';

class AppReleaseInfo {
  const AppReleaseInfo({
    required this.version,
    required this.apkUrl,
    required this.expectedSize,
  });

  final String version;
  final String apkUrl;
  final int expectedSize;
}

class AppUpdateService {
  AppUpdateService({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;
  static const String _apkName = 'app-release.apk';

  /// 获取最新 Release 信息
  Future<AppReleaseInfo> fetchLatestRelease() async {
    final uri = Uri.parse(
      'https://api.github.com/repos/xiyang029/autoclicker/releases/latest',
    );
    final request = await _httpClient.getUrl(uri);
    request.headers.set(HttpHeaders.userAgentHeader, 'autoclicker-app-updater');

    final response = await request.close();
    if (response.statusCode != 200) {
      throw HttpException('Fetch failed: ${response.statusCode}', uri: uri);
    }

    final Map<String, dynamic> data = json.decode(
      await utf8.decodeStream(response),
    );
    final assets = data['assets'] as List<dynamic>;

    // 精确匹配名为 'app-release.apk' 的资源
    final apkAsset = assets.firstWhere(
      (asset) => asset['name'] == _apkName,
      orElse: () =>
          throw const FormatException('$_apkName not found in GitHub assets'),
    );

    return AppReleaseInfo(
      version: data['tag_name'] as String,
      apkUrl: apkAsset['browser_download_url'] as String,
      expectedSize: (apkAsset['size'] as num).toInt(),
    );
  }

  /// 下载 APK（如遇中断立删残缺文件，下次全新重下）
  Future<File> downloadReleaseApk(
    AppReleaseInfo release, {
    void Function(int received, int total)? onProgress,
  }) async {
    final cacheFile = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}$_apkName',
    );

    // 1. 缓存强校验：文件存在且大小完全一致，直接复用
    if (await cacheFile.exists() &&
        await cacheFile.length() == release.expectedSize) {
      onProgress?.call(release.expectedSize, release.expectedSize);
      return cacheFile;
    }

    // 2. 发起网络请求
    final downloadUri = Uri.parse(release.apkUrl);
    final request = await _httpClient.getUrl(downloadUri)
      ..followRedirects = true;
    request.headers.set(HttpHeaders.userAgentHeader, 'autoclicker-app-updater');

    final response = await request.close();
    if (response.statusCode >= 400) {
      throw HttpException(
        'Download failed: ${response.statusCode}',
        uri: downloadUri,
      );
    }

    // 3. 开始下载流式写入
    var receivedBytes = 0;
    final sink = cacheFile.openWrite(); // 默认 FileMode.write 会自动清空旧文件

    try {
      await sink.addStream(
        response.map((chunk) {
          receivedBytes += chunk.length;
          onProgress?.call(receivedBytes, release.expectedSize);
          return chunk;
        }),
      );
      await sink.close(); // 必须先正常关闭流，才能保证后续的文件大小校验准确
    } catch (_) {
      // 核心改动：中途断网或报错，立即安全关闭并清理残缺文件
      await sink.close().catchError((_) {});
      if (await cacheFile.exists()) await cacheFile.delete();
      rethrow;
    }

    // 4. 最终大小安全校验
    if (receivedBytes != release.expectedSize) {
      if (await cacheFile.exists()) await cacheFile.delete();
      throw FileSystemException(
        'Size mismatch: expected ${release.expectedSize}, got $receivedBytes',
        cacheFile.path,
      );
    }

    return cacheFile;
  }

  /// 简单的语义化版本号对比 (支持 v1.2.3 或 1.2.3)
  bool isNewerVersion(String latest, String current) {
    List<int> parse(String v) => RegExp(
      r'\d+',
    ).allMatches(v).map((m) => int.parse(m.group(0)!)).toList();
    final lParts = parse(latest), cParts = parse(current);

    for (var i = 0; i < lParts.length || i < cParts.length; i++) {
      final l = i < lParts.length ? lParts[i] : 0;
      final c = i < cParts.length ? cParts[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }
}
