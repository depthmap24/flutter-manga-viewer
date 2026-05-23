import 'dart:io';

import '../core/constants.dart';
import '../models/image_file.dart';

class FileScanner {
  FileScanner._();

  /// Scans a directory recursively for supported image files.
  static Future<List<ImageFile>> scanDirectory(Directory dir) async {
    bool exists;
    try {
      exists = await dir.exists();
    } catch (_) {
      return const [];
    }
    if (!exists) return const [];

    final results = <ImageFile>[];
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File && ImageFile.isSupported(entity.path)) {
          results.add(ImageFile(entity));
        }
      }
    } on FileSystemException {
      // Permission denied on a subtree — return what we got so far.
    }
    results.sort((a, b) => b.path.compareTo(a.path));
    return results;
  }

  /// Returns directories from [AppConstants.defaultScanRoots] that exist AND
  /// are readable. Catches per-path exceptions so a single inaccessible root
  /// (e.g. permission denied on Android 11+ scoped storage) doesn't fail the
  /// whole list.
  static Future<List<Directory>> availableRoots() async {
    final result = <Directory>[];
    for (final path in AppConstants.defaultScanRoots) {
      try {
        final dir = Directory(path);
        if (await dir.exists()) result.add(dir);
      } catch (_) {
        // Permission denied / no longer mounted / etc. — skip this root.
      }
    }
    return result;
  }
}
