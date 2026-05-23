import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

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
  late Future<List<Directory>> _roots;
  bool _permissionAsked = false;

  @override
  void initState() {
    super.initState();
    _roots = _init();
  }

  Future<List<Directory>> _init() async {
    await _requestPermissions();
    final roots = await FileScanner.availableRoots();
    // Defer update check; fire-and-forget so the UI is never blocked.
    _maybeCheckUpdate();
    return roots;
  }

  Future<void> _requestPermissions() async {
    if (_permissionAsked) return;
    _permissionAsked = true;
    if (Platform.isAndroid) {
      await [Permission.photos, Permission.storage].request();
    }
  }

  Future<void> _maybeCheckUpdate() async {
    try {
      final info = await UpdateService.checkForUpdate();
      if (info == null || !info.isNewer || !mounted) return;
      _showUpdateBanner(info);
    } catch (_) {/* offline / api down: ignore */}
  }

  void _showUpdateBanner(UpdateInfo info) {
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: Text(
          'New version ${info.latestVersion} available '
          '(you have ${info.currentVersion}).',
        ),
        actions: [
          TextButton(
            onPressed: () => ScaffoldMessenger.of(context)
                .hideCurrentMaterialBanner(),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () async {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              if (info.apkUrl == null) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Downloading update…')),
              );
              try {
                await UpdateService.downloadAndInstall(info.apkUrl!);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Viewer'),
        actions: [
          IconButton(
            tooltip: 'Check for updates',
            icon: const Icon(Icons.system_update),
            onPressed: _maybeCheckUpdate,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _roots = _init()),
          ),
        ],
      ),
      body: FutureBuilder<List<Directory>>(
        future: _roots,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final roots = snap.data!;
          if (roots.isEmpty) {
            return const _EmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: roots.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
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
              'No accessible image folders.\nGrant the app storage permission and try again.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
