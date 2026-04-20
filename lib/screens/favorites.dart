/*
Current State 12/13/25 Last Modified v(Alpha 2.2)
- Favorites Screen - User's saved/favorited items
- Integrated with New Botanical Theme (AppColors & AppTheme)
*/

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use forestDeep instead of the old sageGreen
      backgroundColor: AppColors.forestDeep,
      appBar: AppBar(
        title: const Text(
          'Favorites',
          style: TextStyle(color: AppColors.parchment), // Swapped offWhite for parchment
        ),
        backgroundColor: AppColors.forestDeep,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.parchment),
      ),
      body: Container(
        // Reusing the centralized vine background logic from AppTheme
        decoration: AppTheme.vineBackground,
        child: const Center(
          child: Text(
            'Saved Things & flags go here',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.mistGreen, // Mist green looks great for body text on dark green
            ),
          ),
        ),
      ),
    );
  }
}