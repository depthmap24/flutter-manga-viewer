import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../core/crash_logger.dart';
import '../providers/providers.dart';
import '../services/gallery_service.dart';
import '../services/share_service.dart';
import '../services/update_service.dart';
import 'viewer_screen.dart';

class _InitResult {
  _InitResult({required this.albums, required this.needsPermission});
  final List<AssetPathEntity> albums;
  final bool needsPermission;
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Future<_InitResult>? _init;
  String? _lastCrash;

  @override
  void initState() {
    super.initState();
    CrashLogger.readLast().then((log) {
      if (!mounted) return;
      setState(() => _lastCrash = log);
    });
    _init = _safeInit();
  }

  Future<_InitResult> _safeInit() async {
    bool granted = false;
    try {
      granted = await GalleryService.requestPermission();
    } catch (e, st) {
      await CrashLogger.record(e, st, phase: 'requestPermission');
    }
    if (!granted) {
      return _InitResult(albums: const [], needsPermission: true);
    }
    List<AssetPathEntity> albums = const [];
    try {
      albums = await GalleryService.listAlbums();
    } catch (e, st) {
      await CrashLogger.record(e, st, phase: 'listAlbums');
    }
    unawaited(_maybeCheckUpdate());
    return _InitResult(albums: albums, needsPermission: false);
  }

  Future<void> _maybeCheckUpdate() async {
    try {
      final info = await UpdateService.checkForUpdate();
      if (info == null || !info.isNewer || !mounted) return;
      _showUpdateBanner(info);
    } catch (_) {/* offline / rate-limited: ignore */}
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
            onPressed: messenger.hideCurrentMaterialBanner,
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

  void _openAlbum(AssetPathEntity album) {
    ref.read(selectedAlbumProvider.notifier).state = album;
    ref.read(currentIndexProvider.notifier).state = 0;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ViewerScreen()),
    );
  }

  Future<void> _openSystemSettings() async {
    await PhotoManager.openSetting();
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
              await ShareService.shareText(
                log,
                subject: 'Image Viewer crash log',
              );
            },
            child: const Text('Share'),
          ),
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
          if (result == null) return const SizedBox.shrink();
          if (result.needsPermission) {
            return _PermissionState(
              onGrant: _openSystemSettings,
              onRetry: () => setState(() => _init = _safeInit()),
            );
          }
          if (result.albums.isEmpty) {
            return const _EmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: result.albums.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (_, i) {
              final album = result.albums[i];
              return _AlbumTile(
                album: album,
                onTap: () => _openAlbum(album),
              );
            },
          );
        },
      ),
    );
  }
}

class _AlbumTile extends StatefulWidget {
  const _AlbumTile({required this.album, required this.onTap});
  final AssetPathEntity album;
  final VoidCallback onTap;

  @override
  State<_AlbumTile> createState() => _AlbumTileState();
}

class _AlbumTileState extends State<_AlbumTile> {
  int _count = -1;

  @override
  void initState() {
    super.initState();
    widget.album.assetCountAsync.then((c) {
      if (!mounted) return;
      setState(() => _count = c);
    }).catchError((_) {/* leave as -1 */});
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.folder),
      title: Text(widget.album.name),
      subtitle: _count < 0
          ? null
          : Text('$_count ${_count == 1 ? 'image' : 'images'}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: widget.onTap,
    );
  }
}

class _PermissionState extends StatelessWidget {
  const _PermissionState({required this.onGrant, required this.onRetry});
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
            const Icon(Icons.photo_library_outlined, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Image Viewer needs access to your photos to browse and share '
              'them. Tap below to grant the Photos permission.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onGrant,
              icon: const Icon(Icons.settings),
              label: const Text('Grant photo access'),
            ),
            const SizedBox(height: 8),
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
              'No image albums found on this device.',
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
              'Could not load albums.',
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
