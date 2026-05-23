import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../providers/providers.dart';
import '../services/image_actions.dart';
import '../services/share_service.dart';
import '../widgets/image_view.dart';
import '../widgets/thumbnail_strip.dart';
import 'edit_screen.dart';
import 'metadata_sheet.dart';

class ViewerScreen extends ConsumerStatefulWidget {
  const ViewerScreen({super.key, this.initialIndex = 0});
  final int initialIndex;

  @override
  ConsumerState<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends ConsumerState<ViewerScreen> {
  late final PageController _pageController =
      PageController(initialPage: widget.initialIndex);
  bool _chromeVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(currentIndexProvider.notifier).state = widget.initialIndex;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _deleteCurrent(List<AssetEntity> assets, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete image?'),
        content: Text(assets[index].title ?? '<unnamed>'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final ok = await ImageActions.delete(assets[index]);
    if (!mounted) return;
    if (ok) {
      ref.read(imageListProvider.notifier).removeAt(index);
      final remaining = ref.read(imageListProvider).value ?? const [];
      if (remaining.isEmpty) {
        Navigator.of(context).pop();
      } else {
        final newIndex = index >= remaining.length ? remaining.length - 1 : index;
        _pageController.jumpToPage(newIndex);
        ref.read(currentIndexProvider.notifier).state = newIndex;
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Delete failed. Android may need you to confirm the action.',
          ),
        ),
      );
    }
  }

  Future<void> _editCurrent(AssetEntity asset) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditScreen(asset: asset)),
    );
    if (changed == true && mounted) {
      await ref.read(imageListProvider.notifier).refresh();
    }
  }

  void _showMetadata(AssetEntity asset) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MetadataSheet(asset: asset),
    );
  }

  Future<void> _share(AssetEntity asset) async {
    final ok = await ShareService.shareAsset(asset);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not access file for sharing')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncAssets = ref.watch(imageListProvider);
    final currentIndex = ref.watch(currentIndexProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _chromeVisible
          ? AppBar(
              backgroundColor: Colors.black.withValues(alpha: 0.4),
              foregroundColor: Colors.white,
              title: asyncAssets.value != null &&
                      currentIndex < asyncAssets.value!.length
                  ? Text(
                      asyncAssets.value![currentIndex].title ?? '',
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
            )
          : null,
      body: asyncAssets.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        error: (e, _) => Center(
          child: Text('Error: $e', style: const TextStyle(color: Colors.white)),
        ),
        data: (assets) {
          if (assets.isEmpty) {
            return const Center(
              child: Text(
                'No images.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }
          return GestureDetector(
            onTap: () => setState(() => _chromeVisible = !_chromeVisible),
            behavior: HitTestBehavior.translucent,
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: assets.length,
                  onPageChanged: (i) =>
                      ref.read(currentIndexProvider.notifier).state = i,
                  itemBuilder: (_, i) => ZoomableImageView(asset: assets[i]),
                ),
                if (_chromeVisible)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _BottomBar(
                      assets: assets,
                      currentIndex: currentIndex,
                      onThumbnailTap: (i) {
                        _pageController.animateToPage(
                          i,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        );
                      },
                      onEdit: () => _editCurrent(assets[currentIndex]),
                      onDelete: () => _deleteCurrent(assets, currentIndex),
                      onShare: () => _share(assets[currentIndex]),
                      onInfo: () => _showMetadata(assets[currentIndex]),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.assets,
    required this.currentIndex,
    required this.onThumbnailTap,
    required this.onEdit,
    required this.onDelete,
    required this.onShare,
    required this.onInfo,
  });

  final List<AssetEntity> assets;
  final int currentIndex;
  final ValueChanged<int> onThumbnailTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.55),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ThumbnailStrip(
              assets: assets,
              currentIndex: currentIndex,
              onTap: onThumbnailTap,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  tooltip: 'Edit',
                  color: Colors.white,
                  onPressed: onEdit,
                  icon: const Icon(Icons.crop_rotate),
                ),
                IconButton(
                  tooltip: 'Share',
                  color: Colors.white,
                  onPressed: onShare,
                  icon: const Icon(Icons.share),
                ),
                IconButton(
                  tooltip: 'Info',
                  color: Colors.white,
                  onPressed: onInfo,
                  icon: const Icon(Icons.info_outline),
                ),
                IconButton(
                  tooltip: 'Delete',
                  color: Colors.white,
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
