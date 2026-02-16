/*
Account model for user login (for now it's locally stored)
Matches the schema: userId, email, password
*/

class AccountLogin {
  final int userId;
  final String email;
  final String password;

  AccountLogin({
    required this.userId,
    required this.email,
    required this.password,
  });

  factory AccountLogin.fromJson(Map<String, dynamic> json) {
    return AccountLogin(
      userId: json['userId'] as int,
      email: json['email'] ?? '',
      password: json['password'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'email': email,
      'password': password,
    };
  }
}