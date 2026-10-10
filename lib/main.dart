import 'package:flutter/material.dart';

import 'game/ui.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hop\'N Mop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8a5fb0)),
        useMaterial3: true,
      ),
      home: const GameScreen(),
    );
  }
}
