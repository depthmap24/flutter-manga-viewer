import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'core/log_service.dart';
import 'core/theme.dart';
import 'screens/home_screen.dart';
import 'screens/viewer_screen.dart';
import 'services/gallery_service.dart';

void main() {
  // ZERO async work before runApp().
  // Any platform-channel call (path_provider, app_links, permission_handler)
  // before the first frame risks an ANR-kill on slow devices because the
  // platform thread may not be ready to answer yet.
  runZonedGuarded<void>(
    () {
      WidgetsFlutterBinding.ensureInitialized();

      PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024;

      FlutterError.onError = (details) =>
          LogService.instance.error(details.exceptionAsString(), details.stack);
      PlatformDispatcher.instance.onError = (error, stack) {
        LogService.instance.error(error, stack);
        return true;
      };

      runApp(const ProviderScope(child: _AppInit()));
    },
    (error, stack) => LogService.instance.error(error, stack),
  );
}

/// Shown for one frame while async startup work completes, then replaced
/// by the real app. Doing async init here — after the first frame is on
/// screen — means the platform thread is fully ready and ANR is impossible.
class _AppInit extends StatefulWidget {
  const _AppInit();

  @override
  State<_AppInit> createState() => _AppInitState();
}

class _AppInitState extends State<_AppInit> {
  Widget? _next;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    await LogService.instance.init()
        .timeout(const Duration(seconds: 5), onTimeout: () {});
    LogService.instance.info(
        'App started — log: ${LogService.instance.logFilePath}');

    await _loadCrashReport()
        .timeout(const Duration(seconds: 3), onTimeout: () {})
        .catchError((_) {});

    Uri? initialUri;
    try {
      initialUri = await AppLinks()
          .getInitialLink()
          .timeout(const Duration(seconds: 3), onTimeout: () => null);
      if (initialUri != null) {
        LogService.instance.info('Intent URI: $initialUri');
      }
    } catch (e, st) {
      LogService.instance.warning('Failed to get initial link: $e', st);
    }

    if (!mounted) return;
    setState(() {
      _next = MaterialApp(
        title: 'Image Viewer',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: initialUri != null
            ? _IntentLoader(uri: initialUri)
            : const HomeScreen(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return _next ??
        const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          ),
        );
  }
}

Future<void> _loadCrashReport() async {
  final candidates = <File>[];
  try {
    final ext = await getExternalStorageDirectory();
    if (ext != null) {
      candidates.add(File('${ext.path}/imageviewer_crash.txt'));
    }
  } catch (_) {}
  candidates
      .add(File('/storage/emulated/0/Download/imageviewer/imageviewer_crash.txt'));
  try {
    final internal = await getApplicationDocumentsDirectory();
    candidates.add(File('${internal.path}/crash.txt'));
  } catch (_) {}

  for (final f in candidates) {
    try {
      if (await f.exists()) {
        final report = await f.readAsString();
        LogService.instance.error('PREVIOUS CRASH REPORT (${f.path}):\n$report');
        await f.delete();
      }
    } catch (_) {}
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
    final result = await GalleryService().loadFromUri(widget.uri);
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
        builder: (_) =>
            ViewerScreen(images: result.images, initialIndex: result.startIndex),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
}
