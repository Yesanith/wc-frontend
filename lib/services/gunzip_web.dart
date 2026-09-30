import 'package:archive/archive.dart';

List<int> gunzip(List<int> bytes) => GZipDecoder().decodeBytes(bytes);
