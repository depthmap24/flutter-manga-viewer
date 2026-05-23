import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart';

import 'asset_file.dart';

class ImageActions {
  ImageActions._();

  /// Rotates the [asset] by [quarterTurns] * 90° clockwise and saves the
  /// result as a NEW MediaStore entry (since we cannot legally modify a
  /// MediaStore asset we don't own). Returns the new AssetEntity or null.
  static Future<AssetEntity?> rotate(
    AssetEntity asset, {
    int quarterTurns = 1,
  }) async {
    final file = await resolveAssetFile(asset);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final rotated = img.copyRotate(decoded, angle: (quarterTurns * 90) % 360);
    final ext = p.extension(file.path).toLowerCase();
    final out = _encodeForExtension(rotated, ext);
    return PhotoManager.editor.saveImage(
      out,
      filename: '${p.basenameWithoutExtension(file.path)}_rot$ext',
    );
  }

  /// Saves cropped bytes [data] as a new MediaStore entry.
  static Future<AssetEntity?> saveCropped(
    String originalName,
    Uint8List data,
  ) async {
    return PhotoManager.editor.saveImage(
      data,
      filename:
          '${p.basenameWithoutExtension(originalName)}_crop${p.extension(originalName)}',
    );
  }

  /// Deletes the asset via MediaStore. Returns true if it no longer exists.
  static Future<bool> delete(AssetEntity asset) async {
    try {
      final removed = await PhotoManager.editor.deleteWithIds([asset.id]);
      return removed.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Uint8List _encodeForExtension(img.Image image, String extension) {
    switch (extension.toLowerCase()) {
      case '.png':
        return img.encodePng(image);
      case '.webp':
        // image package doesn't encode webp; fall back to png bytes
        return img.encodePng(image);
      default:
        return Uint8List.fromList(img.encodeJpg(image, quality: 92));
    }
  }
}

/// Helper for the metadata sheet — returns the resolved [File] for an asset.
Future<File?> assetAsFile(AssetEntity asset) => resolveAssetFile(asset);
