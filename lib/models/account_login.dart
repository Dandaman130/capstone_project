/*
Account model for user login (for now it's locally stored)
Matches the schema: userId, email, password
*/

class AccountLogin {
  final int userId;
  final String username;
  final String password;

  AccountLogin({
    required this.userId,
    required this.username,
    required this.password,
  });

  factory AccountLogin.fromJson(Map<String, dynamic> json) {
    return AccountLogin(
      userId: json['userId'] as int,
      username: json['username'] ?? '',
      password: json['password'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'password': password,
    };
  }
}