import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../core/log_service.dart';
import '../providers/providers.dart';

class LogScreen extends ConsumerStatefulWidget {
  const LogScreen({super.key});

  @override
  ConsumerState<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends ConsumerState<LogScreen> {
  final _expanded = <int>{};

  Color _levelColor(LogLevel level) => switch (level) {
        LogLevel.error => Colors.red.shade300,
        LogLevel.warning => Colors.amber.shade300,
        LogLevel.info => Colors.grey.shade400,
      };

  Future<void> _copyAll(List<LogEntry> entries) async {
    final text = entries.reversed.map((e) => e.toString()).join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Logs copied')));
    }
  }

  Future<void> _shareFile() async {
    final path = LogService.instance.logFilePath;
    final file = File(path);
    if (!await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Log file not found')));
      }
      return;
    }
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], subject: 'app.log'),
    );
  }

  void _clear() {
    LogService.instance.clear();
    setState(() => _expanded.clear());
    ref.invalidate(logProvider);
  }

  @override
  Widget build(BuildContext context) {
    final entries = LogService.instance.entries.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy all',
            onPressed: () => _copyAll(entries),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share log file',
            onPressed: _shareFile,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear',
            onPressed: _clear,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                LogService.instance.logFilePath,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: Colors.grey),
              ),
            ),
          ),
        ),
      ),
      body: entries.isEmpty
          ? const Center(child: Text('No log entries yet.'))
          : ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final isExpanded = _expanded.contains(index);
                return InkWell(
                  onTap: () {
                    if (entry.stackTrace != null) {
                      setState(() {
                        if (isExpanded) {
                          _expanded.remove(index);
                        } else {
                          _expanded.add(index);
                        }
                      });
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Chip(
                              label: Text(
                                entry.level.name.toUpperCase(),
                                style: TextStyle(
                                    color: _levelColor(entry.level),
                                    fontSize: 10),
                              ),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${entry.timestamp.hour.toString().padLeft(2, '0')}'
                              ':${entry.timestamp.minute.toString().padLeft(2, '0')}'
                              ':${entry.timestamp.second.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(entry.message,
                            style: TextStyle(
                                fontSize: 12,
                                color: _levelColor(entry.level))),
                        if (isExpanded && entry.stackTrace != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              entry.stackTrace.toString(),
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                  fontFamily: 'monospace'),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
