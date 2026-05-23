import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'core/crash_logger.dart';
import 'core/theme.dart';
import 'models/image_file.dart';
import 'providers/providers.dart';
import 'screens/error_screen.dart';
import 'screens/home_screen.dart';
import 'screens/viewer_screen.dart';

void main() {
  // Capture any error that escapes the widget tree.
  runZonedGuarded<void>(
    () {
      WidgetsFlutterBinding.ensureInitialized();

      // Route Flutter framework errors to our crash logger AND keep the
      // default presentation so they show up in logcat too.
      final defaultOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        CrashLogger.record(
          details.exceptionAsString(),
          details.stack,
          phase: 'FlutterError.onError',
        );
        defaultOnError?.call(details);
      };

      // Catch async errors that don't reach a Dart catch.
      PlatformDispatcher.instance.onError = (error, stack) {
        CrashLogger.record(error, stack, phase: 'PlatformDispatcher');
        return true; // mark as handled — don't crash the engine
      };

      runApp(const _Bootstrap());
    },
    (error, stack) {
      CrashLogger.record(error, stack, phase: 'runZonedGuarded');
      // As a last resort, swap the running app with the ErrorScreen.
      runApp(_FatalErrorApp(error: error, stack: stack));
    },
  );
}

/// Picks between the real app and the fallback ErrorScreen depending on
/// whether the initial Riverpod/widget-tree build succeeded.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  Object? _bootError;
  StackTrace? _bootStack;
  int _bootGeneration = 0;

  void _recordBootError(Object error, StackTrace stack) {
    CrashLogger.record(error, stack, phase: 'boot');
    setState(() {
      _bootError = error;
      _bootStack = stack;
    });
  }

  void _retry() {
    setState(() {
      _bootError = null;
      _bootStack = null;
      _bootGeneration++;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_bootError != null) {
      return ErrorScreen(
        error: _bootError!,
        stackTrace: _bootStack,
        onRetry: _retry,
      );
    }
    return _SafeAppHost(
      key: ValueKey(_bootGeneration),
      onError: _recordBootError,
    );
  }
}

class _SafeAppHost extends StatelessWidget {
  const _SafeAppHost({super.key, required this.onError});

  final void Function(Object error, StackTrace stack) onError;

  @override
  Widget build(BuildContext context) {
    // Any widget build error inside the app will be caught and bubbled up.
    ErrorWidget.builder = (FlutterErrorDetails details) {
      // We can't easily switch root from inside ErrorWidget; record and
      // render a minimal placeholder so the framework's red screen doesn't
      // appear in release.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onError(
          details.exception,
          details.stack ?? StackTrace.current,
        );
      });
      return Material(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              kDebugMode
                  ? details.exceptionAsString()
                  : 'A widget failed to render.',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      );
    };

    try {
      return const ProviderScope(child: ImageViewerApp());
    } catch (e, st) {
      // Synchronous build error — extremely unlikely but be safe.
      WidgetsBinding.instance.addPostFrameCallback((_) => onError(e, st));
      return Material(
        color: Colors.black,
        child: Center(
          child: Text(
            'Boot failed',
            style: TextStyle(color: Colors.red[200]),
          ),
        ),
      );
    }
  }
}

class _FatalErrorApp extends StatelessWidget {
  const _FatalErrorApp({required this.error, required this.stack});
  final Object error;
  final StackTrace stack;

  @override
  Widget build(BuildContext context) {
    return ErrorScreen(
      error: error,
      stackTrace: stack,
      // Try a full restart by re-running main.
      onRetry: () => runApp(const _Bootstrap()),
    );
  }
}

class ImageViewerApp extends ConsumerStatefulWidget {
  const ImageViewerApp({super.key});

  @override
  ConsumerState<ImageViewerApp> createState() => _ImageViewerAppState();
}

class _ImageViewerAppState extends ConsumerState<ImageViewerApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  AppLinks? _appLinks;
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    // Defer plugin-channel touches until after the first frame so the engine
    // is fully attached. This prevents races where getInitialLink is called
    // before the Android plugin has registered itself.
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupDeepLinks());
  }

  Future<void> _setupDeepLinks() async {
    try {
      _appLinks = AppLinks();
    } catch (e, st) {
      await CrashLogger.record(e, st, phase: 'AppLinks ctor');
      return;
    }

    try {
      final initial = await _appLinks!.getInitialLink();
      if (initial != null) _handleIncomingUri(initial);
    } catch (e, st) {
      await CrashLogger.record(e, st, phase: 'getInitialLink');
    }

    try {
      _linkSub = _appLinks!.uriLinkStream.listen(
        _handleIncomingUri,
        onError: (Object e, StackTrace st) =>
            CrashLogger.record(e, st, phase: 'uriLinkStream onError'),
        cancelOnError: false,
      );
    } catch (e, st) {
      await CrashLogger.record(e, st, phase: 'uriLinkStream.listen');
    }
  }

  void _handleIncomingUri(Uri uri) {
    final path = _resolveFilePath(uri);
    if (path == null) return;
    if (!ImageFile.isSupported(path)) return;
    final file = File(path);
    final folder = file.parent;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
