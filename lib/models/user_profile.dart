/*Model to handle user profiles after they're logged in
Matches schema: UUID, workos_user_id, dietary_prefrences, created_at
 */

class UserProfile {
  final String uuid;
  final String workosUserId;
  final String dietaryPreferences;
  final DateTime createdAt;

  UserProfile({
    required this.uuid,
    required this.workosUserId,
    required this.dietaryPreferences,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uuid: json['uuid'] ?? '',
      workosUserId: json['workos_user_id'] ?? '',
      dietaryPreferences: json['dietary_preferences'] ?? 'None',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'workos_user_id': workosUserId,
      'dietary_preferences': dietaryPreferences,
      'created_at': createdAt.toIso8601String(),
    };
  }
}