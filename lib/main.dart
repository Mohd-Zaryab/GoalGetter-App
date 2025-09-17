// lib/main.dart
import 'package:flutter/material.dart';
import 'package:goalgetter/screens/splash_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GoalGetter',
      theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Poppins'),
      home: const SplashScreen(),
    );
  }
}
