/*
Current State 12/13/25 Last Modified v(Alpha 2.2)
-Community Screen - Placeholder for community features
-Now includes navigation buttons to Favorites and Account
*/

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'favorites.dart';
import 'account.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sageGreen,
      appBar: AppBar(
        title: const Text('Community', style: TextStyle(color: AppColors.offWhite)),
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
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
          children: [
            const SizedBox(height: 20),
            // Row with two square buttons on either side
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Favorites Button (Left)
                SizedBox(
                  width: 70,
                  height: 70,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FavoritesScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sageGreen,
                      foregroundColor: AppColors.lightTan,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                      padding: const EdgeInsets.all(8),
                    ),
                    child: Icon(
                      Icons.favorite,
                      size: 32,
                      color: AppColors.lightTan,
                    ),
                  ),
                ),
                // Account Button (Right)
                SizedBox(
                  width: 70,
                  height: 70,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AccountScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sageGreen,
                      foregroundColor: AppColors.lightTan,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                      padding: const EdgeInsets.all(8),
                    ),
                    child: Icon(
                      Icons.person,
                      size: 32,
                      color: AppColors.lightTan,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            const Text(
              'Community features coming soon',
              style: TextStyle(fontSize: 16, color: AppColors.offWhite),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
