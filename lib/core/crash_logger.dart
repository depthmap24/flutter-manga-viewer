import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Persists fatal/non-fatal errors to a file in the app's data directory so
/// users can retrieve them after a crash. Never throws.
class CrashLogger {
  CrashLogger._();

  static const String _fileName = 'last_error.log';
  static File? _cachedFile;

  /// Resolves the log file path lazily. Tries application support dir first,
  /// then falls back to a temp dir. Returns `null` if neither is available.
  static Future<File?> _file() async {
    if (_cachedFile != null) return _cachedFile;
    try {
      final dir = await getApplicationSupportDirectory();
      _cachedFile = File(p.join(dir.path, _fileName));
      return _cachedFile;
    } catch (_) {/* fall through */}
    try {
      final dir = await getTemporaryDirectory();
      _cachedFile = File(p.join(dir.path, _fileName));
      return _cachedFile;
    } catch (_) {
      return null;
    }
  }

  /// Writes a single error entry. Overwrites any previous entry — we only
  /// keep the most recent crash so the file never grows unbounded.
  static Future<void> record(
    Object error,
    StackTrace? stack, {
    String? phase,
  }) async {
    final ts = DateTime.now().toIso8601String();
    final phaseStr = phase == null ? '' : '\nphase: $phase';
    final entry = '''
[$ts]$phaseStr
$error
${stack ?? '<no stack>'}
''';
    if (kDebugMode) {
      // ignore: avoid_print
      print('CrashLogger.record:\n$entry');
    }
    try {
      final file = await _file();
      if (file != null) {
        await file.writeAsString(entry, flush: true);
      }
    } catch (_) {/* swallow — never make logging itself crash */}
  }

  /// Returns whatever crash evidence we have: Dart-side error log + native
  /// (Kotlin) crash trace + boot phase markers. Returns null if nothing.
  static Future<String?> readLast() async {
    final buffer = StringBuffer();
    try {
      final file = await _file();
      if (file != null && await file.exists()) {
        buffer
          ..writeln('--- dart side ---')
          ..writeln(await file.readAsString());
      }
    } catch (_) {/* ignore */}
    final native = await readNativeLogs();
    if (native != null) buffer.write(native);
    if (buffer.isEmpty) return null;
    return buffer.toString();
  }

  /// Reads native-side crash + boot trace logs written by the Kotlin
  /// Application class. Returns a concatenated string (or null if neither
  /// file exists). The native side writes to:
  ///   - <internal>/files/native_crash.log
  ///   - <internal>/files/boot_trace.log
  /// and also to the external app-files dir (which is the user-accessible
  /// /sdcard/Android/data/<package>/files/ path).
  static Future<String?> readNativeLogs() async {
    final buffer = StringBuffer();
    try {
      // The Kotlin side writes to ctx.filesDir which on Android is
      // /data/data/<package>/files. The Dart path_provider's
      // getApplicationSupportDirectory() returns a subdir of that, but the
      // raw files are in the *parent* of the support dir.
      final supportDir = await getApplicationSupportDirectory();
      final filesDir = Directory(p.dirname(supportDir.path));
      await _appendIfExists(filesDir, 'native_crash.log', buffer);
      await _appendIfExists(filesDir, 'boot_trace.log', buffer);
    } catch (_) {/* ignore */}
    if (buffer.isEmpty) return null;
    return buffer.toString();
  }

  static Future<void> _appendIfExists(
    Directory dir,
    String name,
    StringBuffer out,
  ) async {
    final file = File(p.join(dir.path, name));
    if (!await file.exists()) return;
    out
      ..writeln('--- $name ---')
      ..writeln(await file.readAsString());
  }

  /// Deletes the persisted error file. Used by the "Clear & Restart" path.
  static Future<void> clear() async {
    try {
      final file = await _file();
      if (file != null && await file.exists()) {
        await file.delete();
      }
    } catch (_) {/* swallow */}
  }

  /// Best-effort cache wipe: deletes contents of getTemporaryDirectory and
  /// getApplicationCacheDirectory. Never throws.
  static Future<void> clearAppCaches() async {
    Future<void> wipe(Future<Directory> Function() getter) async {
      try {
        final dir = await getter();
        if (await dir.exists()) {
          await for (final entity in dir.list(followLinks: false)) {
            try {
              await entity.delete(recursive: true);
            } catch (_) {/* skip uneven perms */}
          }
        }
      } catch (_) {/* skip */}
    }

    await wipe(getTemporaryDirectory);
    try {
      await wipe(getApplicationCacheDirectory);
    } catch (_) {/* some platforms lack this */}
  }
}
