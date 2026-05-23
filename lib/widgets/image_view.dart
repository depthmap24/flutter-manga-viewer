import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/image_file.dart';

/// Renders an image with pinch-to-zoom and double-tap to reset.
class ZoomableImageView extends StatefulWidget {
  const ZoomableImageView({super.key, required this.image});

  final ImageFile image;

  @override
  State<ZoomableImageView> createState() => _ZoomableImageViewState();
}

class _ZoomableImageViewState extends State<ZoomableImageView>
    with SingleTickerProviderStateMixin {
  final TransformationController _controller = TransformationController();
  TapDownDetails? _doubleTapDetails;
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  Animation<Matrix4>? _animationMatrix;

  @override
  void dispose() {
    _controller.dispose();
    _animation.dispose();
    super.dispose();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    final isZoomedIn = _controller.value != Matrix4.identity();
    final endMatrix = isZoomedIn
        ? Matrix4.identity()
        : (Matrix4.identity()
          ..translateByDouble(
            -(_doubleTapDetails?.localPosition.dx ?? 0),
            -(_doubleTapDetails?.localPosition.dy ?? 0),
            0,
            1,
          )
          ..scaleByDouble(2.0, 2.0, 1.0, 1.0));
    _animationMatrix =
        Matrix4Tween(begin: _controller.value, end: endMatrix).animate(
      CurvedAnimation(parent: _animation, curve: Curves.easeOut),
    );
    _animation
      ..removeListener(_listener)
      ..addListener(_listener)
      ..forward(from: 0);
  }

  void _listener() {
    _controller.value = _animationMatrix!.value;
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.image.isSvg
        ? SvgPicture.file(
            File(widget.image.path),
            fit: BoxFit.contain,
            placeholderBuilder: (_) =>
                const Center(child: CircularProgressIndicator()),
          )
        : Image.file(
            File(widget.image.path),
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.broken_image, size: 64),
            ),
          );

    return GestureDetector(
      onDoubleTapDown: _handleDoubleTapDown,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _controller,
        minScale: 1.0,
        maxScale: 6.0,
        clipBehavior: Clip.none,
        child: Center(child: child),
      ),
    );
  }
}
