import 'dart:io';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

import '../models/image_file.dart';
import '../services/image_actions.dart';

class EditScreen extends StatefulWidget {
  const EditScreen({super.key, required this.image});

  final ImageFile image;

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  final _cropController = CropController();
  late Future<Uint8List> _bytes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _bytes = File(widget.image.path).readAsBytes();
  }

  Future<void> _rotateClockwise() async {
    setState(() => _saving = true);
    final ok = await ImageActions.rotate(widget.image.path);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _bytes = File(widget.image.path).readAsBytes();
        _saving = false;
      });
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rotate failed')),
      );
    }
  }

  Future<void> _saveCrop() async {
    setState(() => _saving = true);
    _cropController.crop();
  }

  Future<void> _onCropped(Uint8List bytes) async {
    await ImageActions.overwrite(widget.image.path, bytes);
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop(true);
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
      body: FutureBuilder<Uint8List>(
        future: _bytes,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return Stack(
            children: [
              Crop(
                controller: _cropController,
                image: snap.data!,
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
