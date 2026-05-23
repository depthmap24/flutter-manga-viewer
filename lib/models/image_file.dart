import 'dart:io';
import 'package:path/path.dart' as p;

import '../core/constants.dart';

/// A discovered image on disk.
class ImageFile {
  ImageFile(this.file);

  final File file;

  String get path => file.path;
  String get name => p.basename(path);
  String get extension => p.extension(path).toLowerCase();
  bool get isPng => extension == '.png';
  bool get isSvg => extension == '.svg';

  static bool isSupported(String path) {
    final ext = p.extension(path).toLowerCase();
    return AppConstants.supportedExtensions.contains(ext);
  }
}
