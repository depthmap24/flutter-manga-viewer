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
  File? _logFile;         // internal storage — used by in-app LogScreen
  File? _externalLogFile; // external storage — readable by file manager / USB
  bool _initialized = false;

  List<LogEntry> get entries => List.unmodifiable(_entries);

  /// Path shown in LogScreen subtitle. Prefers the external path so the user
  /// can find the file in a file manager.
  String get logFilePath =>
      _externalLogFile?.path ?? _logFile?.path ?? '(not initialized)';

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Internal log (always available).
    try {
      final dir = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${dir.path}/logs');
      await logsDir.create(recursive: true);
      _logFile = File('${logsDir.path}/app.log');
      await _rotate(_logFile!);
    } catch (_) {}

    // External log — visible in file manager and via USB/MTP.
    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        final logsDir = Directory('${ext.path}/logs');
        await logsDir.create(recursive: true);
        _externalLogFile = File('${logsDir.path}/app.log');
        await _rotate(_externalLogFile!);
        // Replay whatever was already logged before init() finished.
        for (final e in _entries) {
          _appendToFile(_externalLogFile!, e);
        }
      }
    } catch (_) {}
  }

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
    if (_entries.length >= kLogMaxEntries) _entries.removeAt(0);
    _entries.add(entry);
    _appendToFile(_logFile, entry);
    _appendToFile(_externalLogFile, entry);
  }

  void _appendToFile(File? file, LogEntry entry) {
    if (file == null) return;
    try {
      file.writeAsStringSync('$entry\n', mode: FileMode.append);
    } catch (_) {}
  }

  Future<void> _rotate(File file) async {
    if (!await file.exists()) return;
    if (await file.length() > kLogMaxFileBytes) {
      await file.writeAsString('');
    }
  }

  void clear() {
    _entries.clear();
    _logFile?.writeAsStringSync('');
    _externalLogFile?.writeAsStringSync('');
  }

  // Only for tests — resets state without touching the filesystem.
  void clearForTest() => _entries.clear();
}
