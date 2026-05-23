import 'dart:io';

import '../core/constants.dart';
import '../models/image_file.dart';

class FileScanner {
  FileScanner._();

  /// Scans a directory recursively for supported image files.
  static Future<List<ImageFile>> scanDirectory(Directory dir) async {
    if (!await dir.exists()) return const [];
    final results = <ImageFile>[];
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File && ImageFile.isSupported(entity.path)) {
          results.add(ImageFile(entity));
        }
      }
    } on FileSystemException {
      // Permission denied on a subtree — return what we got.
    }
    results.sort((a, b) => b.path.compareTo(a.path));
    return results;
  }

  /// Returns directories from [AppConstants.defaultScanRoots] that exist.
  static Future<List<Directory>> availableRoots() async {
    final result = <Directory>[];
    for (final path in AppConstants.defaultScanRoots) {
      final dir = Directory(path);
      if (await dir.exists()) result.add(dir);
    }
    return result;
  }
}
