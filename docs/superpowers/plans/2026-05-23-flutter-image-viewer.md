# Flutter Image Viewer — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a complete Flutter Android image viewer with folder browsing, swipe navigation, pinch-to-zoom, NovelAI PNG prompt extraction, EXIF metadata display, crop/rotate editing, share/delete, file-manager intent support, and an in-app developer log console.

**Architecture:** Riverpod state management (`StateProvider` for folder path/index, `AsyncNotifierProvider` for image list). File scanning uses `dart:io` directly — simpler and ANR-free compared to photo_manager album queries. `photo_manager` is kept only for Android permission requests and MediaStore notifications. All async operations run off the main thread.

**Tech Stack:** Flutter 3.44.0 / Dart 3.12.0 / Android; `flutter_riverpod ^3.3.1`, `photo_manager ^3.9.0`, `flutter_svg ^2.3.0`, `crop_your_image ^2.0.0`, `exif ^3.3.0`, `image ^4.8.0`, `share_plus ^13.1.0`, `file_picker ^8.1.7`, `shared_preferences ^2.5.4`, `app_links ^7.0.0`, `permission_handler ^12.0.1`, `path_provider ^2.1.5`, `path ^1.9.1`

**Build command (ARM64 host):** `flutter build apk --release --target-platform android-arm64`

---

## File Map

```
lib/
  main.dart                          ← app entry, error hooks, intent routing
  core/
    constants.dart                   ← app-wide constants
    theme.dart                       ← Material light/dark theme
    log_service.dart                 ← LogService singleton + LogEntry
  models/
    image_file.dart                  ← ImageFile value type
    image_metadata.dart              ← ImageMetadata (EXIF)
    novel_ai_metadata.dart           ← NovelAiMetadata
  providers/
    providers.dart                   ← all Riverpod providers
  services/
    gallery_service.dart             ← dir scan, sort, SAF URI resolution
    metadata_service.dart            ← EXIF reader via exif package
    png_metadata_service.dart        ← PNG tEXt/iTXt chunk parser
    image_actions_service.dart       ← share, delete, saveEdit
  screens/
    home_screen.dart                 ← grid + overflow menu + folder picker
    viewer_screen.dart               ← PageView + action bar
    edit_screen.dart                 ← crop/rotate
    log_screen.dart                  ← developer log console
    metadata_sheet.dart              ← bottom sheet (not a full screen)
  widgets/
    image_page.dart                  ← single page: InteractiveViewer + image
    thumbnail_strip.dart             ← bottom scrollable thumb row
android/app/src/main/
  AndroidManifest.xml                ← modify: permissions + intent filter
  kotlin/com/depthmap24/imageviewer/
    Application.kt                   ← new: FlutterEngine pre-warm
    MainActivity.kt                  ← modify: use cached engine
test/
  services/
    png_metadata_service_test.dart
    gallery_service_test.dart
    log_service_test.dart
```

---

### Task 1: Reset the project

**Files:** Delete `/home/ubuntu/flutter-manga-viewer`, recreate with `flutter create`

- [ ] **Step 1: Back up docs and plan**

```bash
cp -r /home/ubuntu/flutter-manga-viewer/docs /tmp/viewer_docs
```

- [ ] **Step 2: Delete the existing project**

```bash
rm -rf /home/ubuntu/flutter-manga-viewer
```

- [ ] **Step 3: Create a brand-new Flutter project**

`--org com.depthmap24` sets the Android package prefix. `--project-name imageviewer` names the app. `--platforms android` skips iOS/web/desktop stubs.

```bash
cd /home/ubuntu
flutter create --org com.depthmap24 --project-name imageviewer --platforms android flutter-manga-viewer
```

Expected last line: `All done! Your project is ready at /home/ubuntu/flutter-manga-viewer`

- [ ] **Step 4: Restore the docs folder**

```bash
cp -r /tmp/viewer_docs /home/ubuntu/flutter-manga-viewer/docs
```

- [ ] **Step 5: Set up git and force-push to GitHub**

This replaces the GitHub repo history with a single clean commit.

```bash
cd /home/ubuntu/flutter-manga-viewer
git init -b main
git remote add origin https://github.com/depthmap24/flutter-manga-viewer.git
git add -A
git commit -m "chore: fresh Flutter project — image viewer v2"
git push --force origin main
```

If the push fails with authentication error, run `gh auth login` first, then retry the push.

- [ ] **Step 6: Verify the clean project builds**

This confirms the ARM64 build environment is still working before we write any code.

```bash
cd /home/ubuntu/flutter-manga-viewer
flutter build apk --release --target-platform android-arm64 2>&1 | tail -5
```

Expected: `✓ Built build/app/outputs/flutter-apk/app-release.apk`

**If this fails:** Do NOT proceed. The ARM64 environment may need reconfiguring (see the ARM64 setup memory notes: box64 v0.4.2 as binfmt handler, cmake/ninja symlinked to native arm64 binaries in the Android SDK).

- [ ] **Step 7: Commit**

```bash
cd /home/ubuntu/flutter-manga-viewer
git add -A
git commit -m "chore: confirm clean build"
git push origin main
```

---

### Task 2: Update pubspec.yaml

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Replace pubspec.yaml with the exact content below**

`pubspec.yaml` is the Flutter equivalent of `package.json` — it lists all dependencies. Replace the entire file:

```yaml
name: imageviewer
description: "Image viewer with gallery, swipe, zoom, NovelAI metadata, and developer logs"
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.12.0

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  flutter_riverpod: ^3.3.1
  photo_manager: ^3.9.0
  flutter_svg: ^2.3.0
  share_plus: ^13.1.0
  permission_handler: ^12.0.1
  path_provider: ^2.1.5
  path: ^1.9.1
  exif: ^3.3.0
  image: ^4.8.0
  crop_your_image: ^2.0.0
  app_links: ^7.0.0
  shared_preferences: ^2.5.4
  file_picker: ^8.1.7

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true
```

- [ ] **Step 2: Install dependencies**

```bash
cd /home/ubuntu/flutter-manga-viewer
flutter pub get
```

Expected: `Got dependencies!` with no errors.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add all dependencies"
git push origin main
```

---

### Task 3: Android configuration

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Create: `android/app/src/main/kotlin/com/depthmap24/imageviewer/Application.kt`
- Modify: `android/app/src/main/kotlin/com/depthmap24/imageviewer/MainActivity.kt`
- Modify: `android/app/build.gradle`

**What these files are:**
- `AndroidManifest.xml` — tells Android what permissions the app needs and what file types it can open
- `Application.kt` — Kotlin code that runs when the app process starts; we use it to pre-load the Flutter engine to prevent "Application Not Responding" (ANR) freezes
- `MainActivity.kt` — the main Android activity; we tell it to use the pre-loaded engine
- `build.gradle` — Android build configuration; we set minimum/target Android API levels

- [ ] **Step 1: Replace AndroidManifest.xml**

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- Permissions: Android 13+ (API 33+) uses READ_MEDIA_IMAGES instead of READ_EXTERNAL_STORAGE -->
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
    <uses-permission
        android:name="android.permission.READ_EXTERNAL_STORAGE"
        android:maxSdkVersion="32" />
    <!-- WRITE needed only on Android 9 and below for delete/save-edit -->
    <uses-permission
        android:name="android.permission.WRITE_EXTERNAL_STORAGE"
        android:maxSdkVersion="28" />
    <!-- Allows reading GPS coordinates embedded in image EXIF data -->
    <uses-permission android:name="android.permission.ACCESS_MEDIA_LOCATION" />

    <application
        android:name=".Application"
        android:label="Image Viewer"
        android:icon="@mipmap/ic_launcher"
        android:requestLegacyExternalStorage="true">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">

            <meta-data
                android:name="io.flutter.embedding.android.NormalTheme"
                android:resource="@style/NormalTheme" />

            <!-- Normal launcher entry point -->
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>

            <!-- "Open with..." entry point from any file manager -->
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="image/*" />
            </intent-filter>

        </activity>

        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />

    </application>
</manifest>
```

- [ ] **Step 2: Create Application.kt**

This file pre-loads the Flutter engine when the app process starts. Without this, the first screen can freeze for several seconds (ANR).

```kotlin
package com.depthmap24.imageviewer

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

class Application : Application() {

    companion object {
        const val ENGINE_ID = "pre_warmed_engine"
    }

    override fun onCreate() {
        super.onCreate()
        val engine = FlutterEngine(this)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
    }
}
```

- [ ] **Step 3: Replace MainActivity.kt**

```kotlin
package com.depthmap24.imageviewer

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun getCachedEngineId(): String = Application.ENGINE_ID
}
```

- [ ] **Step 4: Update android/app/build.gradle — set minSdk to 21**

Open `android/app/build.gradle`. Find the `defaultConfig` block and update `minSdkVersion` to 21 (Android 5.0, required by `photo_manager`):

```groovy
defaultConfig {
    applicationId "com.depthmap24.imageviewer"
    minSdkVersion 21
    targetSdkVersion flutter.targetSdkVersion
    versionCode flutterVersionCode.toInteger()
    versionName flutterVersionName
}
```

- [ ] **Step 5: Verify the build still passes**

```bash
cd /home/ubuntu/flutter-manga-viewer
flutter build apk --release --target-platform android-arm64 2>&1 | tail -5
```

Expected: `✓ Built build/app/outputs/flutter-apk/app-release.apk`

- [ ] **Step 6: Commit**

```bash
git add android/
git commit -m "feat(android): permissions, intent filter, engine pre-warm"
git push origin main
```

---

### Task 4: Core — constants and theme

**Files:**
- Create: `lib/core/constants.dart`
- Create: `lib/core/theme.dart`
- Delete: `lib/main.dart` content (will be replaced in Task 19)

- [ ] **Step 1: Create lib/core/constants.dart**

```dart
const kSupportedExtensions = {'.jpg', '.jpeg', '.png', '.svg', '.webp'};
const kLogMaxEntries = 500;
const kLogMaxFileBytes = 2 * 1024 * 1024; // 2 MB
const kThumbnailSize = 120.0;
const kFolderPathKey = 'selected_folder_path';
const kEngineId = 'pre_warmed_engine';
```

- [ ] **Step 2: Create lib/core/theme.dart**

```dart
import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      );

  static ThemeData dark() => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      );
}
```

- [ ] **Step 3: Replace lib/main.dart with a placeholder so the project compiles**

We will rewrite this in Task 19. For now it just needs to compile:

```dart
import 'package:flutter/material.dart';
import 'core/theme.dart';

void main() => runApp(const _Placeholder());

class _Placeholder extends StatelessWidget {
  const _Placeholder();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const Scaffold(body: Center(child: Text('Building...'))),
    );
  }
}
```

- [ ] **Step 4: Run flutter analyze to check for errors**

```bash
cd /home/ubuntu/flutter-manga-viewer
flutter analyze lib/core/
```

Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/
git commit -m "feat: core constants and theme"
git push origin main
```

---

### Task 5: LogService

**Files:**
- Create: `lib/core/log_service.dart`
- Create: `test/services/log_service_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/services/log_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:imageviewer/core/log_service.dart';

void main() {
  group('LogService', () {
    setUp(() => LogService.instance.clearForTest());

    test('records info entries', () {
      LogService.instance.info('hello');
      expect(LogService.instance.entries.last.message, 'hello');
      expect(LogService.instance.entries.last.level, LogLevel.info);
    });

    test('records warning entries', () {
      LogService.instance.warning('warn msg');
      expect(LogService.instance.entries.last.level, LogLevel.warning);
    });

    test('records error entries with stack trace', () {
      final st = StackTrace.current;
      LogService.instance.error('oops', st);
      final entry = LogService.instance.entries.last;
      expect(entry.level, LogLevel.error);
      expect(entry.stackTrace, st);
    });

    test('caps in-memory entries at kLogMaxEntries', () {
      for (int i = 0; i < 520; i++) {
        LogService.instance.info('entry $i');
      }
      expect(LogService.instance.entries.length, lessThanOrEqualTo(500));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /home/ubuntu/flutter-manga-viewer
flutter test test/services/log_service_test.dart 2>&1 | tail -10
```

Expected: compile error — `log_service.dart` does not exist yet.

- [ ] **Step 3: Create lib/core/log_service.dart**

```dart
import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'constants.dart';

enum LogLevel { info, warning, error }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final StackTrace? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.stackTrace,
  });

  @override
  String toString() {
    final ts = timestamp.toIso8601String();
    final lvl = level.name.toUpperCase().padRight(7);
    final stack = stackTrace != null ? '\n$stackTrace' : '';
    return '[$ts] $lvl $message$stack';
  }
}

class LogService {
  LogService._();
  static final instance = LogService._();

  final _entries = <LogEntry>[];
  File? _logFile;
  bool _initialized = false;

  List<LogEntry> get entries => List.unmodifiable(_entries);

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${dir.path}/logs');
      await logsDir.create(recursive: true);
      _logFile = File('${logsDir.path}/app.log');
      await _rotate();
    } catch (_) {
      // If log file setup fails, in-memory logging still works.
    }
  }

  String get logFilePath => _logFile?.path ?? '(not initialized)';

  void info(Object message, [StackTrace? st]) =>
      _record(LogLevel.info, message, st);

  void warning(Object message, [StackTrace? st]) =>
      _record(LogLevel.warning, message, st);

  void error(Object message, [StackTrace? st]) =>
      _record(LogLevel.error, message, st);

  void _record(LogLevel level, Object message, StackTrace? st) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message.toString(),
      stackTrace: st,
    );
    if (_entries.length >= kLogMaxEntries) {
      _entries.removeAt(0);
    }
    _entries.add(entry);
    _writeToFile(entry);
  }

  void _writeToFile(LogEntry entry) {
    final file = _logFile;
    if (file == null) return;
    try {
      file.writeAsStringSync('${entry}\n', mode: FileMode.append);
    } catch (_) {}
  }

  Future<void> _rotate() async {
    final file = _logFile;
    if (file == null || !await file.exists()) return;
    final size = await file.length();
    if (size > kLogMaxFileBytes) {
      await file.writeAsString('');
    }
  }

  void clear() {
    _entries.clear();
    _logFile?.writeAsStringSync('');
  }

  // Only for tests — resets state without touching the filesystem.
  void clearForTest() => _entries.clear();
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/services/log_service_test.dart 2>&1 | tail -10
```

Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/core/log_service.dart test/services/log_service_test.dart
git commit -m "feat: LogService with file output and in-memory cap"
git push origin main
```

---

### Task 6: Models

**Files:**
- Create: `lib/models/image_file.dart`
- Create: `lib/models/image_metadata.dart`
- Create: `lib/models/novel_ai_metadata.dart`

- [ ] **Step 1: Create lib/models/image_file.dart**

```dart
import 'dart:io';

class ImageFile {
  final String path;

  const ImageFile(this.path);

  String get name => path.split('/').last;

  String get extension {
    final n = name;
    final dot = n.lastIndexOf('.');
    if (dot < 0) return '';
    return n.substring(dot).toLowerCase();
  }

  File get file => File(path);

  bool get isSvg => extension == '.svg';

  @override
  bool operator ==(Object other) => other is ImageFile && other.path == path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'ImageFile($name)';
}
```

- [ ] **Step 2: Create lib/models/image_metadata.dart**

```dart
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
```

- [ ] **Step 3: Create lib/models/novel_ai_metadata.dart**

```dart
class NovelAiMetadata {
  final String? prompt;
  final String? negativePrompt;
  final int? steps;
  final String? sampler;
  final int? seed;
  final double? cfgScale;
  final String? imageSize;

  const NovelAiMetadata({
    this.prompt,
    this.negativePrompt,
    this.steps,
    this.sampler,
    this.seed,
    this.cfgScale,
    this.imageSize,
  });
}
```

- [ ] **Step 4: Run flutter analyze**

```bash
flutter analyze lib/models/
```

Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/models/
git commit -m "feat: ImageFile, ImageMetadata, NovelAiMetadata models"
git push origin main
```

---

### Task 7: PngMetadataService (NovelAI parser) + tests

**Files:**
- Create: `lib/services/png_metadata_service.dart`
- Create: `test/services/png_metadata_service_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/services/png_metadata_service_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imageviewer/services/png_metadata_service.dart';

/// Builds a minimal valid PNG byte sequence with tEXt chunks.
/// Our parser does not verify CRC, so we use zero CRCs for simplicity.
Uint8List buildTestPng(Map<String, String> textChunks) {
  final buf = BytesBuilder();
  // PNG signature
  buf.add([137, 80, 78, 71, 13, 10, 26, 10]);
  // Minimal IHDR (width=1, height=1, bitDepth=8, colorType=2 RGB)
  final ihdr = Uint8List(13)
    ..[3] = 1
    ..[7] = 1
    ..[8] = 8
    ..[9] = 2;
  buf.add(_makeChunk('IHDR', ihdr));
  for (final e in textChunks.entries) {
    final data = Uint8List.fromList([
      ...utf8.encode(e.key),
      0,
      ...latin1.encode(e.value),
    ]);
    buf.add(_makeChunk('tEXt', data));
  }
  buf.add(_makeChunk('IEND', Uint8List(0)));
  return buf.toBytes();
}

Uint8List _makeChunk(String type, Uint8List data) {
  final b = BytesBuilder();
  b.addByte((data.length >> 24) & 0xFF);
  b.addByte((data.length >> 16) & 0xFF);
  b.addByte((data.length >> 8) & 0xFF);
  b.addByte(data.length & 0xFF);
  b.add(utf8.encode(type));
  b.add(data);
  b.add([0, 0, 0, 0]); // fake CRC
  return b.toBytes();
}

void main() {
  final svc = PngMetadataService();

  group('PngMetadataService', () {
    test('returns null for non-PNG bytes', () {
      final bytes = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7]);
      expect(svc.parseBytes(bytes), isNull);
    });

    test('returns null for PNG with no NovelAI chunks', () {
      final bytes = buildTestPng({'Software': 'GIMP'});
      expect(svc.parseBytes(bytes), isNull);
    });

    test('parses prompt from "parameters" tEXt chunk', () {
      final bytes = buildTestPng({'parameters': 'a cat, masterpiece'});
      final meta = svc.parseBytes(bytes);
      expect(meta, isNotNull);
      expect(meta!.prompt, 'a cat, masterpiece');
    });

    test('parses prompt from "Description" tEXt chunk', () {
      final bytes = buildTestPng({'Description': 'a dog'});
      final meta = svc.parseBytes(bytes);
      expect(meta!.prompt, 'a dog');
    });

    test('parses negativePrompt, steps, sampler, seed from "Comment" JSON', () {
      final comment = jsonEncode({
        'prompt': 'a fox',
        'uc': 'blurry, bad',
        'steps': 28,
        'sampler': 'k_euler',
        'seed': 12345,
        'scale': 7.0,
        'image_size': '512x768',
      });
      final bytes = buildTestPng({'Comment': comment});
      final meta = svc.parseBytes(bytes);
      expect(meta!.prompt, 'a fox');
      expect(meta.negativePrompt, 'blurry, bad');
      expect(meta.steps, 28);
      expect(meta.sampler, 'k_euler');
      expect(meta.seed, 12345);
      expect(meta.cfgScale, 7.0);
      expect(meta.imageSize, '512x768');
    });

    test('"parameters" key takes priority over "Description"', () {
      final bytes = buildTestPng({
        'parameters': 'primary prompt',
        'Description': 'secondary',
      });
      final meta = svc.parseBytes(bytes);
      expect(meta!.prompt, 'primary prompt');
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
flutter test test/services/png_metadata_service_test.dart 2>&1 | tail -5
```

Expected: compile error — `png_metadata_service.dart` does not exist.

- [ ] **Step 3: Create lib/services/png_metadata_service.dart**

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../core/log_service.dart';
import '../models/novel_ai_metadata.dart';

class PngMetadataService {
  static const _sig = [137, 80, 78, 71, 13, 10, 26, 10];

  Future<NovelAiMetadata?> parse(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return parseBytes(bytes);
    } catch (e, st) {
      LogService.instance.warning('PNG parse failed for ${file.path}: $e', st);
      return null;
    }
  }

  /// Exposed for unit tests (no file I/O).
  NovelAiMetadata? parseBytes(Uint8List bytes) {
    if (bytes.length < 8) return null;
    for (int i = 0; i < 8; i++) {
      if (bytes[i] != _sig[i]) return null;
    }

    final chunks = <String, String>{};
    int offset = 8;

    while (offset + 12 <= bytes.length) {
      final length = _u32(bytes, offset);
      final type = String.fromCharCodes(bytes.sublist(offset + 4, offset + 8));
      final dataEnd = offset + 8 + length;
      if (dataEnd + 4 > bytes.length) break;

      if (type == 'tEXt') {
        _parseTExt(bytes.sublist(offset + 8, dataEnd), chunks);
      } else if (type == 'iTXt') {
        _parseITxt(bytes.sublist(offset + 8, dataEnd), chunks);
      }

      offset = dataEnd + 4; // skip 4-byte CRC
    }

    return _build(chunks);
  }

  void _parseTExt(Uint8List data, Map<String, String> out) {
    final nullIdx = data.indexOf(0);
    if (nullIdx <= 0) return;
    final key = utf8.decode(data.sublist(0, nullIdx), allowMalformed: true);
    final value =
        latin1.decode(data.sublist(nullIdx + 1), allowInvalid: true);
    out[key] = value;
  }

  void _parseITxt(Uint8List data, Map<String, String> out) {
    try {
      int pos = 0;
      final nullIdx = data.indexOf(0, pos);
      if (nullIdx < 0) return;
      final key = utf8.decode(data.sublist(pos, nullIdx), allowMalformed: true);
      pos = nullIdx + 1;
      if (pos >= data.length) return;
      final compressionFlag = data[pos++];
      pos++; // compression method
      // skip language tag
      final langEnd = data.indexOf(0, pos);
      if (langEnd < 0) return;
      pos = langEnd + 1;
      // skip translated keyword
      final transEnd = data.indexOf(0, pos);
      if (transEnd < 0) return;
      pos = transEnd + 1;
      if (pos >= data.length) return;

      final raw = data.sublist(pos);
      final value = compressionFlag == 1
          ? utf8.decode(zlib.decode(raw), allowMalformed: true)
          : utf8.decode(raw, allowMalformed: true);
      out[key] = value;
    } catch (_) {}
  }

  NovelAiMetadata? _build(Map<String, String> chunks) {
    String? prompt;
    String? negativePrompt;
    int? steps;
    String? sampler;
    int? seed;
    double? cfgScale;
    String? imageSize;

    prompt = chunks['parameters'] ?? chunks['Description'];

    if (chunks.containsKey('Comment')) {
      try {
        final json = jsonDecode(chunks['Comment']!) as Map<String, dynamic>;
        prompt ??= json['prompt'] as String?;
        negativePrompt = json['uc'] as String?;
        steps = json['steps'] as int?;
        sampler = json['sampler'] as String?;
        seed = (json['seed'] as num?)?.toInt();
        cfgScale = (json['scale'] as num?)?.toDouble();
        imageSize = json['image_size'] as String?;
      } catch (_) {}
    }

    if (prompt == null) return null;

    return NovelAiMetadata(
      prompt: prompt,
      negativePrompt: negativePrompt,
      steps: steps,
      sampler: sampler,
      seed: seed,
      cfgScale: cfgScale,
      imageSize: imageSize,
    );
  }

  int _u32(Uint8List b, int o) =>
      (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/services/png_metadata_service_test.dart 2>&1 | tail -5
```

Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/services/png_metadata_service.dart test/services/png_metadata_service_test.dart
git commit -m "feat: PngMetadataService — NovelAI tEXt/iTXt chunk parser"
git push origin main
```

---

### Task 8: GalleryService + tests

**Files:**
- Create: `lib/services/gallery_service.dart`
- Create: `test/services/gallery_service_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/services/gallery_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:imageviewer/models/image_file.dart';
import 'package:imageviewer/services/gallery_service.dart';

void main() {
  final svc = GalleryService();

  group('GalleryService.filterImages', () {
    test('keeps only supported extensions', () {
      final files = [
        ImageFile('/a/photo.jpg'),
        ImageFile('/a/doc.pdf'),
        ImageFile('/a/image.PNG'),  // uppercase extension
        ImageFile('/a/video.mp4'),
        ImageFile('/a/icon.svg'),
        ImageFile('/a/anim.webp'),
      ];
      final result = svc.filterImages(files);
      final names = result.map((f) => f.name).toList();
      expect(names, containsAll(['photo.jpg', 'image.PNG', 'icon.svg', 'anim.webp']));
      expect(names, isNot(contains('doc.pdf')));
      expect(names, isNot(contains('video.mp4')));
    });
  });

  group('GalleryService.sortImages', () {
    test('returns files in case-insensitive alphabetical order', () {
      final files = [
        ImageFile('/a/Zebra.jpg'),
        ImageFile('/a/apple.png'),
        ImageFile('/a/Mango.webp'),
      ];
      final sorted = svc.sortImages(files);
      expect(sorted.map((f) => f.name).toList(),
          ['apple.png', 'Mango.webp', 'Zebra.jpg']);
    });
  });

  group('GalleryService.safUriToPath', () {
    test('passes through a real /storage/... path unchanged', () {
      const p = '/storage/emulated/0/Pictures/NovelAI';
      expect(svc.safUriToPath(p), p);
    });

    test('converts primary SAF URI to real path', () {
      const uri =
          'content://com.android.externalstorage.documents/tree/primary%3APictures%2FNovelAI';
      expect(
          svc.safUriToPath(uri), '/storage/emulated/0/Pictures/NovelAI');
    });

    test('returns null for unrecognised URI scheme', () {
      expect(svc.safUriToPath('ftp://something'), isNull);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
flutter test test/services/gallery_service_test.dart 2>&1 | tail -5
```

Expected: compile error — `gallery_service.dart` does not exist yet.

- [ ] **Step 3: Create lib/services/gallery_service.dart**

```dart
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
  /// the same parent directory, returning the list + index of the tapped file.
  Future<LoadResult?> loadFromUri(Uri uri) async {
    try {
      String? filePath;

      if (uri.scheme == 'file') {
        filePath = uri.toFilePath();
      } else if (uri.scheme == 'content') {
        // Use photo_manager to resolve content:// URI to a real file path.
        final asset = await PhotoManager.getAssetFromUri(uri);
        if (asset != null) {
          final f = await asset.originFile;
          filePath = f?.path;
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

  /// Converts a SAF (Storage Access Framework) content URI to a real file
  /// system path. Returns the input unchanged if it is already a real path.
  /// Returns null if the URI format is not recognised.
  String? safUriToPath(String input) {
    if (input.startsWith('/')) return input;

    const prefix =
        'content://com.android.externalstorage.documents/tree/';
    if (input.startsWith(prefix)) {
      final encoded = input.substring(prefix.length);
      final decoded = Uri.decodeComponent(encoded);
      // Format: "primary:Pictures/NovelAI"
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
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/services/gallery_service_test.dart 2>&1 | tail -5
```

Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/services/gallery_service.dart test/services/gallery_service_test.dart
git commit -m "feat: GalleryService — dir scan, filter, sort, SAF URI resolution"
git push origin main
```

---

### Task 9: MetadataService

**Files:**
- Create: `lib/services/metadata_service.dart`

(Unit testing this service requires real image files with EXIF data, which is impractical in a unit test. We skip dedicated tests and rely on LogScreen to surface any issues at runtime.)

- [ ] **Step 1: Create lib/services/metadata_service.dart**

```dart
import 'dart:typed_data';

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
      // EXIF format: "2024:06:15 12:30:00"
      final normalised = s.replaceFirst(':', '-').replaceFirst(':', '-');
      return DateTime.tryParse(normalised);
    } catch (_) {
      return null;
    }
  }

  double? _parseGps(IfdTag? coord, String? ref) {
    if (coord == null) return null;
    try {
      // coord.values is a list of [degrees, minutes, seconds] as Ratio objects
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
    // The exif package returns Ratio objects with numerator and denominator.
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
```

- [ ] **Step 2: Run flutter analyze**

```bash
flutter analyze lib/services/metadata_service.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/services/metadata_service.dart
git commit -m "feat: MetadataService — EXIF reader wrapping exif package"
git push origin main
```

---

### Task 10: ImageActionsService

**Files:**
- Create: `lib/services/image_actions_service.dart`

- [ ] **Step 1: Create lib/services/image_actions_service.dart**

```dart
import 'dart:io';
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

  /// Deletes the file from disk and notifies Android's MediaStore so the
  /// file disappears from other apps immediately.
  Future<void> delete(ImageFile imageFile) async {
    try {
      final file = imageFile.file;
      if (await file.exists()) {
        await file.delete();
      }
      // Notify Android MediaStore to remove the stale entry.
      await PhotoManager.editor.android.removeAllNoExistsAsset();
      LogService.instance.info('Deleted: ${imageFile.name}');
    } catch (e, st) {
      LogService.instance.error('Delete failed for ${imageFile.name}: $e', st);
      rethrow;
    }
  }

  /// Saves [croppedBytes] (result of crop_your_image) back to the original
  /// file. Preserves the original file extension/format.
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

  /// Rotates the image at [imageFile] by [degrees] (must be 90 or -90)
  /// and returns the rotated bytes. Does not write to disk.
  Future<Uint8List> rotateImage(ImageFile imageFile, int degrees) async {
    final bytes = await imageFile.file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Could not decode image for rotation');
    }
    final rotated = img.copyRotate(decoded, angle: degrees);
    // Re-encode in the same format.
    if (imageFile.extension == '.png') {
      return Uint8List.fromList(img.encodePng(rotated));
    }
    return Uint8List.fromList(img.encodeJpg(rotated, quality: 92));
  }
}
```

- [ ] **Step 2: Run flutter analyze**

```bash
flutter analyze lib/services/image_actions_service.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/services/image_actions_service.dart
git commit -m "feat: ImageActionsService — share, delete, saveEdit, rotateImage"
git push origin main
```

---

### Task 11: Providers

**Files:**
- Create: `lib/providers/providers.dart`

- [ ] **Step 1: Create lib/providers/providers.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../core/log_service.dart';
import '../models/image_file.dart';
import '../services/gallery_service.dart';

// ── Folder path ──────────────────────────────────────────────────────────────

/// The absolute path to the currently selected folder, or null if not chosen.
/// Persisted to SharedPreferences across app restarts.
final folderPathProvider = StateProvider<String?>((ref) => null);

// ── Gallery ───────────────────────────────────────────────────────────────────

class GalleryNotifier extends AsyncNotifier<List<ImageFile>> {
  final _svc = GalleryService();

  @override
  Future<List<ImageFile>> build() async {
    final path = ref.watch(folderPathProvider);
    if (path == null) return [];
    LogService.instance.info('Loading gallery from: $path');
    return _svc.loadFolder(path);
  }

  void reload() => ref.invalidateSelf();
}

final galleryProvider =
    AsyncNotifierProvider<GalleryNotifier, List<ImageFile>>(
        GalleryNotifier.new);

// ── Current image index ───────────────────────────────────────────────────────

final currentIndexProvider = StateProvider<int>((ref) => 0);

// ── Log entries ───────────────────────────────────────────────────────────────

final logProvider = Provider<List<LogEntry>>((ref) {
  // This is a simple synchronous snapshot — the LogScreen rebuilds by
  // calling ref.refresh(logProvider) after each log action.
  return LogService.instance.entries;
});

// ── SharedPreferences ─────────────────────────────────────────────────────────

final sharedPrefsProvider = FutureProvider<SharedPreferences>(
  (_) => SharedPreferences.getInstance(),
);

/// Loads the persisted folder path and writes it into folderPathProvider.
/// Call this once at app start.
Future<void> initFolderPath(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(kFolderPathKey);
  if (saved != null) {
    ref.read(folderPathProvider.notifier).state = saved;
  }
}

/// Saves [path] to SharedPreferences and updates folderPathProvider.
Future<void> setFolderPath(WidgetRef ref, String path) async {
  ref.read(folderPathProvider.notifier).state = path;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kFolderPathKey, path);
  LogService.instance.info('Folder path saved: $path');
}
```

- [ ] **Step 2: Run flutter analyze**

```bash
flutter analyze lib/providers/
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/providers/
git commit -m "feat: Riverpod providers — gallery, folder path, index, log"
git push origin main
```

---

### Task 12: ImagePage widget

**Files:**
- Create: `lib/widgets/image_page.dart`

- [ ] **Step 1: Create lib/widgets/image_page.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/image_file.dart';

/// A single page in the ViewerScreen PageView.
/// Wraps the image in InteractiveViewer for pinch-to-zoom.
/// Resets zoom when [resetKey] changes (driven by page changes).
class ImagePage extends StatelessWidget {
  final ImageFile imageFile;
  final TransformationController transformationController;

  const ImagePage({
    super.key,
    required this.imageFile,
    required this.transformationController,
  });

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: transformationController,
      minScale: 1.0,
      maxScale: 5.0,
      child: Center(child: _buildImage()),
    );
  }

  Widget _buildImage() {
    if (imageFile.isSvg) {
      return SvgPicture.file(
        imageFile.file,
        fit: BoxFit.contain,
        placeholderBuilder: (_) =>
            const CircularProgressIndicator(),
      );
    }
    return Image.file(
      imageFile.file,
      fit: BoxFit.contain,
      errorBuilder: (_, error, __) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image, color: Colors.white54, size: 64),
          const SizedBox(height: 8),
          Text(
            imageFile.name,
            style: const TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Run flutter analyze**

```bash
flutter analyze lib/widgets/image_page.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/image_page.dart
git commit -m "feat: ImagePage widget — InteractiveViewer with SVG support"
git push origin main
```

---

### Task 13: ThumbnailStrip widget

**Files:**
- Create: `lib/widgets/thumbnail_strip.dart`

- [ ] **Step 1: Create lib/widgets/thumbnail_strip.dart**

```dart
import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../models/image_file.dart';

class ThumbnailStrip extends StatefulWidget {
  final List<ImageFile> images;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const ThumbnailStrip({
    super.key,
    required this.images,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<ThumbnailStrip> createState() => _ThumbnailStripState();
}

class _ThumbnailStripState extends State<ThumbnailStrip> {
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController();
  }

  @override
  void didUpdateWidget(ThumbnailStrip old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _scrollToIndex(widget.currentIndex);
    }
  }

  void _scrollToIndex(int index) {
    final itemWidth = kThumbnailSize + 4; // thumb + horizontal padding
    final target = index * itemWidth -
        (MediaQuery.sizeOf(context).width / 2) +
        itemWidth / 2;
    _scroll.animateTo(
      target.clamp(0.0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kThumbnailSize + 12,
      child: ListView.builder(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        itemCount: widget.images.length,
        itemBuilder: (context, index) {
          final isActive = index == widget.currentIndex;
          final img = widget.images[index];
          return GestureDetector(
            onTap: () => widget.onTap(index),
            child: Container(
              width: kThumbnailSize,
              height: kThumbnailSize,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isActive ? Colors.white : Colors.transparent,
                  width: 2,
                ),
              ),
              child: img.isSvg
                  ? const Icon(Icons.image, color: Colors.white54)
                  : Image.file(
                      img.file,
                      width: kThumbnailSize,
                      height: kThumbnailSize,
                      fit: BoxFit.cover,
                      cacheWidth: (kThumbnailSize * 2).toInt(),
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image, color: Colors.white54),
                    ),
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 2: Run flutter analyze**

```bash
flutter analyze lib/widgets/thumbnail_strip.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/thumbnail_strip.dart
git commit -m "feat: ThumbnailStrip — scrollable thumb bar with active highlight"
git push origin main
```

---

### Task 14: MetadataSheet

**Files:**
- Create: `lib/screens/metadata_sheet.dart`

- [ ] **Step 1: Create lib/screens/metadata_sheet.dart**

```dart
import 'package:flutter/material.dart';

import '../models/image_file.dart';
import '../models/image_metadata.dart';
import '../models/novel_ai_metadata.dart';
import '../services/metadata_service.dart';

class MetadataSheet extends StatefulWidget {
  final ImageFile imageFile;

  const MetadataSheet({super.key, required this.imageFile});

  static Future<void> show(BuildContext context, ImageFile imageFile) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MetadataSheet(imageFile: imageFile),
    );
  }

  @override
  State<MetadataSheet> createState() => _MetadataSheetState();
}

class _MetadataSheetState extends State<MetadataSheet> {
  final _svc = MetadataService();
  ImageMetadata? _meta;
  NovelAiMetadata? _ai;
  bool _loading = true;
  bool _aiExpanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final meta = await _svc.getMetadata(widget.imageFile);
    final ai = await _svc.getNovelAi(widget.imageFile);
    if (mounted) {
      setState(() {
        _meta = meta;
        _ai = ai;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      maxChildSize: 0.92,
      minChildSize: 0.3,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildContent(controller),
      ),
    );
  }

  Widget _buildContent(ScrollController controller) {
    final meta = _meta!;
    return ListView(
      controller: controller,
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(widget.imageFile.name,
            style: Theme.of(context).textTheme.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        const Divider(height: 24),
        _row('Resolution', meta.resolution),
        _row('Color space', meta.colorSpace ?? 'Unknown'),
        _row(
          'Date taken',
          meta.dateTaken != null
              ? '${meta.dateTaken!.toLocal()}'.split('.').first
              : 'Unknown',
        ),
        _row('GPS', meta.gpsString),
        if (_ai != null) ...[
          const Divider(height: 24),
          InkWell(
            onTap: () => setState(() => _aiExpanded = !_aiExpanded),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                    child: Text('AI Generation',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                Icon(_aiExpanded
                    ? Icons.expand_less
                    : Icons.expand_more),
              ],
            ),
          ),
          if (_aiExpanded) ...[
            const SizedBox(height: 12),
            _aiSection(),
          ],
        ],
      ],
    );
  }

  Widget _aiSection() {
    final ai = _ai!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ai.prompt != null) ...[
          const Text('Prompt',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          SelectableText(ai.prompt!,
              style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
        ],
        if (ai.negativePrompt != null) ...[
          const Text('Negative Prompt',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          SelectableText(ai.negativePrompt!,
              style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (ai.steps != null) _chip('Steps: ${ai.steps}'),
            if (ai.sampler != null) _chip('Sampler: ${ai.sampler}'),
            if (ai.seed != null) _chip('Seed: ${ai.seed}'),
            if (ai.cfgScale != null) _chip('CFG: ${ai.cfgScale}'),
            if (ai.imageSize != null) _chip('Size: ${ai.imageSize}'),
          ],
        ),
      ],
    );
  }

  Widget _chip(String label) => Chip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 13)),
            ),
            Expanded(
              child: Text(value, style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
      );
}
```

- [ ] **Step 2: Run flutter analyze**

```bash
flutter analyze lib/screens/metadata_sheet.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/screens/metadata_sheet.dart
git commit -m "feat: MetadataSheet — EXIF + NovelAI bottom sheet"
git push origin main
```

---

### Task 15: EditScreen

**Files:**
- Create: `lib/screens/edit_screen.dart`

- [ ] **Step 1: Create lib/screens/edit_screen.dart**

```dart
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

import '../core/log_service.dart';
import '../models/image_file.dart';
import '../services/image_actions_service.dart';

class EditScreen extends StatefulWidget {
  final ImageFile imageFile;
  final VoidCallback onSaved;

  const EditScreen({
    super.key,
    required this.imageFile,
    required this.onSaved,
  });

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  final _cropController = CropController();
  final _actions = ImageActionsService();

  Uint8List? _imageBytes;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await widget.imageFile.file.readAsBytes();
      if (mounted) setState(() { _imageBytes = bytes; _loading = false; });
    } catch (e, st) {
      LogService.instance.error('EditScreen load failed: $e', st);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _rotateLeft() async {
    if (_imageBytes == null) return;
    setState(() => _loading = true);
    try {
      final rotated = await _actions.rotateImage(widget.imageFile, -90);
      if (mounted) setState(() { _imageBytes = rotated; _loading = false; });
    } catch (e, st) {
      LogService.instance.error('Rotate left failed: $e', st);
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _rotateRight() async {
    if (_imageBytes == null) return;
    setState(() => _loading = true);
    try {
      final rotated = await _actions.rotateImage(widget.imageFile, 90);
      if (mounted) setState(() { _imageBytes = rotated; _loading = false; });
    } catch (e, st) {
      LogService.instance.error('Rotate right failed: $e', st);
      if (mounted) setState(() => _loading = false);
    }
  }

  void _save() {
    _cropController.crop();
  }

  Future<void> _onCropped(Uint8List cropped) async {
    setState(() => _saving = true);
    try {
      await _actions.saveEdit(widget.imageFile, cropped);
      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (e, st) {
      LogService.instance.error('Save edit failed: $e', st);
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.imageFile.name,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _loading || _imageBytes == null
          ? const Center(child: CircularProgressIndicator())
          : Crop(
              image: _imageBytes!,
              controller: _cropController,
              onCropped: _onCropped,
              withCircleUi: false,
              baseColor: Colors.black,
              maskColor: Colors.black54,
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: _saving ? null : _rotateLeft,
                icon: const Icon(Icons.rotate_left,
                    color: Colors.white, size: 32),
                tooltip: 'Rotate left',
              ),
              IconButton(
                onPressed: _saving ? null : _rotateRight,
                icon: const Icon(Icons.rotate_right,
                    color: Colors.white, size: 32),
                tooltip: 'Rotate right',
              ),
              if (_saving)
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Run flutter analyze**

```bash
flutter analyze lib/screens/edit_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/screens/edit_screen.dart
git commit -m "feat: EditScreen — crop and rotate with crop_your_image"
git push origin main
```

---

### Task 16: LogScreen

**Files:**
- Create: `lib/screens/log_screen.dart`

- [ ] **Step 1: Create lib/screens/log_screen.dart**

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../core/log_service.dart';
import '../providers/providers.dart';

class LogScreen extends ConsumerStatefulWidget {
  const LogScreen({super.key});

  @override
  ConsumerState<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends ConsumerState<LogScreen> {
  final _expanded = <int>{};

  Color _levelColor(LogLevel level) => switch (level) {
        LogLevel.error => Colors.red.shade300,
        LogLevel.warning => Colors.amber.shade300,
        LogLevel.info => Colors.grey.shade400,
      };

  Future<void> _copyAll(List<LogEntry> entries) async {
    final text = entries.reversed.map((e) => e.toString()).join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Logs copied')));
    }
  }

  Future<void> _shareFile() async {
    final path = LogService.instance.logFilePath;
    final file = File(path);
    if (!await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Log file not found')));
      }
      return;
    }
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], subject: 'app.log'),
    );
  }

  void _clear() {
    LogService.instance.clear();
    setState(() => _expanded.clear());
    ref.invalidate(logProvider);
  }

  @override
  Widget build(BuildContext context) {
    // We read directly from LogService so pressing "Clear" refreshes instantly.
    final entries = LogService.instance.entries.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy all',
            onPressed: () => _copyAll(entries),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share log file',
            onPressed: _shareFile,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear',
            onPressed: _clear,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                LogService.instance.logFilePath,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: Colors.grey),
              ),
            ),
          ),
        ),
      ),
      body: entries.isEmpty
          ? const Center(child: Text('No log entries yet.'))
          : ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final isExpanded = _expanded.contains(index);
                return InkWell(
                  onTap: () {
                    if (entry.stackTrace != null) {
                      setState(() {
                        if (isExpanded) {
                          _expanded.remove(index);
                        } else {
                          _expanded.add(index);
                        }
                      });
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Chip(
                              label: Text(
                                entry.level.name.toUpperCase(),
                                style: TextStyle(
                                    color: _levelColor(entry.level),
                                    fontSize: 10),
                              ),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${entry.timestamp.hour.toString().padLeft(2, '0')}'
                              ':${entry.timestamp.minute.toString().padLeft(2, '0')}'
                              ':${entry.timestamp.second.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(entry.message,
                            style: TextStyle(
                                fontSize: 12,
                                color: _levelColor(entry.level))),
                        if (isExpanded && entry.stackTrace != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              entry.stackTrace.toString(),
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                  fontFamily: 'monospace'),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
```

- [ ] **Step 2: Run flutter analyze**

```bash
flutter analyze lib/screens/log_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/screens/log_screen.dart
git commit -m "feat: LogScreen — color-coded log viewer with copy/share/clear"
git push origin main
```

---

### Task 17: HomeScreen

**Files:**
- Create: `lib/screens/home_screen.dart`

- [ ] **Step 1: Create lib/screens/home_screen.dart**

```dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../core/constants.dart';
import '../core/log_service.dart';
import '../models/image_file.dart';
import '../providers/providers.dart';
import '../screens/log_screen.dart';
import '../screens/viewer_screen.dart';
import '../services/gallery_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _permissionGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    await _requestPermission();
    await initFolderPath(ref);
    // If no folder saved, prompt the user to pick one.
    if (ref.read(folderPathProvider) == null && mounted) {
      _pickFolder();
    }
  }

  Future<void> _requestPermission() async {
    final result = await PhotoManager.requestPermissionExtend();
    setState(() => _permissionGranted = result.isAuth);
    if (!result.isAuth) {
      LogService.instance.warning('Media permission not granted: $result');
    }
  }

  Future<void> _pickFolder() async {
    try {
      final svc = GalleryService();
      String? picked = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose image folder',
      );
      if (picked == null) return;

      // Convert SAF URI → real path if needed.
      final resolved = svc.safUriToPath(picked) ?? picked;

      await setFolderPath(ref, resolved);
    } catch (e, st) {
      LogService.instance.error('Folder picker failed: $e', st);
    }
  }

  void _openViewer(List<ImageFile> images, int index) {
    ref.read(currentIndexProvider.notifier).state = index;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ViewerScreen(images: images, initialIndex: index),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final gallery = ref.watch(galleryProvider);
    final folderPath = ref.watch(folderPathProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          folderPath != null
              ? folderPath.split('/').last
              : 'Image Viewer',
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'folder') _pickFolder();
              if (value == 'logs') {
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LogScreen()));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'folder', child: Text('Change Folder')),
              PopupMenuItem(value: 'logs', child: Text('Developer Logs')),
            ],
          ),
        ],
      ),
      body: gallery.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) {
          LogService.instance.error('Gallery load error: $e', st);
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 8),
                Text('$e'),
                TextButton(
                    onPressed: () => ref.invalidate(galleryProvider),
                    child: const Text('Retry')),
              ],
            ),
          );
        },
        data: (images) {
          if (images.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.photo_library_outlined, size: 64),
                  const SizedBox(height: 16),
                  const Text('No images found'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _pickFolder,
                    child: const Text('Choose Folder'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(galleryProvider),
            child: GridView.builder(
              padding: const EdgeInsets.all(2),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemCount: images.length,
              itemBuilder: (context, index) {
                final img = images[index];
                return GestureDetector(
                  onTap: () => _openViewer(images, index),
                  child: img.isSvg
                      ? Container(
                          color: Colors.grey.shade800,
                          child: const Icon(Icons.image,
                              color: Colors.white54),
                        )
                      : Image.file(
                          img.file,
                          fit: BoxFit.cover,
                          cacheWidth: (kThumbnailSize * 3).toInt(),
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade800,
                            child: const Icon(Icons.broken_image,
                                color: Colors.white54),
                          ),
                        ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 2: Run flutter analyze**

```bash
flutter analyze lib/screens/home_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "feat: HomeScreen — 3-column grid, folder picker, overflow menu"
git push origin main
```

---

### Task 18: ViewerScreen

**Files:**
- Create: `lib/screens/viewer_screen.dart`

- [ ] **Step 1: Create lib/screens/viewer_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/log_service.dart';
import '../models/image_file.dart';
import '../screens/edit_screen.dart';
import '../screens/metadata_sheet.dart';
import '../services/image_actions_service.dart';
import '../widgets/image_page.dart';
import '../widgets/thumbnail_strip.dart';

class ViewerScreen extends StatefulWidget {
  final List<ImageFile> images;
  final int initialIndex;

  const ViewerScreen({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  late final PageController _page;
  late final List<TransformationController> _transforms;
  late int _currentIndex;
  final _actions = ImageActionsService();
  bool _showBars = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _page = PageController(initialPage: _currentIndex);
    _transforms = List.generate(
      widget.images.length,
      (_) => TransformationController(),
    );
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _scheduleBarsHide();
  }

  void _scheduleBarsHide() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _showBars) setState(() => _showBars = false);
    });
  }

  void _toggleBars() {
    setState(() => _showBars = !_showBars);
    if (_showBars) _scheduleBarsHide();
  }

  void _goToIndex(int index) {
    _page.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    // Reset zoom on the page we're leaving.
    _transforms[_currentIndex].value = Matrix4.identity();
    setState(() => _currentIndex = index);
  }

  Future<void> _share() async {
    try {
      await _actions.share(widget.images[_currentIndex]);
    } catch (e, st) {
      LogService.instance.error('Share error: $e', st);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete image?'),
        content: Text(widget.images[_currentIndex].name),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _actions.delete(widget.images[_currentIndex]);
      if (mounted) Navigator.of(context).pop();
    } catch (e, st) {
      LogService.instance.error('Delete error: $e', st);
    }
  }

  void _edit() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EditScreen(
        imageFile: widget.images[_currentIndex],
        onSaved: () => setState(() {}), // force image widget rebuild
      ),
    ));
  }

  void _info() {
    MetadataSheet.show(context, widget.images[_currentIndex]);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _page.dispose();
    for (final t in _transforms) {
      t.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleBars,
        child: Stack(
          children: [
            // ── Main PageView ───────────────────────────────────────────
            PageView.builder(
              controller: _page,
              itemCount: widget.images.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (_, index) => ImagePage(
                imageFile: widget.images[index],
                transformationController: _transforms[index],
              ),
            ),

            // ── Top action bar ──────────────────────────────────────────
            if (_showBars)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Container(
                    color: Colors.black54,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Expanded(
                          child: Text(
                            widget.images[_currentIndex].name,
                            style: const TextStyle(color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${_currentIndex + 1} / ${widget.images.length}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                        IconButton(
                          icon: const Icon(Icons.share,
                              color: Colors.white),
                          tooltip: 'Share',
                          onPressed: _share,
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit,
                              color: Colors.white),
                          tooltip: 'Edit',
                          onPressed: _edit,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.white),
                          tooltip: 'Delete',
                          onPressed: _delete,
                        ),
                        IconButton(
                          icon: const Icon(Icons.info_outline,
                              color: Colors.white),
                          tooltip: 'Info',
                          onPressed: _info,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Bottom thumbnail strip ──────────────────────────────────
            if (_showBars)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Container(
                    color: Colors.black54,
                    child: ThumbnailStrip(
                      images: widget.images,
                      currentIndex: _currentIndex,
                      onTap: _goToIndex,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Run flutter analyze**

```bash
flutter analyze lib/screens/viewer_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/screens/viewer_screen.dart
git commit -m "feat: ViewerScreen — PageView, thumb strip, action bar, auto-hide"
git push origin main
```

---

### Task 19: main.dart — app entry, error hooks, intent routing

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Replace lib/main.dart with the final version**

```dart
import 'dart:async';
import 'dart:ui';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/log_service.dart';
import 'core/theme.dart';
import 'screens/home_screen.dart';
import 'screens/viewer_screen.dart';
import 'services/gallery_service.dart';

void main() {
  runZonedGuarded<void>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Wire Flutter framework errors into LogService.
      FlutterError.onError = (details) {
        LogService.instance.error(
            details.exceptionAsString(), details.stack);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        LogService.instance.error(error, stack);
        return true;
      };

      // Start LogService (sets up the on-disk log file).
      await LogService.instance.init();
      LogService.instance.info('App starting');

      // Check if this launch came from a file manager "Open with…" tap.
      Uri? initialUri;
      try {
        initialUri = await AppLinks().getInitialLink();
        if (initialUri != null) {
          LogService.instance.info('Intent URI: $initialUri');
        }
      } catch (e, st) {
        LogService.instance.warning('Failed to get initial link: $e', st);
      }

      runApp(
        ProviderScope(
          child: ImageViewerApp(initialUri: initialUri),
        ),
      );
    },
    (error, stack) {
      LogService.instance.error(error, stack);
    },
  );
}

class ImageViewerApp extends StatelessWidget {
  final Uri? initialUri;

  const ImageViewerApp({super.key, this.initialUri});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Viewer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: initialUri != null
          ? _IntentLoader(uri: initialUri!)
          : const HomeScreen(),
    );
  }
}

/// Shown when the app is launched via a file manager intent.
/// Loads all images from the tapped file's parent directory and opens
/// ViewerScreen at the tapped image's index.
class _IntentLoader extends StatefulWidget {
  final Uri uri;
  const _IntentLoader({required this.uri});

  @override
  State<_IntentLoader> createState() => _IntentLoaderState();
}

class _IntentLoaderState extends State<_IntentLoader> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = GalleryService();
    final result = await svc.loadFromUri(widget.uri);

    if (!mounted) return;

    if (result == null || result.images.isEmpty) {
      LogService.instance.warning('Intent load returned no images');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ProviderScope(
          child: ViewerScreen(
            images: result.images,
            initialIndex: result.startIndex,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
```

- [ ] **Step 2: Run flutter analyze on the whole lib**

```bash
cd /home/ubuntu/flutter-manga-viewer
flutter analyze lib/ 2>&1 | tail -15
```

Expected: `No issues found!`

If there are type errors or missing imports, fix them before proceeding.

- [ ] **Step 3: Run all unit tests**

```bash
flutter test 2>&1 | tail -10
```

Expected: `All tests passed!`

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat: main.dart — error hooks, LogService init, intent routing"
git push origin main
```

---

### Task 20: Final build and smoke verification

- [ ] **Step 1: Run the full test suite one more time**

```bash
cd /home/ubuntu/flutter-manga-viewer
flutter test 2>&1
```

Expected: all tests pass.

- [ ] **Step 2: Build the release APK**

```bash
flutter build apk --release --target-platform android-arm64 2>&1 | tail -10
```

Expected: `✓ Built build/app/outputs/flutter-apk/app-release.apk`

The APK will be roughly 20–30 MB.

- [ ] **Step 3: Note where the APK is**

The built APK is at:
```
/home/ubuntu/flutter-manga-viewer/build/app/outputs/flutter-apk/app-release.apk
```

To install it on your Android device, transfer this file to the device (e.g., via USB, cloud storage, or a web server) and open it. Android will ask if you want to install from an unknown source — you will need to allow this in Settings → Security → Install unknown apps.

- [ ] **Step 4: Final commit and push**

```bash
git add -A
git commit -m "chore: v1.0.0 — complete image viewer build"
git push origin main
```

---

## Self-Review Checklist

**Spec coverage:**
- ✅ `.jpg .png .svg .webp` support — `constants.dart` + `GalleryService.filterImages`
- ✅ Alphabetical sort — `GalleryService.sortImages`
- ✅ Horizontal swipe — `ViewerScreen` PageView
- ✅ Thumbnail strip — `ThumbnailStrip` widget
- ✅ Pinch-to-zoom — `ImagePage` InteractiveViewer
- ✅ Edit (crop + rotate) — `EditScreen` + `ImageActionsService.rotateImage`
- ✅ Delete — `ImageActionsService.delete` + MediaStore notify
- ✅ Share — `ImageActionsService.share` via share_plus
- ✅ Metadata panel — `MetadataSheet` (resolution, color space, date, GPS)
- ✅ NovelAI prompt reader — `PngMetadataService` tEXt/iTXt parser
- ✅ In-app log viewer — `LogScreen` with copy/share/clear + `LogService`
- ✅ Folder picker on first launch — `HomeScreen._pickFolder` + `file_picker`
- ✅ Intent from file manager — `_IntentLoader` + `GalleryService.loadFromUri`
- ✅ Browse folder when opened from file manager — `loadFromUri` scans parent dir
- ✅ Android 13+ permissions — `AndroidManifest.xml` + `PhotoManager.requestPermissionExtend()`
- ✅ Engine pre-warm (ANR prevention) — `Application.kt`
- ✅ ARM64 build — `--target-platform android-arm64` build command
