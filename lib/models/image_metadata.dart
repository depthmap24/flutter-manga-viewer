class ImageMetadata {
  final int? width;
  final int? height;
  final String? colorSpace;
  final DateTime? dateTaken;
  final double? gpsLat;
  final double? gpsLon;

  const ImageMetadata({
    this.width,
    this.height,
    this.colorSpace,
    this.dateTaken,
    this.gpsLat,
    this.gpsLon,
  });

  String get resolution =>
      (width != null && height != null) ? '$width × $height px' : 'Unknown';

  bool get hasGps => gpsLat != null && gpsLon != null;

  String get gpsString => hasGps
      ? '${gpsLat!.toStringAsFixed(6)}, ${gpsLon!.toStringAsFixed(6)}'
      : 'Not available';
}
