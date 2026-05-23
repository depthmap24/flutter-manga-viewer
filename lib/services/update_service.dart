import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';

class UpdateInfo {
  UpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.apkUrl,
    required this.releaseNotes,
    required this.htmlUrl,
  });

  final String latestVersion;
  final String currentVersion;
  final String? apkUrl;
  final String releaseNotes;
  final String htmlUrl;

  bool get isNewer => _compareVersions(latestVersion, currentVersion) > 0;

  static int _compareVersions(String a, String b) {
    final aParts = _split(a);
    final bParts = _split(b);
    final length = aParts.length > bParts.length ? aParts.length : bParts.length;
    for (var i = 0; i < length; i++) {
      final av = i < aParts.length ? aParts[i] : 0;
      final bv = i < bParts.length ? bParts[i] : 0;
      if (av != bv) return av - bv;
    }
    return 0;
  }

  static List<int> _split(String version) =>
      version.replaceAll(RegExp(r'^v'), '').split('.').map((s) {
        final n = RegExp(r'^\d+').firstMatch(s);
        return n == null ? 0 : int.parse(n.group(0)!);
      }).toList();
}

class UpdateService {
  UpdateService._();

  static Future<UpdateInfo?> checkForUpdate() async {
    final info = await PackageInfo.fromPlatform();
    final current = info.version;
    final uri = Uri.parse(
      'https://api.github.com/repos/${AppConstants.githubOwner}/${AppConstants.githubRepo}/releases/latest',
    );
    final resp = await http
        .get(uri, headers: {'Accept': 'application/vnd.github+json'}).timeout(
      const Duration(seconds: 10),
    );
    if (resp.statusCode != 200) return null;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final tag = (data['tag_name'] as String?) ?? '';
    final notes = (data['body'] as String?) ?? '';
    final htmlUrl = (data['html_url'] as String?) ?? '';
    final assets = (data['assets'] as List?) ?? const [];
    String? apkUrl;
    for (final asset in assets) {
      final name = (asset['name'] as String?) ?? '';
      if (name.toLowerCase().endsWith('.apk')) {
        apkUrl = asset['browser_download_url'] as String?;
        break;
      }
    }
    return UpdateInfo(
      latestVersion: tag,
      currentVersion: current,
      apkUrl: apkUrl,
      releaseNotes: notes,
      htmlUrl: htmlUrl,
    );
  }

  /// Downloads the APK from [apkUrl] and triggers the system installer.
  static Future<void> downloadAndInstall(String apkUrl) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/update.apk');
    final resp = await http.get(Uri.parse(apkUrl));
    if (resp.statusCode != 200) {
      throw Exception('Download failed (HTTP ${resp.statusCode})');
    }
    await file.writeAsBytes(resp.bodyBytes);
    await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
  }
}
