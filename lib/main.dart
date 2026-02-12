import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: CityStridesApp()));
}

class CityStridesApp extends StatelessWidget {
  const CityStridesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'City Strides',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

// Temporary home screen — will be replaced with proper navigation later
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('City Strides'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const Center(
        child: Text('City Strides is running!'),
      ),
    );
  }
}