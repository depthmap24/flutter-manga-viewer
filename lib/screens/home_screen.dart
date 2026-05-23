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

class _InitResult {
  _InitResult({required this.roots, required this.needsAllFiles});
  final List<Directory> roots;
  final bool needsAllFiles;
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Future<_InitResult>? _init;
  String? _lastCrash;

  @override
  void initState() {
    super.initState();
    // Read previous crash log (if any) so we can warn the user once.
    CrashLogger.readLast().then((log) {
      if (!mounted) return;
      setState(() => _lastCrash = log);
    });
    _init = _safeInit();
  }

  Future<_InitResult> _safeInit() async {
    bool needsAllFiles = false;
    try {
      needsAllFiles = !await _ensureFileSystemAccess();
    } catch (e, st) {
      await CrashLogger.record(e, st, phase: 'requestPermissions');
    }

    List<Directory> roots = const [];
    try {
      roots = await FileScanner.availableRoots();
    } catch (e, st) {
      await CrashLogger.record(e, st, phase: 'availableRoots');
    }

    // On Android 11+, if we have zero readable roots we almost certainly
    // need MANAGE_EXTERNAL_STORAGE — flag it so the UI offers the settings
    // jump.
    if (roots.isEmpty && Platform.isAndroid) {
      needsAllFiles = true;
    }

    unawaited(_maybeCheckUpdate());
    return _InitResult(roots: roots, needsAllFiles: needsAllFiles);
  }

  /// Returns true when we have enough permission to do filesystem scanning.
  /// On Android 11+ that means MANAGE_EXTERNAL_STORAGE granted. On older
  /// versions Permission.storage / Permission.photos is sufficient.
  Future<bool> _ensureFileSystemAccess() async {
    if (!Platform.isAndroid) return true;

    // Always ask for the photo permission so the picker keeps working even
    // if the user declines all-files-access (we still surface MediaStore on
    // the Pictures/DCIM roots once they exist).
    try {
      await Permission.photos.request();
    } catch (_) {/* swallow */}

    // Check whether we already have all-files-access. permission_handler
    // maps this to MANAGE_EXTERNAL_STORAGE on API 30+ and to legacy
    // READ/WRITE on older Android.
    PermissionStatus status;
    try {
      status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
      }
    } catch (e, st) {
      await CrashLogger.record(e, st, phase: 'manageExternalStorage.request');
      return false;
    }
    return status.isGranted;
  }

  Future<void> _openSystemSettings() async {
    try {
      await openAppSettings();
    } catch (e, st) {
      await CrashLogger.record(e, st, phase: 'openAppSettings');
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
            onPressed: () => setState(() => _init = _safeInit()),
          ),
        ],
      ),
      body: FutureBuilder<_InitResult>(
        future: _init,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorState(
              message: snap.error.toString(),
              onRetry: () => setState(() => _init = _safeInit()),
            );
          }
          final result = snap.data;
          if (result == null || result.roots.isEmpty) {
            return _NoFolderState(
              needsAllFiles: result?.needsAllFiles ?? false,
              onGrant: _openSystemSettings,
              onRetry: () => setState(() => _init = _safeInit()),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: result.roots.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (_, i) {
              final dir = result.roots[i];
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

class _NoFolderState extends StatelessWidget {
  const _NoFolderState({
    required this.needsAllFiles,
    required this.onGrant,
    required this.onRetry,
  });
  final bool needsAllFiles;
  final VoidCallback onGrant;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              needsAllFiles ? Icons.folder_off : Icons.image_not_supported_outlined,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              needsAllFiles
                  ? 'This app needs "All files access" to scan your image folders. '
                      'On Android 11 and newer, regular photo permissions are not '
                      'enough to read /storage/emulated/0/Pictures directly.'
                  : 'No images found in the default folders '
                      '(Pictures, DCIM, Download).',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (needsAllFiles) ...[
              FilledButton.icon(
                onPressed: onGrant,
                icon: const Icon(Icons.settings),
                label: const Text('Grant file access'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Toggle "Allow access to manage all files" on the page that '
                'opens, then come back and tap Retry.',
                style: TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
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

