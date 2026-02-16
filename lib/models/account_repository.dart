import '../models/account_login.dart';

class AccountRepository {
  static final List<AccountLogin> _accounts = [];

  static List<AccountLogin> get accounts => _accounts;

  static void addAccount(AccountLogin account) {
    _accounts.add(account);
  }

  static AccountLogin? login(String email, String password) {
    try {
      return _accounts.firstWhere(
            (acc) => acc.email == email && acc.password == password,
      );
    } catch (_) {
      return null;
    }
  }

  static bool emailExists(String email) {
    return _accounts.any((acc) => acc.email == email);
  }
}