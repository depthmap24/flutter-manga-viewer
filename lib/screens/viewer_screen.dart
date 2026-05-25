import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/log_service.dart';
import '../models/image_file.dart';
import '../screens/edit_screen.dart';
import '../screens/metadata_sheet.dart';
import '../services/image_actions_service.dart';
import '../widgets/image_page.dart';
import '../widgets/thumbnail_strip.dart';

class ViewerScreen extends StatefulWidget {
  final List<ImageFile> images;
  final int initialIndex;

  const ViewerScreen({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  late final PageController _page;
  late final List<TransformationController> _transforms;
  late int _currentIndex;
  final _actions = ImageActionsService();
  bool _showBars = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _page = PageController(initialPage: _currentIndex);
    _transforms = List.generate(
      widget.images.length,
      (_) => TransformationController(),
    );
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _scheduleBarsHide();
  }

  void _scheduleBarsHide() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _showBars) setState(() => _showBars = false);
    });
  }

  void _toggleBars() {
    setState(() => _showBars = !_showBars);
    if (_showBars) _scheduleBarsHide();
  }

  void _goToIndex(int index) {
    _page.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    _transforms[_currentIndex].value = Matrix4.identity();
    setState(() => _currentIndex = index);
  }

  Future<void> _share() async {
    try {
      await _actions.share(widget.images[_currentIndex]);
    } catch (e, st) {
      LogService.instance.error('Share error: $e', st);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete image?'),
        content: Text(widget.images[_currentIndex].name),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _actions.delete(widget.images[_currentIndex]);
      if (mounted) Navigator.of(context).pop();
    } catch (e, st) {
      LogService.instance.error('Delete error: $e', st);
    }
  }

  void _edit() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EditScreen(
        imageFile: widget.images[_currentIndex],
        onSaved: () {
          // Evict the stale decoded bitmap so Image.file re-reads the new file.
          PaintingBinding.instance.imageCache
              .evict(FileImage(widget.images[_currentIndex].file));
          setState(() {});
        },
      ),
    ));
  }

  void _info() {
    MetadataSheet.show(context, widget.images[_currentIndex]);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _page.dispose();
    for (final t in _transforms) {
      t.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleBars,
        child: Stack(
          children: [
            PageView.builder(
              controller: _page,
              itemCount: widget.images.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (_, index) => ImagePage(
                imageFile: widget.images[index],
                transformationController: _transforms[index],
              ),
            ),
            if (_showBars)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Container(
                    color: Colors.black54,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Expanded(
                          child: Text(
                            widget.images[_currentIndex].name,
                            style: const TextStyle(color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${_currentIndex + 1} / ${widget.images.length}',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        IconButton(
                          icon: const Icon(Icons.share, color: Colors.white),
                          tooltip: 'Share',
                          onPressed: _share,
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white),
                          tooltip: 'Edit',
                          onPressed: _edit,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.white),
                          tooltip: 'Delete',
                          onPressed: _delete,
                        ),
                        IconButton(
                          icon: const Icon(Icons.info_outline, color: Colors.white),
                          tooltip: 'Info',
                          onPressed: _info,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_showBars)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Container(
                    color: Colors.black54,
                    child: ThumbnailStrip(
                      images: widget.images,
                      currentIndex: _currentIndex,
                      onTap: _goToIndex,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
