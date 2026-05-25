import 'package:flutter_test/flutter_test.dart';
import 'package:imageviewer/core/log_service.dart';

void main() {
  group('LogService', () {
    setUp(() => LogService.instance.clearForTest());

    test('records info entries', () {
      LogService.instance.info('hello');
      expect(LogService.instance.entries.last.message, 'hello');
      expect(LogService.instance.entries.last.level, LogLevel.info);
    });

    test('records warning entries', () {
      LogService.instance.warning('warn msg');
      expect(LogService.instance.entries.last.level, LogLevel.warning);
    });

    test('records error entries with stack trace', () {
      final st = StackTrace.current;
      LogService.instance.error('oops', st);
      final entry = LogService.instance.entries.last;
      expect(entry.level, LogLevel.error);
      expect(entry.stackTrace, st);
    });

    test('caps in-memory entries at kLogMaxEntries', () {
      for (int i = 0; i < 520; i++) {
        LogService.instance.info('entry $i');
      }
      expect(LogService.instance.entries.length, lessThanOrEqualTo(500));
    });
  });
}
