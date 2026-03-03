import 'package:flutter/material.dart';
import '../models/account_login.dart';
import '../models/session_manager.dart';
import '../models/account_gate.dart';

class AccountHomePage extends StatelessWidget {
  final AccountLogin user;

  const AccountHomePage({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Account"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              SessionManager.logout();

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AccountGate()),
              );
            }
          ),
        ],
      ),
      body: const Center(
        child: Text(
          "Account Home (Coming Soon)",
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
