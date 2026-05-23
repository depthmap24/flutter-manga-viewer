import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imageviewer/main.dart';

void main() {
  testWidgets('ImageViewerApp builds without crashing',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: ImageViewerApp()),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
