import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/crash_logger.dart';

/// Fallback UI shown when the app's normal startup path threw a fatal error.
/// Lets the user see what happened, copy the trace, wipe caches, or try again.
class ErrorScreen extends StatefulWidget {
  const ErrorScreen({
    super.key,
    required this.error,
    required this.stackTrace,
    required this.onRetry,
  });

  final Object error;
  final StackTrace? stackTrace;

  /// Called when the user taps "Try again". The host is expected to rebuild
  /// the application root.
  final VoidCallback onRetry;

  @override
  State<ErrorScreen> createState() => _ErrorScreenState();
}

class _ErrorScreenState extends State<ErrorScreen> {
  bool _clearing = false;
  String? _persistedLog;

  @override
  void initState() {
    super.initState();
    CrashLogger.readLast().then((value) {
      if (!mounted) return;
      setState(() => _persistedLog = value);
    });
  }

  Future<void> _clearCachesAndRetry() async {
    setState(() => _clearing = true);
    await CrashLogger.clearAppCaches();
    await CrashLogger.clear();
    if (!mounted) return;
    setState(() => _clearing = false);
    widget.onRetry();
  }

  void _copyToClipboard() {
    final buffer = StringBuffer()
      ..writeln(widget.error.toString())
      ..writeln(widget.stackTrace ?? '<no stack>');
    if (_persistedLog != null) {
      buffer
        ..writeln()
        ..writeln('--- previous persisted error ---')
        ..writeln(_persistedLog);
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Error copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB3261E),
          brightness: Brightness.dark,
        ),
        brightness: Brightness.dark,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Something went wrong'),
          actions: [
            IconButton(
              tooltip: 'Copy details',
              icon: const Icon(Icons.copy),
              onPressed: _copyToClipboard,
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'The app failed to start. Tap "Clear cache & retry" to wipe '
                'the temporary cache and try again, or share these details:',
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _formatBody(),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _clearing ? null : widget.onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _clearing ? null : _clearCachesAndRetry,
                      icon: _clearing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cleaning_services),
                      label: const Text('Clear cache & retry'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatBody() {
    final buffer = StringBuffer()
      ..writeln('Error:')
      ..writeln(widget.error)
      ..writeln()
      ..writeln('Stack:')
      ..writeln(widget.stackTrace ?? '<no stack>');
    if (_persistedLog != null) {
      buffer
        ..writeln()
        ..writeln('--- previous persisted error (from disk) ---')
        ..writeln(_persistedLog);
    }
    return buffer.toString();
  }
}
