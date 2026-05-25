import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../core/constants.dart';
import '../core/log_service.dart';
import '../models/image_file.dart';
import '../providers/providers.dart';
import '../services/gallery_service.dart';
import '../screens/log_screen.dart';
import '../screens/viewer_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    try {
      await _requestPermission();
      await _loadPrefs();
      if (ref.read(folderPathProvider) == null) {
        await _pickFolder();
      }
    } catch (e, st) {
      LogService.instance.error('HomeScreen._init() failed: $e', st);
    }
  }

  Future<void> _requestPermission() async {
    try {
      final result = await PhotoManager.requestPermissionExtend()
          .timeout(const Duration(seconds: 10), onTimeout: () {
        LogService.instance.warning('PhotoManager permission request timed out');
        return PermissionState.denied;
      });
      LogService.instance.info('PhotoManager permission result: $result');
    } catch (e, st) {
      LogService.instance.error('PhotoManager.requestPermissionExtend() failed: $e', st);
    }
  }

  Future<void> _loadPrefs() async {
    try {
      await initFolderPath(ref)
          .timeout(const Duration(seconds: 5), onTimeout: () {
        LogService.instance.warning('SharedPreferences load timed out');
      });
    } catch (e, st) {
      LogService.instance.error('initFolderPath failed: $e', st);
    }
  }

  Future<void> _pickFolder() async {
    if (!mounted) return;

    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Image Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '/storage/emulated/0/Pictures',
            labelText: 'Folder path',
          ),
          autofocus: true,
          onSubmitted: (_) => Navigator.of(ctx).pop(true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    final input = controller.text.trim();
    controller.dispose(); // always dispose before any early returns

    if (confirmed != true) return;

    if (input.isEmpty) return;

    final resolved = GalleryService().safUriToPath(input) ?? input;

    if (!Directory(resolved).existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Folder not found')),
        );
      }
      return;
    }

    await setFolderPath(ref, resolved);
  }

  void _openViewer(List<ImageFile> images, int index) {
    // Sync global index so any provider watchers stay consistent.
    ref.read(currentIndexProvider.notifier).state = index;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ViewerScreen(images: images, initialIndex: index),
      ),
    );
  }

  String _folderName(String? path) {
    if (path == null || path.isEmpty) return 'Image Viewer';
    final parts = path.split('/');
    final name = parts.lastWhere((p) => p.isNotEmpty, orElse: () => '');
    return name.isEmpty ? 'Image Viewer' : name;
  }

  @override
  Widget build(BuildContext context) {
    final folderPath = ref.watch(folderPathProvider);
    final galleryAsync = ref.watch(galleryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_folderName(folderPath)),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'change_folder') {
                _pickFolder();
              } else if (value == 'dev_logs') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LogScreen()),
                );
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(
                value: 'change_folder',
                child: Text('Change Folder'),
              ),
              PopupMenuItem(
                value: 'dev_logs',
                child: Text('Developer Logs'),
              ),
            ],
          ),
        ],
      ),
      body: galleryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(galleryProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (images) {
          if (images.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.photo_library_outlined, size: 64),
                  const SizedBox(height: 16),
                  const Text('No images found'),
                  const SizedBox(height: 16),
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
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemCount: images.length,
              itemBuilder: (ctx, index) {
                final img = images[index];
                return GestureDetector(
                  onTap: () => _openViewer(images, index),
                  child: img.isSvg
                      ? Container(
                          color: Colors.grey.shade800,
                          child: const Center(
                            child: Icon(Icons.image, color: Colors.grey),
                          ),
                        )
                      : Image.file(
                          img.file,
                          fit: BoxFit.cover,
                          cacheWidth: (kThumbnailSize * 3).toInt(),
                          errorBuilder: (ctx, error, stack) => Container(
                            color: Colors.grey.shade800,
                            child: const Center(
                              child:
                                  Icon(Icons.broken_image, color: Colors.grey),
                            ),
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
