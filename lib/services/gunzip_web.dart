import 'package:archive/archive.dart';

List<int> gunzip(List<int> bytes) => const GZipDecoder().decodeBytes(bytes);
