import 'package:flutter/material.dart';
import 'core/theme.dart';

void main() => runApp(const _Placeholder());

class _Placeholder extends StatelessWidget {
  const _Placeholder();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const Scaffold(body: Center(child: Text('Building...'))),
    );
  }
}
