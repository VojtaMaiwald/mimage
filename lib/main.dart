import 'package:flutter/material.dart';
import 'package:mimage/canvas.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mimage',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.redAccent)),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.redAccent, brightness: Brightness.dark),
      ),
      home: const Canvas(),
    );
  }
}
