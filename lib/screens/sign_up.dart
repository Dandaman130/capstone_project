/*
  SignUpPage - Botanical Refactor
  Features: Hardcoded vine background and themed input fields.
*/

import 'package:flutter/material.dart';
import '../models/account_login.dart';
import '../theme/app_colors.dart'; // Ensure this is imported
import '../models/account_repository.dart';

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _signUp() {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Fields cannot be empty"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (AccountRepository.usernameExists(username)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Account already exists"),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    final newAccount = AccountLogin(
      userId: AccountRepository.accounts.length + 1,
      username: username,
      password: password,
    );

    AccountRepository.addAccount(newAccount);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Account created successfully"),
        backgroundColor: AppColors.mossGreen,
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 🌿 Transparent Scaffold to show the Container's background
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          "Create Account",
          style: TextStyle(color: AppColors.parchment, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.parchment),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        // 🌿 Hardcoded Botanical Decoration
        decoration: const BoxDecoration(
          color: AppColors.forestDeep,
          image: DecorationImage(
            image: AssetImage('lib/theme/vinebg.png'),
            repeat: ImageRepeat.repeat,
            scale: 1.8,
            opacity: 0.18,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                    Icons.eco_rounded,
                    size: 60,
                    color: AppColors.agedGold
                ),
                const SizedBox(height: 20),
                const Text(
                  'Join Us',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                    color: AppColors.parchment,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Start your Forage journey',
                  style: TextStyle(fontSize: 16, color: AppColors.mistGreen),
                ),
                const SizedBox(height: 32),

                // Username Field
                _buildTextField(
                  controller: _usernameController,
                  label: 'New Username',
                  icon: Icons.person_add_alt_1_rounded,
                ),
                const SizedBox(height: 16),

                // Password Field
                _buildTextField(
                  controller: _passwordController,
                  label: 'New Password',
                  icon: Icons.password_rounded,
                  obscure: true,
                ),

                const SizedBox(height: 32),

                // Create Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _signUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.agedGold,
                      foregroundColor: AppColors.forestDeep,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Create Account',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Already have an account? Log In",
                    style: TextStyle(color: AppColors.mistGreen),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Textfield helper to keep things clean and consistent
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: AppColors.parchment),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.mistGreen),
        prefixIcon: Icon(icon, color: AppColors.agedGold.withOpacity(0.7)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.mossGreen.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.agedGold),
        ),
        filled: true,
        fillColor: AppColors.forestMid.withOpacity(0.4),
      ),
    );
  }
}