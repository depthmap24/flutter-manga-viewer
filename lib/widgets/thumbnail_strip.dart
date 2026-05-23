import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

/// Horizontally scrolling row of thumbnails synchronized with a PageView.
class ThumbnailStrip extends StatefulWidget {
  const ThumbnailStrip({
    super.key,
    required this.assets,
    required this.currentIndex,
    required this.onTap,
  });

  final List<AssetEntity> assets;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  State<ThumbnailStrip> createState() => _ThumbnailStripState();
}

class _ThumbnailStripState extends State<ThumbnailStrip> {
  late final ScrollController _scroll = ScrollController();
  static const double _itemSize = 64;
  static const double _itemPad = 4;

  @override
  void didUpdateWidget(covariant ThumbnailStrip old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
    }
  }

  void _scrollToCurrent() {
    if (!_scroll.hasClients) return;
    final target = (widget.currentIndex * (_itemSize + _itemPad * 2)) -
        (MediaQuery.of(context).size.width / 2) +
        _itemSize / 2;
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
      height: _itemSize + _itemPad * 2,
      child: ListView.builder(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        itemCount: widget.assets.length,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemBuilder: (context, index) {
          final selected = index == widget.currentIndex;
          final asset = widget.assets[index];
          return GestureDetector(
            onTap: () => widget.onTap(index),
            child: Container(
              width: _itemSize,
              margin: const EdgeInsets.all(_itemPad),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              clipBehavior: Clip.hardEdge,
              child: AssetEntityImage(
                asset,
                isOriginal: false,
                thumbnailSize: const ThumbnailSize.square(128),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
              ),
            ),
          );
        },
      ),
    );
  }
}
