import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: GeekPlayerApp()));
}

class GeekPlayerApp extends StatelessWidget {
  const GeekPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeekPlayer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const _HelloScreen(),
    );
  }
}

class _HelloScreen extends StatelessWidget {
  const _HelloScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GeekPlayer')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Hello, GeekPlayer', style: TextStyle(fontSize: 28)),
            SizedBox(height: 8),
            Text('v0.1 scaffold — features pending'),
          ],
        ),
      ),
    );
  }
}
