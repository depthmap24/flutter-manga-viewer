/// Compile-time constants for the app.
class AppConstants {
  AppConstants._();

  static const String githubOwner = 'depthmap24';
  static const String githubRepo = 'flutter-manga-viewer';

  static const List<String> supportedExtensions = [
    '.jpg',
    '.jpeg',
    '.png',
    '.svg',
    '.webp',
  ];

  /// Folders we scan by default on Android.
  static const List<String> defaultScanRoots = [
    '/storage/emulated/0/Pictures',
    '/storage/emulated/0/DCIM',
    '/storage/emulated/0/Download',
  ];
}
