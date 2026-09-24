import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// icons from render.guildwars2.com, downloaded once and kept on disk.
/// the urls are content addressed (signature and file id), so a cached
/// file never goes stale
class IconCache {
  IconCache(this.dir);

  final Directory dir;
  final Map<String, Future<File?>> _pending = {};
  final http.Client _client = http.Client();

  static Future<IconCache> open() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/icons');
    if (!await dir.exists()) await dir.create(recursive: true);
    return IconCache(dir);
  }

  File _fileFor(String url) {
    final segments = Uri.tryParse(url)?.pathSegments ?? const [];
    final name = segments.length >= 2
        ? '${segments[segments.length - 2]}_${segments.last}'
        : url.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return File('${dir.path}/$name');
  }

  /// the file when it is already on disk, a quick stat and nothing else
  File? cached(String url) {
    final file = _fileFor(url);
    return file.existsSync() ? file : null;
  }

  /// downloads the icon unless another widget is already doing it
  Future<File?> fetch(String url) {
    return _pending.putIfAbsent(url, () async {
      try {
        final res = await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
        if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;
        final file = _fileFor(url);
        await file.writeAsBytes(res.bodyBytes, flush: true);
        return file;
      } catch (_) {
        return null;
      } finally {
        // a failed download may be retried later
        unawaited(Future(() => _pending.remove(url)));
      }
    });
  }

  Future<void> clear() async {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
      await dir.create(recursive: true);
    } catch (_) {}
  }
}

/// overridden in main() once the icon directory exists
final iconCacheProvider = Provider<IconCache?>((ref) => null);

/// shows a game icon from the disk cache, downloading it the first time
class CachedIcon extends ConsumerStatefulWidget {
  const CachedIcon({super.key, required this.url, this.fit = BoxFit.cover});

  final String url;
  final BoxFit fit;

  @override
  ConsumerState<CachedIcon> createState() => _CachedIconState();
}

class _CachedIconState extends ConsumerState<CachedIcon> {
  File? _file;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant CachedIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _file = null;
      _resolve();
    }
  }

  void _resolve() {
    final cache = ref.read(iconCacheProvider);
    if (cache == null) return;
    final hit = cache.cached(widget.url);
    if (hit != null) {
      _file = hit;
      return;
    }
    final url = widget.url;
    cache.fetch(url).then((file) {
      if (mounted && file != null && widget.url == url) setState(() => _file = file);
    });
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    if (file != null) {
      return Image.file(file, fit: widget.fit, errorBuilder: (context, error, stack) => const SizedBox.shrink());
    }
    // no disk cache available (tests) or still downloading
    if (ref.read(iconCacheProvider) == null) {
      return Image.network(widget.url, fit: widget.fit, errorBuilder: (context, error, stack) => const SizedBox.shrink());
    }
    return const SizedBox.shrink();
  }
}
