import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/crash_logger.dart';
import 'core/theme.dart';
import 'screens/error_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runZonedGuarded<void>(
    () {
      WidgetsFlutterBinding.ensureInitialized();

      final defaultOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        CrashLogger.record(
          details.exceptionAsString(),
          details.stack,
          phase: 'FlutterError.onError',
        );
        defaultOnError?.call(details);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        CrashLogger.record(error, stack, phase: 'PlatformDispatcher');
        return true;
      };

      runApp(const _Bootstrap());
    },
    (error, stack) {
      CrashLogger.record(error, stack, phase: 'runZonedGuarded');
      runApp(_FatalErrorApp(error: error, stack: stack));
    },
  );
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  Object? _bootError;
  StackTrace? _bootStack;
  int _gen = 0;

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
      _gen++;
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
    return _SafeAppHost(key: ValueKey(_gen), onError: _recordBootError);
  }
}

class _SafeAppHost extends StatelessWidget {
  const _SafeAppHost({super.key, required this.onError});
  final void Function(Object, StackTrace) onError;

  @override
  Widget build(BuildContext context) {
    ErrorWidget.builder = (FlutterErrorDetails details) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onError(details.exception, details.stack ?? StackTrace.current);
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
      WidgetsBinding.instance.addPostFrameCallback((_) => onError(e, st));
      return Material(
        color: Colors.black,
        child: Center(
          child: Text('Boot failed', style: TextStyle(color: Colors.red[200])),
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
      onRetry: () => runApp(const _Bootstrap()),
    );
  }
}

class ImageViewerApp extends ConsumerWidget {
  const ImageViewerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Image Viewer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
