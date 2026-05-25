import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'constants.dart';

enum LogLevel { info, warning, error }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final StackTrace? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.stackTrace,
  });

  @override
  String toString() {
    final ts = timestamp.toIso8601String();
    final lvl = level.name.toUpperCase().padRight(7);
    final stack = stackTrace != null ? '\n$stackTrace' : '';
    return '[$ts] $lvl $message$stack';
  }
}

class LogService {
  LogService._();
  static final instance = LogService._();

  final _entries = <LogEntry>[];
  File? _logFile;
  bool _initialized = false;

  List<LogEntry> get entries => List.unmodifiable(_entries);

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${dir.path}/logs');
      await logsDir.create(recursive: true);
      _logFile = File('${logsDir.path}/app.log');
      await _rotate();
    } catch (_) {
      // If log file setup fails, in-memory logging still works.
    }
  }

  String get logFilePath => _logFile?.path ?? '(not initialized)';

  void info(Object message, [StackTrace? st]) =>
      _record(LogLevel.info, message, st);

  void warning(Object message, [StackTrace? st]) =>
      _record(LogLevel.warning, message, st);

  void error(Object message, [StackTrace? st]) =>
      _record(LogLevel.error, message, st);

  void _record(LogLevel level, Object message, StackTrace? st) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message.toString(),
      stackTrace: st,
    );
    if (_entries.length >= kLogMaxEntries) {
      _entries.removeAt(0);
    }
    _entries.add(entry);
    _writeToFile(entry);
  }

  void _writeToFile(LogEntry entry) {
    final file = _logFile;
    if (file == null) return;
    try {
      file.writeAsStringSync('$entry\n', mode: FileMode.append);
    } catch (_) {}
  }

  Future<void> _rotate() async {
    final file = _logFile;
    if (file == null || !await file.exists()) return;
    final size = await file.length();
    if (size > kLogMaxFileBytes) {
      await file.writeAsString('');
    }
  }

  void clear() {
    _entries.clear();
    _logFile?.writeAsStringSync('');
  }

  // Only for tests — resets state without touching the filesystem.
  void clearForTest() => _entries.clear();
}
