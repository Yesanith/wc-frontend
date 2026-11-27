import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// shares what a RepaintBoundary under [key] draws as a picture. false when there was nothing to draw
Future<bool> shareCard(GlobalKey key, {required String name, required String text}) async {
  final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return false;
  final image = await boundary.toImage(pixelRatio: 3);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) return false;
  final png = bytes.buffer.asUint8List();
  final file = '${name}_${DateTime.now().millisecondsSinceEpoch}.png';
  if (kIsWeb) {
    // a browser has no temporary directory, the picture is shared from its bytes
    await SharePlus.instance
        .share(ShareParams(files: [XFile.fromData(png, mimeType: 'image/png', name: file)], text: text));
  } else {
    final dir = await getTemporaryDirectory();
    final out = File('${dir.path}/$file');
    await out.writeAsBytes(png);
    await SharePlus.instance.share(ShareParams(files: [XFile(out.path)], text: text));
  }
  return true;
}
