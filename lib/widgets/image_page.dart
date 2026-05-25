import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/image_file.dart';

/// A single page in the ViewerScreen PageView.
/// Wraps the image in InteractiveViewer for pinch-to-zoom.
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
        placeholderBuilder: (_) => const CircularProgressIndicator(),
      );
    }
    return Image.file(
      imageFile.file,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Column(
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
