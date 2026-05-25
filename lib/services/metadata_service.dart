import 'package:exif/exif.dart';

import '../core/log_service.dart';
import '../models/image_file.dart';
import '../models/image_metadata.dart';
import '../models/novel_ai_metadata.dart';
import 'png_metadata_service.dart';

class MetadataService {
  final _pngService = PngMetadataService();

  Future<ImageMetadata> getMetadata(ImageFile imageFile) async {
    try {
      final bytes = await imageFile.file.readAsBytes();
      final tags = await readExifFromBytes(bytes);

      final width = _parseInt(tags['Image ImageWidth'] ??
          tags['EXIF ExifImageWidth'] ??
          tags['Image ExifImageWidth']);
      final height = _parseInt(tags['Image ImageLength'] ??
          tags['EXIF ExifImageLength'] ??
          tags['Image ExifImageLength']);
      final colorSpace = tags['EXIF ColorSpace']?.toString();
      final dateStr = tags['EXIF DateTimeOriginal']?.toString() ??
          tags['Image DateTime']?.toString();
      final dateTaken = _parseDate(dateStr);
      final gpsLat = _parseGps(tags['GPS GPSLatitude'],
          tags['GPS GPSLatitudeRef']?.toString());
      final gpsLon = _parseGps(tags['GPS GPSLongitude'],
          tags['GPS GPSLongitudeRef']?.toString());

      return ImageMetadata(
        width: width,
        height: height,
        colorSpace: colorSpace,
        dateTaken: dateTaken,
        gpsLat: gpsLat,
        gpsLon: gpsLon,
      );
    } catch (e, st) {
      LogService.instance.warning(
          'MetadataService failed for ${imageFile.name}: $e', st);
      return const ImageMetadata();
    }
  }

  Future<NovelAiMetadata?> getNovelAi(ImageFile imageFile) async {
    if (!imageFile.path.toLowerCase().endsWith('.png')) return null;
    return _pngService.parse(imageFile.file);
  }

  int? _parseInt(IfdTag? tag) {
    if (tag == null) return null;
    return int.tryParse(tag.printable.replaceAll(RegExp(r'[^0-9]'), ''));
  }

  DateTime? _parseDate(String? s) {
    if (s == null) return null;
    try {
      final normalised = s.replaceFirst(':', '-').replaceFirst(':', '-');
      return DateTime.tryParse(normalised);
    } catch (_) {
      return null;
    }
  }

  double? _parseGps(IfdTag? coord, String? ref) {
    if (coord == null) return null;
    try {
      final parts = coord.values.toList();
      if (parts.length < 3) return null;
      final deg = _ratioToDouble(parts[0]);
      final min = _ratioToDouble(parts[1]);
      final sec = _ratioToDouble(parts[2]);
      double value = deg + min / 60 + sec / 3600;
      if (ref == 'S' || ref == 'W') value = -value;
      return value;
    } catch (_) {
      return null;
    }
  }

  double _ratioToDouble(dynamic r) {
    if (r is num) return r.toDouble();
    final s = r.toString();
    if (s.contains('/')) {
      final p = s.split('/');
      final num = double.tryParse(p[0]) ?? 0;
      final den = double.tryParse(p[1]) ?? 1;
      return den == 0 ? 0 : num / den;
    }
    return double.tryParse(s) ?? 0;
  }
}
