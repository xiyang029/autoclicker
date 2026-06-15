import 'dart:convert';
import 'dart:io';

import '../platform/app_installer_platform_service.dart';

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
  const AppReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.expectedSize,
  });

  final String name;
  final String downloadUrl;
  final int expectedSize;

  String get cacheKey => _normalizeCacheKey(name);

  String get abiLabel => _inferAbiLabel(name);
}

class AppUpdateService {
  AppUpdateService({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;

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
            expectedSize: (asset['size'] as num).toInt(),
          ),
        )
        .toList(growable: false);

    if (assets.isEmpty) {
      throw const FormatException('No GitHub release assets found');
    }

    return AppReleaseInfo(version: data['tag_name'] as String, assets: assets);
  }

  /// 按当前设备 ABI 下载对应 APK
  Future<File> downloadReleaseApk(
    AppReleaseInfo release, {
    void Function(int received, int total)? onProgress,
  }) async {
    final deviceAbi = await AppInstallerPlatformService.getDeviceAbi();
    final asset = release.assetForAbi(deviceAbi) ?? _fallbackAsset(release);

    if (asset == null) {
      throw const FormatException(
        'No matching APK asset found for current device ABI',
      );
    }

    final cacheFile = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}${asset.cacheKey}',
    );

    if (await cacheFile.exists() &&
        await cacheFile.length() == asset.expectedSize) {
      onProgress?.call(asset.expectedSize, asset.expectedSize);
      return cacheFile;
    }

    final downloadUri = Uri.parse(asset.downloadUrl);
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

    var receivedBytes = 0;
    final sink = cacheFile.openWrite();

    try {
      await sink.addStream(
        response.map((chunk) {
          receivedBytes += chunk.length;
          onProgress?.call(receivedBytes, asset.expectedSize);
          return chunk;
        }),
      );
      await sink.close();
    } catch (_) {
      await sink.close().catchError((_) {});
      if (await cacheFile.exists()) await cacheFile.delete();
      rethrow;
    }

    if (receivedBytes != asset.expectedSize) {
      if (await cacheFile.exists()) await cacheFile.delete();
      throw FileSystemException(
        'Size mismatch: expected ${asset.expectedSize}, got $receivedBytes',
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
