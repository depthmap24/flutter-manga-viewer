# Flutter Image Viewer — Design Spec
**Date:** 2026-05-23
**Repo:** depthmap24/flutter-manga-viewer
**Target platform:** Android (ARM64, Oracle Cloud Ampere build host)

---

## 1. Project Reset

The existing repository (`depthmap24/flutter-manga-viewer`, local `/home/ubuntu/flutter-manga-viewer`) is wiped completely:
- Local folder deleted and recreated via `flutter create`
- GitHub remote force-pushed with the new empty project
- No code carried over from v1.0.x

---

## 2. Supported File Types & Sorting

The app reads and displays images with extensions: `.jpg`, `.png`, `.svg`, `.webp`.

Images within a folder are always displayed in **alphabetical order by filename**.

---

## 3. Architecture

**State management:** Riverpod (`flutter_riverpod ^3.x`)

### Providers

| Provider | Type | Purpose |
|---|---|---|
| `folderPathProvider` | `StateProvider<String?>` | Persisted folder path; `null` = no folder chosen yet |
| `galleryProvider` | `AsyncNotifierProvider<GalleryNotifier, List<AssetEntity>>` | Loads & sorts images from the selected folder via `photo_manager` |
| `currentIndexProvider` | `StateProvider<int>` | Currently viewed image index |
| `logProvider` | `StateNotifierProvider<LogNotifier, List<LogEntry>>` | In-memory log list for LogScreen |

### Navigation flows

**Normal launch (launcher icon):**
`main()` → `HomeScreen` → folder picker (if `folderPathProvider == null`) → gallery grid → `ViewerScreen`

**Intent launch (file manager tap):**
`main()` → reads incoming `ACTION_VIEW` URI via `app_links` → resolves parent directory → loads all images from that directory → opens `ViewerScreen` directly at the tapped image index

In both flows, `ViewerScreen` receives the full image list and the starting index.

### Android cold-start
`Application.onCreate` pre-warms the `FlutterEngine` to prevent ANR on first launch (pattern carried forward from v1.0.13).

---

## 4. Screens & UI

### HomeScreen
- App bar: title + overflow menu (⋮) with entries "Change Folder" and "Developer Logs"
- Body: 3-column thumbnail grid (`photo_manager_image_provider` for cached thumbnails)
- Tapping a thumbnail opens `ViewerScreen` at that index

### ViewerScreen
- Full-screen dark background
- `PageView.builder` for left/right swipe between images
- Each page: `InteractiveViewer` wrapping the image (pinch-to-zoom, min 1×, max 5×, reset on page change)
- SVG files rendered via `flutter_svg`; all other types via `photo_manager_image_provider`
- **Bottom thumbnail strip:** horizontally scrollable row of small thumbnails; active item highlighted; auto-scrolls to keep current thumb visible; tapping a thumbnail jumps the `PageView`
- **Top action bar** (auto-hides 3 s after last tap): back button, share (↗), edit (✏), delete (🗑), info (ⓘ)

### MetadataSheet
Bottom sheet triggered by ⓘ:
- Filename, resolution (W × H px), color space, date modified
- GPS coordinates (if present in EXIF)
- **"AI Generation" collapsible card** (shown only when NovelAI data detected):
  - Prompt and negative prompt in selectable/copyable text fields
  - Parameters (steps, sampler, seed, CFG scale, image size) as compact key-value table

### EditScreen
- `crop_your_image` widget fills the screen
- Bottom bar: rotate-left button, rotate-right button, Save, Cancel
- On Save: overwrites the original file on disk, invalidates the gallery cache, pops back to `ViewerScreen`

### LogScreen
Opened from HomeScreen overflow menu → "Developer Logs":
- Full-screen list of log entries, newest first
- Color-coded rows: red = error, amber = warning, grey = info
- Tap a row to expand the full stack trace
- Top bar actions: "Copy All" (copies full log text to clipboard), "Share Log File" (shares `.log` file via `share_plus`), "Clear"
- Subtitle shows the on-disk log file path

---

## 5. Services

### GalleryService
- `loadFolder(String path) → List<AssetEntity>`: uses `photo_manager` to find the `AssetPathEntity` matching the path, fetches all assets with `.jpg/.png/.webp/.svg` extensions, sorts alphabetically by filename.
- `loadFolderFromUri(Uri fileUri) → (List<AssetEntity>, int startIndex)`: for intent launches — resolves the parent directory of the incoming file URI, runs the same load+sort, returns the list and the index of the tapped file.

### MetadataService
- `getExif(AssetEntity) → ImageMetadata`: reads resolution, color space, date taken, GPS via the `exif` package.
- `getNovelAiPrompt(File) → NovelAiMetadata?`: reads raw PNG bytes, walks tEXt/iTXt chunks, returns structured data or `null`.

### PngMetadataService (NovelAI parser)
1. Verify PNG signature (`\x89PNG\r\n\x1a\n`)
2. Walk chunks: 4-byte length + 4-byte type; collect all `tEXt` and `iTXt` chunks
3. Extract key/value from each chunk; decompress zlib-compressed iTXt values
4. Look for keys: `parameters`, `Description`, `Comment` (JSON)
5. Assemble `NovelAiMetadata { prompt, negativePrompt, steps, sampler, seed, cfgScale, imageSize }`
6. Return `null` cleanly if no known keys found

### ImageActionsService
- `share(AssetEntity)`: via `share_plus`
- `delete(AssetEntity)`: removes file from disk + notifies `photo_manager` to update MediaStore; triggers gallery refresh via provider invalidation
- `saveEdit(File cropped)`: overwrites original, re-scans folder

### LogService (singleton)
- Initialized before `runApp`
- Three levels: `info`, `warning`, `error`
- Writes to: (1) in-memory `List<LogEntry>` capped at 500 entries, (2) `<appDir>/logs/app.log` on disk (rolling at 2 MB)
- Global hooks in `main()`:
  - `FlutterError.onError`
  - `PlatformDispatcher.instance.onError`
  - `runZonedGuarded` catch block
- All service call sites wrap operations in try/catch and log failures

---

## 6. Permissions & Android Manifest

| Permission | Reason |
|---|---|
| `READ_MEDIA_IMAGES` | Android 13+ image access |
| `READ_EXTERNAL_STORAGE` (`maxSdkVersion="32"`) | Android ≤ 12 image access |
| `WRITE_EXTERNAL_STORAGE` (API ≤ 29 only) | Delete / save-edit on older Android |
| `ACCESS_MEDIA_LOCATION` | GPS data from EXIF |

**Intent filter** on `MainActivity`:
```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <data android:mimeType="image/*" />
</intent-filter>
```
This makes the app appear in "Open with…" for all image files in any file manager.

---

## 7. Package List

| Purpose | Package |
|---|---|
| State management | `flutter_riverpod ^3.x` |
| Photo/media access | `photo_manager ^3.x` |
| Cached thumbnail rendering | `photo_manager_image_provider ^2.x` |
| SVG rendering | `flutter_svg ^2.x` |
| Pinch-to-zoom | `InteractiveViewer` (Flutter built-in) |
| Crop & rotate | `crop_your_image ^2.x` |
| EXIF metadata | `exif ^3.x` |
| PNG chunk parsing | Custom (`dart:typed_data` — no extra package) |
| Share | `share_plus ^13.x` |
| Folder picker | `file_picker ^8.x` |
| Persist folder path | `shared_preferences ^2.x` |
| Intent URI handling | `app_links ^7.x` |
| Logging to file | `dart:io` (built-in) |

---

## 8. File Structure (target)

```
lib/
  main.dart                  # app entry, error hooks, intent routing
  core/
    constants.dart           # shared constants (extensions list, log cap, etc.)
    theme.dart               # light/dark MaterialTheme
    log_service.dart         # LogService singleton + LogEntry model
  models/
    image_metadata.dart      # ImageMetadata, NovelAiMetadata structs
  providers/
    providers.dart           # all Riverpod providers
  screens/
    home_screen.dart
    viewer_screen.dart
    edit_screen.dart
    log_screen.dart
    metadata_sheet.dart      # bottom sheet, not a full screen
  services/
    gallery_service.dart
    metadata_service.dart
    png_metadata_service.dart
    image_actions_service.dart
  widgets/
    thumbnail_strip.dart     # bottom scrollable thumb bar
    image_page.dart          # single page in PageView (InteractiveViewer + image)
android/
  app/src/main/
    AndroidManifest.xml      # permissions + intent filter
    kotlin/.../Application.kt # FlutterEngine pre-warm
```

---

## 9. Key Constraints & Risks

- **ANR risk from `photo_manager`:** All `photo_manager` calls must run on background isolates or async contexts — never on the main thread. Use `photo_manager`'s async APIs throughout.
- **ARM build host:** All packages must be pure-Dart or have pre-built ARM64 `.so` files. Packages requiring custom CMake builds (e.g., older `ffmpeg_kit`) are excluded.
- **No ADB access:** All debugging must go through `LogScreen`. Every catch block must log before rethrowing or swallowing.
- **File picker on Android 13+:** `file_picker` requires `photo_manager`'s permission to be granted first; permission request flow must complete before opening the picker.
- **SVG in `PageView`:** `flutter_svg` renders to a widget tree, not a bitmap — `InteractiveViewer` wraps it the same way as raster images with no special casing needed.
