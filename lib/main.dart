import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'core/theme.dart';
import 'models/image_file.dart';
import 'providers/providers.dart';
import 'screens/home_screen.dart';
import 'screens/viewer_screen.dart';

void main() {
  runApp(const ProviderScope(child: ImageViewerApp()));
}

class ImageViewerApp extends ConsumerStatefulWidget {
  const ImageViewerApp({super.key});

  @override
  ConsumerState<ImageViewerApp> createState() => _ImageViewerAppState();
}

class _ImageViewerAppState extends ConsumerState<ImageViewerApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _setupDeepLinks();
  }

  Future<void> _setupDeepLinks() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _handleIncomingUri(initial);
    } catch (_) {/* ignore */}
    _linkSub = _appLinks.uriLinkStream.listen(
      _handleIncomingUri,
      onError: (_) {},
    );
  }

  void _handleIncomingUri(Uri uri) {
    final path = _resolveFilePath(uri);
    if (path == null) return;
    if (!ImageFile.isSupported(path)) return;
    final file = File(path);
    final folder = file.parent;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedFolderProvider.notifier).state = folder;
      _navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => _DeepLinkBootstrap(targetPath: path),
        ),
      );
    });
  }

  String? _resolveFilePath(Uri uri) {
    if (uri.scheme == 'file') return uri.toFilePath();
    if (uri.scheme == 'content') {
      // content:// URIs require ContentResolver — out of scope for v1.
      final segs = uri.pathSegments;
      if (segs.isNotEmpty && ImageFile.isSupported(segs.last)) {
        return segs.last;
      }
      return null;
    }
    if (uri.toString().startsWith('/')) return uri.toString();
    return null;
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Image Viewer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const HomeScreen(),
    );
  }
}

/// Bridges a deep-link target into the viewer at the correct PageView index
/// once the folder scan finishes.
class _DeepLinkBootstrap extends ConsumerWidget {
  const _DeepLinkBootstrap({required this.targetPath});
  final String targetPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(imageListProvider);
    return asyncList.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (list) {
        final index = list.indexWhere((img) => p.equals(img.path, targetPath));
        if (index < 0) {
          return Scaffold(
            appBar: AppBar(title: const Text('Image')),
            body: const Center(child: Text('Image not found in folder.')),
          );
        }
        ref.read(currentIndexProvider.notifier).state = index;
        return ViewerScreen(initialIndex: index);
      },
    );
  }
}
