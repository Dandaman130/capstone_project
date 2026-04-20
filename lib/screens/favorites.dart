import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Favorites',
          style: TextStyle(color: AppColors.parchment, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.parchment),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: AppColors.forestDeep,
          image: DecorationImage(
            image: AssetImage('lib/theme/vinebg.png'), // Path to your file
            repeat: ImageRepeat.repeat,
            scale: 1.8,
            opacity: 0.18,
          ),
        ),
        child: const SafeArea(
          child: Center(
            child: Text(
              'Your favorites will bloom here.',
              style: TextStyle(color: AppColors.mistGreen, fontStyle: FontStyle.italic),
            ),
          ),
        ),
      ),
    );
  }
}