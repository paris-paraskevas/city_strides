import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_provider.dart';
import 'screens/debug/debug_screen.dart';
import 'screens/map/map_screen.dart';
import 'screens/home/home_screen.dart';

class CityStridesApp extends ConsumerWidget {
  const CityStridesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    // Load the local user once when the app starts.
    // ref.read (not ref.watch) because we only want to trigger this
    // action once — we don't need to rebuild app.dart when auth state
    // changes. Screens deeper in the tree watch authProvider individually.
    //
    // listenManual lets us call a one-time action during build without
    // causing a rebuild loop. The cleaner alternative is a post-frame
    // callback, which runs after the first frame is drawn.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).loadUser();
    });

    return MaterialApp(
      title: 'City Strides',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}