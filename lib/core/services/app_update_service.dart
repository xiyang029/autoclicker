import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

class AppReleaseInfo {
  const AppReleaseInfo({required this.version, required this.assets});

  final String version;
  final List<AppReleaseAsset> assets;

  AppReleaseAsset? assetForAbi(String abi) {
    final normalizedAbi = _normalizeAbi(abi);
    final preferredNames = _preferredAssetNames(normalizedAbi);

    for (final preferredName in preferredNames) {
      for (final asset in assets) {
        if (asset.name == preferredName) {
          return asset;
        }
      }
    }

    return null;
  }
}

class AppReleaseAsset {
  const AppReleaseAsset({required this.name, required this.downloadUrl});

  final String name;
  final String downloadUrl;

  String get cacheKey => _normalizeCacheKey(name);

  String get abiLabel => _inferAbiLabel(name);
}

class AppDownloadTask {
  const AppDownloadTask({required this.taskId, required this.filePath});

  final String taskId;
  final String filePath;
}

class AppUpdateService {
  AppUpdateService({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;

  Future<String> getDeviceAbi() async {
    if (!Platform.isAndroid) return '';

    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.supportedAbis.isEmpty) return '';
      return androidInfo.supportedAbis.first;
    } catch (_) {
      return '';
    }
  }

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
    final assets = (data['assets'] as List<dynamic>)
        .map(
          (asset) => AppReleaseAsset(
            name: asset['name'] as String,
            downloadUrl: asset['browser_download_url'] as String,
          ),
        )
        .toList(growable: false);

    if (assets.isEmpty) {
      throw const FormatException('No GitHub release assets found');
    }

    return AppReleaseInfo(version: data['tag_name'] as String, assets: assets);
  }

  /// 按当前设备 ABI 启动对应 APK 的下载任务
  Future<AppDownloadTask> downloadReleaseApk(AppReleaseInfo release) async {
    final deviceAbi = await getDeviceAbi();
    final asset = release.assetForAbi(deviceAbi) ?? _fallbackAsset(release);

    if (asset == null) {
      throw const FormatException(
        'No matching APK asset found for current device ABI',
      );
    }

    final cacheDir = Directory.systemTemp;
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    final cacheFile = File(
      '${cacheDir.path}${Platform.pathSeparator}${asset.cacheKey}',
    );
    if (await cacheFile.exists()) {
      await cacheFile.delete();
    }

    final taskId = await FlutterDownloader.enqueue(
      url: asset.downloadUrl,
      headers: const {'User-Agent': 'autoclicker-app-updater'},
      savedDir: cacheDir.path,
      fileName: asset.cacheKey,
      showNotification: true,
      openFileFromNotification: false,
    );

    if (taskId == null) {
      throw const FileSystemException('Failed to enqueue download task');
    }

    return AppDownloadTask(
      taskId: taskId,
      filePath: '${cacheDir.path}${Platform.pathSeparator}${asset.cacheKey}',
    );
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

AppReleaseAsset? _fallbackAsset(AppReleaseInfo release) {
  const fallbackOrder = ['arm64-v8a', 'armeabi-v7a', 'x86_64'];

  for (final abi in fallbackOrder) {
    final asset = release.assetForAbi(abi);
    if (asset != null) return asset;
  }

  return release.assets.firstWhere(
    (asset) => asset.name.toLowerCase().endsWith('.apk'),
    orElse: () => release.assets.first,
  );
}

String _normalizeAbi(String abi) {
  final normalized = abi.trim().toLowerCase();
  if (normalized.contains('arm64') || normalized.contains('aarch64')) {
    return 'arm64-v8a';
  }
  if (normalized.contains('armeabi') || normalized.contains('armv7')) {
    return 'armeabi-v7a';
  }
  if (normalized.contains('x86_64') || normalized.contains('amd64')) {
    return 'x86_64';
  }
  if (normalized.contains('x86')) {
    return 'x86';
  }
  return normalized;
}

List<String> _preferredAssetNames(String abi) {
  final normalized = _normalizeAbi(abi);
  final candidates = <String>[
    'app-release-$normalized.apk',
    'app-$normalized-release.apk',
    'autoclicker-$normalized.apk',
    '$normalized.apk',
  ];

  if (normalized == 'arm64-v8a') {
    candidates.addAll(['app-arm64-v8a-release.apk', 'app-arm64.apk']);
  }

  return candidates;
}

String _inferAbiLabel(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('arm64-v8a') || lower.contains('arm64')) {
    return 'arm64-v8a';
  }
  if (lower.contains('armeabi-v7a') || lower.contains('v7a')) {
    return 'armeabi-v7a';
  }
  if (lower.contains('x86_64')) {
    return 'x86_64';
  }
  if (lower.contains('x86')) {
    return 'x86';
  }
  return 'universal';
}

String _normalizeCacheKey(String name) {
  final safe = name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_');
  return safe.toLowerCase();
}
