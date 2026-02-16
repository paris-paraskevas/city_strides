// Manages the current user's authentication state.
//
// Currently uses a local hardcoded user (no backend)
// When a backend is added later, only the methods inside
// AuthNotifier need to change - everything else in the app
// that reads the user via authProvider stays the same.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';

// --- StableNotifier ---
// A StableNotifier is a class that:
//   1. Hold a piece of state (in our case. a UserModel?)
//   2. Has methods to change that state
//   3. Automatically notifies listeners when state changes
//
// The "?" after UserModel means the state can be null.
// null = no user logged in, UserModel = user is logged in
class AuthNotifier extends StateNotifier<UserModel?> {
  // super(null) means the initial state is null (no user yet).
  // The app will call loadUser() at startup to create the local user.
  AuthNotifier() : super(null);

  // --- Load user ---
  // For now: creates a hardcoded local user.
  // Later: this would check Firebase/backend for an existing session.
  void loadUser() {
    state = UserModel(
        userId: 'local_user',
        email: 'local@citystrides.app',
        displayName: 'Walker_1',
        trackingMode: 'passive',
        createdAt: DateTime.now(),
    );
  }

  // --- Update profile ---
  // Uses copyWith to create a new UserModel with changed fields.
  // This is why we built copyWith into every model - Riverpod detects
  // state changes by checking if the object reference changed.
  // copyWith creates a NEW object, so Riverpod knows to rebuild the UI.
  void update({
    String? displayName,
    String? bio,
    String? profilePictureUrl,
  }) {
    if(state == null) return; // Safety: can't update if there is no user

    state = state!.copyWith(
      displayName: displayName,
      bio: bio,
      profilePictureUrl: profilePictureUrl,
    );
  }

  // --- Change Tracking Mode ---
  // Switches between 'passive' and 'manual'
  // Separated from updateProfile because tracking mode changes
  // will trigger different behaviour in the tracking provider later.
  void setTrackingMode(String mode) {
    if(state == null)return;
    state = state!.copyWith(trackingMode: mode);
  }

  // --- Logout ---
  // Sets state back to null (no user).
  // Later: would also call Firebase signOut.
  void logout() {
    state = null;
  }
}

// --- Provider ---
// This registers our AuthNotifier with Riverpod so any screen can access it.
//
// Usage from a widget:
//  final user = ref.watch(authProvider); // Gets UserModel?, rebuilds on change
//  ref.read(authProvider.notifier).updateProfile(displayName: 'New Name');
//
// ref.watch = "give me the current value AND rebuild me when it changes"
// ref.read = "give me the current value just once, don't listen for changes"
final authProvider = StateNotifierProvider<AuthNotifier, UserModel?>((ref) {
  return AuthNotifier();
});