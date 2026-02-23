import 'package:flutter/material.dart';
import 'screens/debug/debug_screen.dart';

class CityStridesApp extends StatelessWidget {
  const CityStridesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'City Strides',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const DebugScreen(),
    );
  }
}