/*
Current State 12/13/25 Last Modified v(Alpha 2.2)
-Favorites Screen - User's saved/favorited items
-Renamed from Screen3
*/

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: const Text('Favorites', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.sageGreen,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: const Center(
        child: Text(
          'Saved Things & flags go here',
          style: TextStyle(fontSize: 16, color: Colors.black87),
        ),
      ),
    );
  }
}
