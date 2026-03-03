import '../models/account_login.dart';

class AccountRepository {
  static final List<AccountLogin> _accounts = [];

  static List<AccountLogin> get accounts => _accounts;

  static void addAccount(AccountLogin account) {
    _accounts.add(account);
  }

  static AccountLogin? login(String username, String password) {
    try {
      return _accounts.firstWhere(
            (acc) => acc.username == username && acc.password == password,
      );
    } catch (_) {
      return null;
    }
  }

  static bool usernameExists(String username) {
    return _accounts.any((acc) => acc.username == username);
  }
}