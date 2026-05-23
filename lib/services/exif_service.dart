import 'dart:io';

import 'package:exif/exif.dart';

class ExifService {
  ExifService._();

  /// Returns a flat label → value map of EXIF tags. Empty if no EXIF.
  static Future<Map<String, String>> read(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final tags = await readExifFromBytes(bytes);
      if (tags.isEmpty) return const {};
      final out = <String, String>{};
      tags.forEach((k, v) {
        out[k] = v.printable;
      });
      return out;
    } catch (_) {
      return const {};
    }
  }
}
