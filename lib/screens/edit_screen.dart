import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../services/asset_file.dart';
import '../services/image_actions.dart';

/// Edits a copy of the underlying file and saves the result back to
/// MediaStore as a new asset. We never modify the source in place — that
/// would require special MediaStore "edit pending" flows that don't work
/// for assets owned by other apps.
class EditScreen extends StatefulWidget {
  const EditScreen({super.key, required this.asset});
  final AssetEntity asset;

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  final _cropController = CropController();
  late Future<Uint8List?> _bytes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _bytes = _loadBytes();
  }

  Future<Uint8List?> _loadBytes() async {
    final file = await resolveAssetFile(widget.asset);
    if (file == null) return null;
    return file.readAsBytes();
  }

  Future<void> _rotateClockwise() async {
    setState(() => _saving = true);
    final newAsset = await ImageActions.rotate(widget.asset);
    if (!mounted) return;
    setState(() => _saving = false);
    if (newAsset != null) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rotate failed')),
      );
    }
  }

  void _saveCrop() {
    setState(() => _saving = true);
    _cropController.crop();
  }

  Future<void> _onCropped(Uint8List bytes) async {
    final filename = widget.asset.title ?? 'image.jpg';
    final newAsset = await ImageActions.saveCropped(filename, bytes);
    if (!mounted) return;
    setState(() => _saving = false);
    if (newAsset != null) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Crop save failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit'),
        actions: [
          IconButton(
            tooltip: 'Rotate 90°',
            icon: const Icon(Icons.rotate_right),
            onPressed: _saving ? null : _rotateClockwise,
          ),
          IconButton(
            tooltip: 'Save crop',
            icon: const Icon(Icons.check),
            onPressed: _saving ? null : _saveCrop,
          ),
        ],
      ),
      body: FutureBuilder<Uint8List?>(
        future: _bytes,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data;
          if (data == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Could not load image bytes from MediaStore.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return Stack(
            children: [
              Crop(
                controller: _cropController,
                image: data,
                onCropped: (result) {
                  if (result is CropSuccess) {
                    _onCropped(result.croppedImage);
                  } else {
                    setState(() => _saving = false);
                  }
                },
                baseColor: Colors.black,
                maskColor: Colors.black.withValues(alpha: 0.5),
                interactive: true,
              ),
              if (_saving)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x44000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
