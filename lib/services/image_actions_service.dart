import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

import '../core/log_service.dart';
import '../models/image_file.dart';

class ImageActionsService {
  Future<void> share(ImageFile imageFile) async {
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(imageFile.path)]),
      );
    } catch (e, st) {
      LogService.instance.error('Share failed for ${imageFile.name}: $e', st);
      rethrow;
    }
  }

  /// Deletes the file from disk and notifies Android MediaStore.
  Future<void> delete(ImageFile imageFile) async {
    try {
      final file = imageFile.file;
      if (await file.exists()) {
        await file.delete();
      }
      await PhotoManager.editor.android.removeAllNoExistsAsset();
      LogService.instance.info('Deleted: ${imageFile.name}');
    } catch (e, st) {
      LogService.instance.error('Delete failed for ${imageFile.name}: $e', st);
      rethrow;
    }
  }

  /// Saves [croppedBytes] back to the original file.
  Future<void> saveEdit(ImageFile original, Uint8List croppedBytes) async {
    try {
      await original.file.writeAsBytes(croppedBytes, flush: true);
      LogService.instance.info('Saved edit: ${original.name}');
    } catch (e, st) {
      LogService.instance.error(
          'saveEdit failed for ${original.name}: $e', st);
      rethrow;
    }
  }

  /// Rotates the image by [degrees] (-90 or 90) and returns rotated bytes.
  Future<Uint8List> rotateImage(ImageFile imageFile, int degrees) async {
    final bytes = await imageFile.file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Could not decode image for rotation');
    }
    final rotated = img.copyRotate(decoded, angle: degrees);
    if (imageFile.extension == '.png') {
      return Uint8List.fromList(img.encodePng(rotated));
    }
    return Uint8List.fromList(img.encodeJpg(rotated, quality: 92));
  }
}
