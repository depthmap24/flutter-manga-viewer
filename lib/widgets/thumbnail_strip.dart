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
    if (!_scroll.hasClients) return;
    final itemWidth = kThumbnailSize + 4;
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
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.broken_image, color: Colors.white54),
                    ),
            ),
          );
        },
      ),
    );
  }
}
