# Image Viewer

A Flutter Android image viewer with EXIF and NovelAI metadata parsing.

## Features
- Browse images from `Pictures`, `DCIM`, and `Download`
- PageView swiping with thumbnail strip
- Pinch-to-zoom and double-tap to zoom
- Material 3 (Material You) theming with system dark mode
- Edit (crop / rotate), share, delete
- EXIF metadata viewer
- NovelAI and Stable Diffusion (Automatic1111) prompt extraction from PNG `tEXt` / `iTXt` chunks
- Registers as a system default image viewer via `ACTION_VIEW` intent filters
- Self-updates from GitHub releases

## Install
Grab the latest APK from the [Releases](../../releases/latest) page.

## Build
```
flutter pub get
flutter build apk --release --target-platform android-arm64
```

Targets Flutter `stable` (3.44+), Dart 3.12+, Android compileSdk 36, minSdk 24.

## Permissions
- `READ_MEDIA_IMAGES` (Android 13+) / `READ_EXTERNAL_STORAGE` (older)
- `INTERNET` for the release-check API call
- `REQUEST_INSTALL_PACKAGES` for self-update install
