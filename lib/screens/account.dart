/*
Current State 12/13/25 Last Modified v(Alpha 2.2)
-Account Screen - User account and settings
-Renamed from Screen4
*/

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sageGreen,
      appBar: AppBar(
        title: const Text('Account', style: TextStyle(color: AppColors.offWhite)),
        backgroundColor: AppColors.sageGreen,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.offWhite),
      ),
      body: Container(
        // Background with sage green color and vine pattern image overlay
        decoration: BoxDecoration(
          color: AppColors.sageGreen,
          image: DecorationImage(
            image: AssetImage('lib/theme/vinebg.png'),
            fit: BoxFit.none,
            scale: 1.8,
            opacity: 1.0, // Adjust opacity for subtle background effect
          ),
        ),
        child: const Center(
          child: Text(
            'Personal Account Info goes here',
            style: TextStyle(fontSize: 16, color: AppColors.offWhite),
          ),
        ),
      ),
    );
  }
}
