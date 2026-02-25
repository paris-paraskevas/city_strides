// Profile screen — displays user info, walking stats summary,
// and a settings button.
//
// Consumes:
//   - authProvider: user details (name, bio, picture, createdAt)
//   - progressProvider: distance walked, segments count
//   - cityProvider: city count (for "cities started" stat)
//
// Uses ConsumerWidget because we only need ref.watch —
// no initState or lifecycle methods needed.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/progress_provider.dart';
import '../../providers/city_provider.dart';
import 'settings_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final progress = ref.watch(progressProvider);
    final cityState = ref.watch(cityProvider);

    // Defensive state: no user loaded yet
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
        ),
        body: const Center(
          child: Text(
            'Loading profile...',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ),
      );
    }

    // Calculate aggregate stats from available data
    // Currently: 1 city max (mock data). Later: loop through all cities.
    final int citiesStarted = cityState.currentCity != null ? 1 : 0;
    final double totalDistanceKm = progress != null
        ? progress.distanceWalkedMeters / 1000
        : 0.0;

    // Format the "member since" date
    // We use day/month/year format since you're in Greece
    final createdDate = '${user.createdAt.day}/'
        '${user.createdAt.month}/'
        '${user.createdAt.year}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          // Settings gear icon — navigates to Settings screen (placeholder)
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navigator.push: adds a new screen on top of the current one.
              // Think of it like stacking cards — the Settings screen goes
              // on top of the Profile screen. The user can go back by
              // pressing the back arrow (which Flutter adds automatically)
              // or swiping back on Android.
              //
              // MaterialPageRoute: wraps the destination screen with
              // Material Design transition animations (slide in from right).
              // The 'builder' parameter is a function that returns the
              // widget to display — in our case, the SettingsScreen.
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // --- Profile Picture ---
            // CircleAvatar is a Flutter widget that displays a circular image.
            // 'radius' sets the size (radius 50 = diameter 100 pixels).
            // If profilePictureUrl is empty, we show a default person icon.
            // Later: when backend exists, use NetworkImage to load real pictures.
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.teal.shade100,
              child: user.profilePictureUrl.isEmpty
                  ? Icon(
                Icons.person,
                size: 50,
                color: Colors.teal.shade700,
              )
                  : null,
              // When profilePictureUrl is not empty, you'd add:
              // backgroundImage: NetworkImage(user.profilePictureUrl),
            ),
            const SizedBox(height: 16),

            // --- Display Name ---
            Text(
              user.displayName.isEmpty ? 'No name set' : user.displayName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),

            // --- Email ---
            Text(
              user.email,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),

            // --- Bio ---
            // Shows the bio text, or a greyed-out placeholder if empty.
            Text(
              user.bio.isEmpty ? 'No bio yet' : user.bio,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: user.bio.isEmpty ? Colors.grey : Colors.black87,
                fontStyle: user.bio.isEmpty ? FontStyle.italic : FontStyle.normal,
              ),
            ),
            const SizedBox(height: 8),

            // --- Member Since ---
            Text(
              'Member since $createdDate',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 32),

            // --- Stats Summary Row ---
            // Three stat cards in a horizontal row.
            // We use Row with Expanded so each card takes equal width.
            //
            // Expanded: tells its child to take up all available space
            // in the Row, divided equally among all Expanded children.
            // Without Expanded, the Row wouldn't know how wide to make
            // each card and could overflow.
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    label: 'Cities',
                    value: '$citiesStarted',
                    icon: Icons.location_city,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    label: 'Distance',
                    value: '${totalDistanceKm.toStringAsFixed(1)} km',
                    icon: Icons.straighten,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    label: 'Streak',
                    value: '—',
                    icon: Icons.local_fire_department,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Reusable stat card ---
  // A small card showing an icon, a value, and a label.
  // Used for Cities, Distance, and Streak.
  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
  }) {
    // Card: a Material widget that gives you a raised surface
    // with rounded corners and a shadow. It's like a container
    // but with built-in elevation (shadow depth).
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: Colors.teal, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}