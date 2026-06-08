import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widgets/whiteboard_canvas.dart';
import 'widgets/toolbar.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Custom Whiteboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const WhiteboardPage(),
    );
  }
}

class WhiteboardPage extends StatelessWidget {
  const WhiteboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Board Pro'),
        elevation: 1,
      ),
      body: const Column(
        children: [
          WhiteboardToolbar(),
          Expanded(
            child: WhiteboardCanvas(),
          ),
        ],
      ),
    );
  }
}
