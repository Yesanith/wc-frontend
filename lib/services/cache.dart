import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// json files on disk, used for game data that barely ever changes
/// (items, currencies, colors, ...). every file keeps the time it was
/// written so callers can decide when it is too old
class DiskCache {
  DiskCache(this.dir);

  final Directory dir;

  static Future<DiskCache> open() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    return DiskCache(dir);
  }

  File _file(String name) => File('${dir.path}/$name.json');

  Future<Map<String, dynamic>?> read(String name, {required Duration maxAge}) async {
    try {
      final file = _file(name);
      if (!await file.exists()) return null;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) return null;
      final at = DateTime.tryParse('${raw['at']}');
      if (at == null || DateTime.now().difference(at) > maxAge) return null;
      final data = raw['data'];
      return data is Map ? Map<String, dynamic>.from(data) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String name, Map<String, dynamic> data) async {
    try {
      await _file(name).writeAsString(jsonEncode({'at': DateTime.now().toIso8601String(), 'data': data}));
    } catch (_) {
      // cache failures are never fatal
    }
  }

  Future<void> clear() async {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
      await dir.create(recursive: true);
    } catch (_) {}
  }

  Future<int> sizeInBytes() async {
    var total = 0;
    try {
      await for (final f in dir.list()) {
        if (f is File) total += await f.length();
      }
    } catch (_) {}
    return total;
  }
}
