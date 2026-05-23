import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:photo_manager/photo_manager.dart';

import '../services/gallery_service.dart';

/// Currently selected album (Pictures, DCIM, ...). Null until the user picks.
final selectedAlbumProvider = StateProvider<AssetPathEntity?>((ref) => null);

/// Async list of images in the currently selected album.
final imageListProvider =
    AsyncNotifierProvider<ImageListNotifier, List<AssetEntity>>(
  ImageListNotifier.new,
);

class ImageListNotifier extends AsyncNotifier<List<AssetEntity>> {
  @override
  Future<List<AssetEntity>> build() async {
    final album = ref.watch(selectedAlbumProvider);
    if (album == null) return const [];
    return GalleryService.imagesInAlbum(album);
  }

  Future<void> refresh() async {
    final album = ref.read(selectedAlbumProvider);
    if (album == null) {
      state = const AsyncData([]);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => GalleryService.imagesInAlbum(album));
  }

  /// Removes an asset locally after a successful delete so the UI updates
  /// before MediaStore notifications propagate.
  void removeAt(int index) {
    final current = state.value;
    if (current == null || index < 0 || index >= current.length) return;
    final next = List<AssetEntity>.from(current)..removeAt(index);
    state = AsyncData(next);
  }
}

/// Active image index inside the current PageView.
final currentIndexProvider = StateProvider<int>((ref) => 0);

/// Light/dark mode toggle (manual override; defaults to system).
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
