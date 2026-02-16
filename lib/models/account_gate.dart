import 'package:flutter/material.dart';
import '../models/session_manager.dart';
import '../screens/account_home.dart';
import '../screens/account.dart'; // where LoginPage is

class AccountGate extends StatelessWidget {
  const AccountGate({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (SessionManager.isLoggedIn) {
      return AccountHomePage(user: SessionManager.currentUser!);
    } else {
      return LoginPage();
    }
  }
}