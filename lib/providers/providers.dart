import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/image_file.dart';
import '../services/file_scanner.dart';

/// Currently selected folder. Null until the user picks one.
final selectedFolderProvider = StateProvider<Directory?>((ref) => null);

/// Async list of images for the currently selected folder.
final imageListProvider =
    AsyncNotifierProvider<ImageListNotifier, List<ImageFile>>(
  ImageListNotifier.new,
);

class ImageListNotifier extends AsyncNotifier<List<ImageFile>> {
  @override
  Future<List<ImageFile>> build() async {
    final folder = ref.watch(selectedFolderProvider);
    if (folder == null) return const [];
    return FileScanner.scanDirectory(folder);
  }

  Future<void> refresh() async {
    final folder = ref.read(selectedFolderProvider);
    if (folder == null) {
      state = const AsyncData([]);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => FileScanner.scanDirectory(folder));
  }

  void removeAt(int index) {
    final current = state.value;
    if (current == null || index < 0 || index >= current.length) return;
    final next = List<ImageFile>.from(current)..removeAt(index);
    state = AsyncData(next);
  }
}

/// Active image index inside the current PageView.
final currentIndexProvider = StateProvider<int>((ref) => 0);

/// Light/dark mode toggle (manual override; defaults to system).
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
