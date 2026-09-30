import 'dart:io';

List<int> gunzip(List<int> bytes) => gzip.decode(bytes);
