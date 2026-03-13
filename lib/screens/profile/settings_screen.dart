// Settings screen — app preferences, data management, and account actions.
//
// Consumes:
//   - authProvider: tracking mode toggle + logout
//   - settingsProvider: GPS distance filter + units preference
//   - trackingProvider: clear walking data
//
// Uses ConsumerWidget because we only need ref.watch and ref.read —
// no initState or lifecycle methods needed.
//
// Navigation: pushed from ProfileScreen's gear icon via Navigator.push.
// The AppBar automatically gets a back arrow because this screen was
// pushed onto the navigation stack (not part of the bottom nav tabs).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/tracking_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch providers so the UI rebuilds when values change
    final user = ref.watch(authProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        // No need to add a back button — Navigator.push gives us one
        // automatically. It's called the "leading" widget and Flutter
        // adds a back arrow by default when the screen was pushed.
      ),
      // ListView is better than Column + SingleChildScrollView for
      // settings screens because it handles scrolling natively and
      // is optimised for lists of items. It only renders visible items
      // (though for a short list like ours the difference is minimal).
      body: ListView(
        children: [
          // ==============================
          // SECTION: Tracking
          // ==============================
          _buildSectionHeader('Tracking'),

          // --- Tracking Mode ---
          // SwitchListTile: a ListTile with a toggle switch built in.
          // It combines an icon, title, subtitle, and a Switch widget
          // all in one convenient package.
          //
          // 'value' controls whether the switch is on or off.
          // 'onChanged' fires when the user taps the switch, giving
          // you the new boolean value (true or false).
          //
          // We map: passive = true (switch ON), manual = false (switch OFF)
          // because passive is the "default/recommended" mode.
          SwitchListTile(
            secondary: const Icon(Icons.directions_walk),
            title: const Text('Passive Tracking'),
            subtitle: Text(
              user?.trackingMode == 'passive'
                  ? 'Tracking automatically in background'
                  : 'Manual — start/stop tracking yourself',
            ),
            value: user?.trackingMode == 'passive',
            activeThumbColor: Colors.teal,
            // onChanged receives true (switched ON) or false (switched OFF).
            // We convert that boolean back to our string format.
            //
            // ref.read (not ref.watch) because we're calling a method,
            // not subscribing to changes. This is inside a callback,
            // so ref.watch would be wrong here — watch is only for
            // the build method body.
            onChanged: (bool isPassive) {
              ref.read(authProvider.notifier).setTrackingMode(
                isPassive ? 'passive' : 'manual',
              );
            },
          ),

          const Divider(),

          // ==============================
          // SECTION: GPS
          // ==============================
          _buildSectionHeader('GPS'),

          // --- Distance Filter ---
          // This controls how far (in metres) the user must move before
          // the next GPS update fires. Lower = more updates = more accurate
          // but more battery drain.
          //
          // We use a ListTile for the label and a Slider below it.
          // Slider: a draggable bar that lets the user pick a value
          // between min and max. It calls onChanged continuously as
          // the user drags.
          //
          // 'divisions' splits the range into discrete steps.
          // Range is 3.0 to 15.0, and divisions: 12 means steps of 1m
          // (15 - 3 = 12 steps). Without divisions, the slider would
          // be continuous (any decimal value).
          //
          // 'label' shows a floating tooltip above the slider thumb
          // as the user drags — so they can see the exact value.
          ListTile(
            leading: const Icon(Icons.gps_fixed),
            title: const Text('GPS Distance Filter'),
            subtitle: Text(
              '${settings.distanceFilterMeters.round()}m between updates',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Slider(
              value: settings.distanceFilterMeters,
              min: 3.0,
              max: 15.0,
              divisions: 12,
              label: '${settings.distanceFilterMeters.round()}m',
              activeColor: Colors.teal,
              onChanged: (double value) {
                ref.read(settingsProvider.notifier).setDistanceFilter(value);
              },
            ),
          ),
          // Helper text explaining the trade-off
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Lower = more accurate tracking, higher battery use\n'
                  'Higher = less accurate, better battery life',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 8),

          const Divider(),

          // ==============================
          // SECTION: Display
          // ==============================
          _buildSectionHeader('Display'),

          // --- Units Toggle ---
          // SwitchListTile again — km = true (switch ON), miles = false.
          SwitchListTile(
            secondary: const Icon(Icons.straighten),
            title: const Text('Use Kilometres'),
            subtitle: Text(
              settings.units == 'km'
                  ? 'Distances shown in km'
                  : 'Distances shown in miles',
            ),
            value: settings.units == 'km',
            activeThumbColor: Colors.teal,
            onChanged: (bool isKm) {
              ref.read(settingsProvider.notifier).setUnits(
                isKm ? 'km' : 'miles',
              );
            },
          ),

          const Divider(),

          // ==============================
          // SECTION: Data
          // ==============================
          _buildSectionHeader('Data'),

          // --- Clear Walking Data ---
          // ListTile: a standard Material list row with leading icon,
          // title, subtitle, and an onTap callback.
          //
          // Unlike SwitchListTile, a plain ListTile doesn't have a
          // switch — it's just a tappable row. We use it for actions
          // like "clear data" where there's no on/off state.
          //
          // We show a confirmation dialog before actually clearing,
          // because this is a destructive action the user can't undo.
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.orange),
            title: const Text('Clear Walking Data'),
            subtitle: const Text('Reset all walked segments'),
            onTap: () => _showClearDataDialog(context, ref),
          ),

          const Divider(),

          // ==============================
          // SECTION: Account
          // ==============================
          _buildSectionHeader('Account'),

          // --- Logout ---
          // Another destructive action, so we show a confirmation dialog.
          // The red colour signals "danger" — this is a convention in
          // UI design for irreversible or significant actions.
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Log Out',
              style: TextStyle(color: Colors.red),
            ),
            subtitle: const Text('Sign out of your account'),
            onTap: () => _showLogoutDialog(context, ref),
          ),

          const Divider(),

          // ==============================
          // FOOTER: App Version
          // ==============================
          const SizedBox(height: 24),
          Center(
            child: Text(
              'City Strides v0.14.0',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // --- Section Header ---
  // Reusable widget for the grey section titles above each group.
  //
  // Padding: adds space around a child widget. Unlike margin (which
  // is external space), padding is internal space. Here we use it
  // to indent the section title from the screen edge and add space
  // above it.
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
          // letterSpacing: adds extra space between each character.
          // Common in section headers and labels for a clean look.
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  // --- Clear Data Confirmation Dialog ---
  // showDialog: displays a modal popup over the current screen.
  // The user must interact with it (tap a button) before they can
  // do anything else — that's what "modal" means.
  //
  // AlertDialog: a Material dialog with a title, content, and
  // action buttons. It's the standard way to ask "are you sure?"
  //
  // Navigator.pop(context): closes the dialog (or any pushed screen).
  // When used inside a dialog, it dismisses the dialog.
  // When used on a pushed screen, it goes back to the previous screen.
  void _showClearDataDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Clear Walking Data?'),
          content: const Text(
            'This will reset all your walked segments. '
                'Your profile and settings will be kept.\n\n'
                'This cannot be undone.',
          ),
          actions: [
            // TextButton: a flat button with no background — just text.
            // Used for less prominent actions like "Cancel".
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            // The destructive action button uses red to signal danger.
            TextButton(
              onPressed: () {
                ref.read(trackingProvider.notifier).clearWalkedSegments();
                Navigator.pop(dialogContext);
                // Show a SnackBar confirming the action.
                // We use the outer 'context' (not dialogContext) because
                // the dialog is about to close — its context would be invalid.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Walking data cleared'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text(
                'Clear Data',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- Logout Confirmation Dialog ---
  // Same pattern as clear data dialog, but calls authProvider.logout().
  // After logout, we pop back to the profile screen — later when
  // real auth exists, you'd navigate to the login screen instead.
  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Log Out?'),
          content: const Text(
            'Are you sure you want to log out?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                ref.read(authProvider.notifier).logout();
                Navigator.pop(dialogContext); // Close dialog
                Navigator.pop(context);       // Go back to profile screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Logged out'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text(
                'Log Out',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}