import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

import '../core/crash_logger.dart';
import '../providers/providers.dart';
import '../services/file_scanner.dart';
import '../services/update_service.dart';
import 'viewer_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Future<List<Directory>>? _roots;
  bool _permissionAsked = false;
  String? _lastCrash;

  @override
  void initState() {
    super.initState();
    // Read previous crash log (if any) so we can warn the user once.
    CrashLogger.readLast().then((log) {
      if (!mounted) return;
      setState(() => _lastCrash = log);
    });
    _roots = _safeInit();
  }

  Future<List<Directory>> _safeInit() async {
    try {
      await _requestPermissions();
    } catch (e, st) {
      await CrashLogger.record(e, st, phase: 'requestPermissions');
      // Continue — we'll just show what we can read.
    }

    List<Directory> roots = const [];
    try {
      roots = await FileScanner.availableRoots();
    } catch (e, st) {
      await CrashLogger.record(e, st, phase: 'availableRoots');
    }

    // Fire-and-forget update check; never blocks.
    unawaited(_maybeCheckUpdate());
    return roots;
  }

  Future<void> _requestPermissions() async {
    if (_permissionAsked) return;
    _permissionAsked = true;
    if (!Platform.isAndroid) return;

    // Permission.photos maps to READ_MEDIA_IMAGES on API 33+ and to
    // READ_EXTERNAL_STORAGE on older versions, so it covers both. We
    // intentionally do NOT request Permission.storage because it is
    // deprecated and noisy on Android 13+.
    try {
      await Permission.photos.request();
    } catch (e, st) {
      // Some custom ROMs throw if a permission isn't recognized.
      await CrashLogger.record(e, st, phase: 'Permission.photos.request');
    }
  }

  Future<void> _maybeCheckUpdate() async {
    try {
      final info = await UpdateService.checkForUpdate();
      if (info == null || !info.isNewer || !mounted) return;
      _showUpdateBanner(info);
    } catch (_) {
      // Offline / GitHub down / API rate-limited: silently ignore.
    }
  }

  void _showUpdateBanner(UpdateInfo info) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showMaterialBanner(
      MaterialBanner(
        content: Text(
          'New version ${info.latestVersion} available '
          '(you have ${info.currentVersion}).',
        ),
        actions: [
          TextButton(
            onPressed: () => messenger.hideCurrentMaterialBanner(),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () async {
              messenger.hideCurrentMaterialBanner();
              if (info.apkUrl == null) return;
              messenger.showSnackBar(
                const SnackBar(content: Text('Downloading update…')),
              );
              try {
                await UpdateService.downloadAndInstall(info.apkUrl!);
              } catch (e, st) {
                await CrashLogger.record(e, st, phase: 'update install');
                if (!mounted) return;
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  SnackBar(content: Text('Update failed: $e')),
                );
              }
            },
            child: const Text('Install'),
          ),
        ],
      ),
    );
  }

  void _openFolder(Directory dir) {
    ref.read(selectedFolderProvider.notifier).state = dir;
    ref.read(currentIndexProvider.notifier).state = 0;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ViewerScreen()),
    );
  }

  void _showLastCrash() {
    final log = _lastCrash;
    if (log == null) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Previous crash log'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              log,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await CrashLogger.clear();
              if (!mounted) return;
              setState(() => _lastCrash = null);
              Navigator.of(ctx).pop();
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Viewer'),
        actions: [
          if (_lastCrash != null)
            IconButton(
              tooltip: 'View previous crash',
              icon: const Icon(Icons.warning_amber, color: Colors.amber),
              onPressed: _showLastCrash,
            ),
          IconButton(
            tooltip: 'Check for updates',
            icon: const Icon(Icons.system_update),
            onPressed: _maybeCheckUpdate,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _roots = _safeInit()),
          ),
        ],
      ),
      body: FutureBuilder<List<Directory>>(
        future: _roots,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorState(
              message: snap.error.toString(),
              onRetry: () => setState(() => _roots = _safeInit()),
            );
          }
          final roots = snap.data ?? const [];
          if (roots.isEmpty) {
            return const _EmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: roots.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (_, i) {
              final dir = roots[i];
              return ListTile(
                leading: const Icon(Icons.folder),
                title: Text(p.basename(dir.path)),
                subtitle: Text(dir.path),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openFolder(dir),
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported_outlined, size: 64),
            SizedBox(height: 16),
            Text(
              'No accessible image folders.\n'
              'Grant storage permission in system settings and tap refresh.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            const Text(
              'Could not load image folders.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

