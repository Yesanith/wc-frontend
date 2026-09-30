// unpacks the gzip data the app ships (the item index, the recipes, the map
// and the market). a phone uses dart:io, a browser has none and uses a decoder
// written in dart
export 'gunzip_io.dart' if (dart.library.js_interop) 'gunzip_web.dart';
