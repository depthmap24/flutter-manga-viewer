import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

import '../core/log_service.dart';
import '../models/image_file.dart';
import '../services/image_actions_service.dart';

class EditScreen extends StatefulWidget {
  final ImageFile imageFile;
  final VoidCallback onSaved;

  const EditScreen({
    super.key,
    required this.imageFile,
    required this.onSaved,
  });

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  final _cropController = CropController();
  final _actions = ImageActionsService();

  Uint8List? _imageBytes;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await widget.imageFile.file.readAsBytes();
      if (mounted) {
        setState(() {
          _imageBytes = bytes;
          _loading = false;
        });
      }
    } catch (e, st) {
      LogService.instance.error('EditScreen load failed: $e', st);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _rotateLeft() async {
    if (_imageBytes == null) return;
    setState(() => _loading = true);
    try {
      final rotated = await _actions.rotateImage(widget.imageFile, -90);
      if (mounted) {
        setState(() {
          _imageBytes = rotated;
          _loading = false;
        });
      }
    } catch (e, st) {
      LogService.instance.error('Rotate left failed: $e', st);
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _rotateRight() async {
    if (_imageBytes == null) return;
    setState(() => _loading = true);
    try {
      final rotated = await _actions.rotateImage(widget.imageFile, 90);
      if (mounted) {
        setState(() {
          _imageBytes = rotated;
          _loading = false;
        });
      }
    } catch (e, st) {
      LogService.instance.error('Rotate right failed: $e', st);
      if (mounted) setState(() => _loading = false);
    }
  }

  void _save() {
    _cropController.crop();
  }

  Future<void> _onCropped(CropResult result) async {
    if (result is CropFailure) {
      LogService.instance.error(
          'Crop failed: ${result.cause}', result.stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Crop failed: ${result.cause}')),
        );
      }
      return;
    }
    final cropped = (result as CropSuccess).croppedImage;
    setState(() => _saving = true);
    try {
      await _actions.saveEdit(widget.imageFile, cropped);
      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (e, st) {
      LogService.instance.error('Save edit failed: $e', st);
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.imageFile.name,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _loading || _imageBytes == null
          ? const Center(child: CircularProgressIndicator())
          : Crop(
              image: _imageBytes!,
              controller: _cropController,
              onCropped: _onCropped,
              withCircleUi: false,
              baseColor: Colors.black,
              maskColor: Colors.black54,
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: _saving ? null : _rotateLeft,
                icon: const Icon(Icons.rotate_left,
                    color: Colors.white, size: 32),
                tooltip: 'Rotate left',
              ),
              IconButton(
                onPressed: _saving ? null : _rotateRight,
                icon: const Icon(Icons.rotate_right,
                    color: Colors.white, size: 32),
                tooltip: 'Rotate right',
              ),
              if (_saving)
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
