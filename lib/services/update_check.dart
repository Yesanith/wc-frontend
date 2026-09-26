import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// version this apk was built with, set by the release workflow
const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');

const _releasesApi = 'https://api.github.com/repos/Yesanith/tyria-companion/releases/latest';

class UpdateInfo {
  const UpdateInfo(this.version, this.apkUrl, this.pageUrl, this.notes);

  final String version;

  /// direct link to the apk asset, null when a release has no apk attached
  final String? apkUrl;
  final String pageUrl;
  final String notes;

  bool get isNewerThan => compareVersions(version, appVersion) > 0;
}

/// -1, 0 or 1. anything that is not a number sorts as older, so a dev build
/// always sees a release as newer
int compareVersions(String a, String b) {
  List<int> parts(String v) => [
        for (final piece in v.replaceAll('v', '').split('.'))
          int.tryParse(piece.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
      ];
  final left = parts(a);
  final right = parts(b);
  if (b == 'dev') return 1;
  for (var i = 0; i < 3; i++) {
    final l = i < left.length ? left[i] : 0;
    final r = i < right.length ? right[i] : 0;
    if (l != r) return l > r ? 1 : -1;
  }
  return 0;
}

final updateProvider = FutureProvider<UpdateInfo?>((ref) async {
  final res = await http.get(Uri.parse(_releasesApi),
      headers: {'Accept': 'application/vnd.github+json'}).timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) return null;
  final data = jsonDecode(utf8.decode(res.bodyBytes));
  if (data is! Map) return null;
  final version = '${data['tag_name'] ?? ''}'.replaceAll('v', '');
  if (version.isEmpty) return null;
  String? apk;
  for (final asset in (data['assets'] as List?) ?? const []) {
    if (asset is Map && '${asset['name']}'.endsWith('.apk')) {
      apk = '${asset['browser_download_url']}';
    }
  }
  return UpdateInfo(version, apk, '${data['html_url'] ?? ''}', '${data['body'] ?? ''}');
});
