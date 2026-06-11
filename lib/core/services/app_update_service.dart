import 'dart:convert';
import 'dart:io';

class AppReleaseInfo {
  const AppReleaseInfo({
    required this.version,
    required this.releasePageUrl,
    required this.apkUrl,
    required this.fileName,
  });

  final String version;
  final String releasePageUrl;
  final String apkUrl;
  final String fileName;
}

class AppUpdateService {
  AppUpdateService({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;
  static final Uri _latestReleaseUri = Uri.parse(
    'https://gitee.com/xiaoxi233xyz/autoclicker/releases/latest',
  );

  Future<AppReleaseInfo> fetchLatestRelease() async {
    final latestResponse = await _get(
      _latestReleaseUri,
      followRedirects: false,
    );
    try {
      final location = latestResponse.headers.value(HttpHeaders.locationHeader);
      final releaseUri = location == null || location.isEmpty
          ? _latestReleaseUri
          : _latestReleaseUri.resolve(location);
      final version = _extractVersionFromReleaseUri(releaseUri);
      final html = await _readResponseBody(
        await _get(releaseUri, followRedirects: true),
      );
      final apkUri = _extractApkUri(html, releaseUri);
      return AppReleaseInfo(
        version: version,
        releasePageUrl: releaseUri.toString(),
        apkUrl: apkUri.toString(),
        fileName: apkUri.pathSegments.isNotEmpty
            ? apkUri.pathSegments.last
            : 'autoclicker-$version.apk',
      );
    } finally {
      latestResponse.detachSocket().then((socket) => socket.destroy());
    }
  }

  bool isNewerVersion(String latestVersion, String currentVersion) {
    final latestParts = _parseVersionParts(latestVersion);
    final currentParts = _parseVersionParts(currentVersion);
    final length = latestParts.length > currentParts.length
        ? latestParts.length
        : currentParts.length;

    for (var index = 0; index < length; index += 1) {
      final latest = index < latestParts.length ? latestParts[index] : 0;
      final current = index < currentParts.length ? currentParts[index] : 0;
      if (latest > current) return true;
      if (latest < current) return false;
    }
    return false;
  }

  Future<HttpClientResponse> _get(
    Uri uri, {
    required bool followRedirects,
  }) async {
    final request = await _httpClient.getUrl(uri);
    request.followRedirects = followRedirects;
    request.headers.set(HttpHeaders.userAgentHeader, 'autoclicker-app-updater');
    final response = await request.close();
    if (response.statusCode >= 400) {
      throw HttpException(
        'Request failed with status ${response.statusCode}',
        uri: uri,
      );
    }
    return response;
  }

  Future<String> _readResponseBody(HttpClientResponse response) async {
    return utf8.decodeStream(response);
  }

  String _extractVersionFromReleaseUri(Uri uri) {
    final segments = uri.pathSegments;
    final tagIndex = segments.indexOf('tag');
    if (tagIndex >= 0 && tagIndex + 1 < segments.length) {
      return segments[tagIndex + 1];
    }
    throw const FormatException('Unable to resolve latest release version');
  }

  Uri _extractApkUri(String html, Uri releaseUri) {
    final match = RegExp(
      r'''href=["']([^"']*?/releases/download/[^"']+?\.apk)["']''',
      caseSensitive: false,
    ).firstMatch(html);
    if (match == null) {
      throw const FormatException('APK download link not found');
    }
    return releaseUri.resolve(match.group(1)!);
  }

  List<int> _parseVersionParts(String version) {
    final normalized = version
        .trim()
        .replaceFirst(RegExp(r'^[vV]'), '')
        .split('+')
        .first;
    final matches = RegExp(r'\d+').allMatches(normalized);
    return matches.map((match) => int.parse(match.group(0)!)).toList();
  }
}
