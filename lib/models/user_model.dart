//Represents a user of the City Strides application
//
//This model is backend-agnostic - it converts to/from Json Maps,
// so it works with Firebase, REST APIs or local storage.

class UserModel {
    // --- Fields ---
    // All marked with final for immutability
    final String userId;
    final String displayName;
    final String email;
    final String profilePictureUrl;
    final String bio;
    final String trackingMode; //'passive' or 'manual'
    final DateTime createdAt;

    // --- Constructor ---
    // 'required' means you must provide these when creating a UserModel
    // Fields with defaults are optional - they'll use defaults if not provided.
    UserModel({
        required this.userId,
        required this.email,
        required this.createdAt,
        this.displayName = '',
        this.profilePictureUrl = '',
        this.bio = '',
        this.trackingMode = 'passive',
    });

    // --- Factory Constructor (fromJson) ---
    // Creates a UserModel from a Map (parsed Json).
    // The '??' means if left side null use right side
    // This protects against missing fields in data.
    factory UserModel.fromJson(Map<String, dynamic> json) {
        return UserModel(
            userId: json['userId'] ?? '',
            displayName: json['displayName'] ?? '',
            email: json['email'] ?? '',
            profilePictureUrl: json['profilePictureUrl'] ?? '',
            bio: json['bio'] ?? '',
            trackingMode: json['trackingMode'] ?? 'passive',
            createdAt: json['createdAt'] != null
                ? DateTime.parse(json['createdAt'] as String)
                : DateTime.now(),
        );
    }

    // --- toJson ---
    // Converts this UserModel into a Map that can be sent to any backend
    // or saved to local storage
    Map<String, dynamic> toJson() {
        return {
            'userId': userId,
            'displayName': displayName,
            'email': email,
            'profilePictureUrl': profilePictureUrl,
            'bio': bio,
            'trackingMode': trackingMode,
            'createdAt': createdAt.toIso8601String(),
        };
    }

    // --- copyWith ---
    // Creates a new UserModel with some fields changes
    // Any field you don't specify keeps its current value
    // Example: user.copyWith(displayName: 'New Name')
    UserModel copyWith({
        String? userId,
        String? displayName,
        String? email,
        String? profilePictureUrl,
        String? bio,
        String? trackingMode,
        DateTime? createdAt,
    }) {
        return UserModel(
            userId: userId ?? this.userId,
            displayName: displayName ?? this.displayName,
            email: email ?? this.email,
            profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
            bio: bio ?? this.bio,
            trackingMode: trackingMode ?? this.trackingMode,
            createdAt: createdAt ?? this.createdAt,
        );
    }
}