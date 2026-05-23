import 'package:photo_manager/photo_manager.dart';

/// MediaStore-backed image discovery. Replaces the old filesystem scanner.
/// Works on Android 11+ with only READ_MEDIA_IMAGES — no MANAGE_EXTERNAL_STORAGE
/// required, which is what Samsung Auto Blocker rejects.
class GalleryService {
  GalleryService._();

  /// Requests photo access; returns true once granted (full or limited).
  static Future<bool> requestPermission() async {
    final state = await PhotoManager.requestPermissionExtend();
    return state.isAuth || state.hasAccess;
  }

  /// Returns top-level image albums (Pictures, DCIM, Download, etc.).
  /// The platform decides which ones exist based on what's indexed.
  static Future<List<AssetPathEntity>> listAlbums() {
    return PhotoManager.getAssetPathList(
      type: RequestType.image,
      filterOption: FilterOptionGroup(
        orders: const [OrderOption(type: OrderOptionType.createDate, asc: false)],
      ),
    );
  }

  /// Loads up to [maxAssets] images from [album], newest first.
  static Future<List<AssetEntity>> imagesInAlbum(
    AssetPathEntity album, {
    int maxAssets = 5000,
  }) async {
    final total = await album.assetCountAsync;
    final count = total < maxAssets ? total : maxAssets;
    if (count == 0) return const [];
    return album.getAssetListRange(start: 0, end: count);
  }

  /// Tries to delete an asset via MediaStore. Returns true on success.
  static Future<bool> delete(AssetEntity asset) async {
    try {
      final result = await PhotoManager.editor.deleteWithIds([asset.id]);
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
