import 'dart:io';

import 'package:photo_manager/photo_manager.dart';

import '../core/constants.dart';
import '../core/log_service.dart';
import '../models/image_file.dart';

class LoadResult {
  final List<ImageFile> images;
  final int startIndex;
  const LoadResult({required this.images, required this.startIndex});
}

class GalleryService {
  /// Lists all supported images in [dirPath], sorted alphabetically.
  Future<List<ImageFile>> loadFolder(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        LogService.instance.warning('Directory not found: $dirPath');
        return [];
      }
      final entities = await dir.list().toList();
      final files = entities
          .whereType<File>()
          .map((f) => ImageFile(f.path))
          .toList();
      return sortImages(filterImages(files));
    } catch (e, st) {
      LogService.instance.error('loadFolder failed for $dirPath: $e', st);
      return [];
    }
  }

  /// Resolves a content:// or file:// URI and loads all images from
  /// the same parent directory.
  Future<LoadResult?> loadFromUri(Uri uri) async {
    try {
      String? filePath;

      if (uri.scheme == 'file') {
        filePath = uri.toFilePath();
      } else if (uri.scheme == 'content') {
        // Extract asset ID from content URI and resolve via photo_manager.
        final segments = uri.pathSegments;
        final idSegment = segments.isNotEmpty ? segments.last : null;
        if (idSegment != null) {
          final asset = await AssetEntity.fromId(idSegment);
          if (asset != null) {
            final f = await asset.originFile;
            filePath = f?.path;
          }
        }
      }

      if (filePath == null) {
        LogService.instance.warning('Could not resolve URI: $uri');
        return null;
      }

      final parentDir = File(filePath).parent.path;
      final images = await loadFolder(parentDir);
      final idx = images.indexWhere((img) => img.path == filePath);

      return LoadResult(
        images: images,
        startIndex: idx < 0 ? 0 : idx,
      );
    } catch (e, st) {
      LogService.instance.error('loadFromUri failed: $e', st);
      return null;
    }
  }

  /// Converts a SAF content URI to a real filesystem path.
  /// Returns the input unchanged if it is already a real path.
  /// Returns null if the URI format is not recognised.
  String? safUriToPath(String input) {
    if (input.startsWith('/')) return input;

    const prefix =
        'content://com.android.externalstorage.documents/tree/';
    if (input.startsWith(prefix)) {
      final encoded = input.substring(prefix.length);
      final decoded = Uri.decodeComponent(encoded);
      final colon = decoded.indexOf(':');
      if (colon > 0) {
        final volume = decoded.substring(0, colon);
        final rel = decoded.substring(colon + 1);
        if (volume == 'primary') {
          return '/storage/emulated/0/$rel';
        }
      }
    }
    return null;
  }

  /// Keeps only files with extensions in [kSupportedExtensions].
  List<ImageFile> filterImages(List<ImageFile> files) => files
      .where((f) => kSupportedExtensions.contains(f.extension))
      .toList();

  /// Sorts [files] alphabetically by filename (case-insensitive).
  List<ImageFile> sortImages(List<ImageFile> files) {
    final sorted = List<ImageFile>.from(files);
    sorted.sort((a, b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return sorted;
  }
}
