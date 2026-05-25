import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
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
  return LogService.instance.entries;
});

// ── SharedPreferences helpers ─────────────────────────────────────────────────

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
