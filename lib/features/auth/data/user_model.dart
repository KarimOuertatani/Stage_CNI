/// Modèle utilisateur FitForge (compte / authentification).
///
/// Correspond au `AccountResponse` du backend (endpoint `GET /auth/me`) :
/// { id, email, fullName, phoneNumber, avatarUrl, role, emailVerified,
///   createdAt, lastLoginAt }.
class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String? phoneNumber;
  final String? avatarUrl;
  final String role;
  final bool emailVerified;
  final DateTime? createdAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.phoneNumber,
    this.avatarUrl,
    this.role = 'ADHERENT',
    this.emailVerified = false,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['fullName'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      role: json['role'] as String? ?? 'ADHERENT',
      emailVerified: json['emailVerified'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'fullName': fullName,
    'phoneNumber': phoneNumber,
    'avatarUrl': avatarUrl,
    'role': role,
    'emailVerified': emailVerified,
    'createdAt': createdAt?.toIso8601String(),
  };
}
