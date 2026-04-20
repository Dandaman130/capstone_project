import '../models/account_login.dart';

class SessionManager {
  static AccountLogin? _currentUser;

  static AccountLogin? get currentUser => _currentUser;

  static bool get isLoggedIn => _currentUser != null;

  static void login(AccountLogin user) {
    _currentUser = user;
  }

  static void logout() {
    _currentUser = null;
  }
}