/*
Current State 12/13/25 Last Modified v(Alpha 2.2)
-Account Screen - User account and settings
-Renamed from Screen4
*/

import 'package:flutter/material.dart';
import '../models/account_login.dart';
import '../theme/app_colors.dart';
import'sign_up.dart';
import '../models/account_repository.dart';
import 'account_home.dart';
import '../models/session_manager.dart';
import '../models/account_gate.dart';

class AccountScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AccountGate();
  }
}

class LoginPage extends StatefulWidget{
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() {
    final email = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    final account = AccountRepository.login(email, password);

    if (account != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login Successful")),
      );

      if (account != null) {
        SessionManager.login(account);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AccountGate()),
        );
      }


    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid email or password")),
      );
    }
  }

  void _goToSignUp() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SignUpPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Account Login"),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            Navigator.pop(context); // Exit button
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Welcome',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 26,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Please log in to your account',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 26),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                height: 49,
                child: ElevatedButton(
                  onPressed: _login,
                  child: const Text(
                    'Log In',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _goToSignUp,
                child: const Text(
                  "Don't have an account? Sign Up",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

