import 'dart:async';
import 'dart:ui';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/log_service.dart';
import 'core/theme.dart';
import 'screens/home_screen.dart';
import 'screens/viewer_screen.dart';
import 'services/gallery_service.dart';

void main() {
  runZonedGuarded<void>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Prevent OOM crashes from full-resolution images filling the cache.
      PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024;

      FlutterError.onError = (details) {
        LogService.instance.error(
            details.exceptionAsString(), details.stack);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        LogService.instance.error(error, stack);
        return true;
      };

      await LogService.instance.init();
      LogService.instance.info('App starting');

      Uri? initialUri;
      try {
        initialUri = await AppLinks().getInitialLink();
        if (initialUri != null) {
          LogService.instance.info('Intent URI: $initialUri');
        }
      } catch (e, st) {
        LogService.instance.warning('Failed to get initial link: $e', st);
      }

      runApp(
        ProviderScope(
          child: ImageViewerApp(initialUri: initialUri),
        ),
      );
    },
    (error, stack) {
      LogService.instance.error(error, stack);
    },
  );
}

class ImageViewerApp extends StatelessWidget {
  final Uri? initialUri;

  const ImageViewerApp({super.key, this.initialUri});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Viewer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: initialUri != null
          ? _IntentLoader(uri: initialUri!)
          : const HomeScreen(),
    );
  }
}

class _IntentLoader extends StatefulWidget {
  final Uri uri;
  const _IntentLoader({required this.uri});

  @override
  State<_IntentLoader> createState() => _IntentLoaderState();
}

class _IntentLoaderState extends State<_IntentLoader> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = GalleryService();
    final result = await svc.loadFromUri(widget.uri);

    if (!mounted) return;

    if (result == null || result.images.isEmpty) {
      LogService.instance.warning('Intent load returned no images');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ViewerScreen(
          images: result.images,
          initialIndex: result.startIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
