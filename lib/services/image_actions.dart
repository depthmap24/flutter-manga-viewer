import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

class ImageActions {
  ImageActions._();

  /// Rotates the image at [path] by [quarterTurns] * 90° clockwise and
  /// overwrites the file. Returns true on success.
  static Future<bool> rotate(String path, {int quarterTurns = 1}) async {
    final file = File(path);
    if (!await file.exists()) return false;
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return false;
    final angle = (quarterTurns * 90) % 360;
    final rotated = img.copyRotate(decoded, angle: angle);
    final out = _encodeForExtension(rotated, p.extension(path));
    await file.writeAsBytes(out, flush: true);
    return true;
  }

  /// Saves cropped bytes [data] over the source [path]. Used by the crop screen.
  static Future<void> overwrite(String path, Uint8List data) =>
      File(path).writeAsBytes(data, flush: true);

  /// Deletes the file at [path]. Returns true if the file no longer exists.
  static Future<bool> delete(String path) async {
    final file = File(path);
    if (!await file.exists()) return true;
    try {
      await file.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  static List<int> _encodeForExtension(img.Image image, String extension) {
    switch (extension.toLowerCase()) {
      case '.png':
        return img.encodePng(image);
      case '.webp':
        // image package doesn't encode webp; fall back to png bytes but keep extension
        return img.encodePng(image);
      default:
        return img.encodeJpg(image, quality: 92);
    }
  }
}
