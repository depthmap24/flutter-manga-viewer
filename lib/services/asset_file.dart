import 'dart:io';

import 'package:photo_manager/photo_manager.dart';

/// Best-effort resolution of an [AssetEntity] to a [File]. Uses the original
/// file when accessible; falls back to a cached copy provided by the
/// platform. Returns null when the platform refuses to materialize it.
Future<File?> resolveAssetFile(AssetEntity asset) async {
  try {
    final original = await asset.originFile;
    if (original != null) return original;
  } catch (_) {/* fall through */}
  try {
    return await asset.file;
  } catch (_) {
    return null;
  }
}
