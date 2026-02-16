/*
Current State 12/13/25 Last Modified v(Alpha 2.2)
-Community Screen - Placeholder for community features
-Now includes navigation buttons to Favorites and Account

Update 02/15/26
-Added articles about health
-Added a share button to the articles
*/

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'package:share_plus/share_plus.dart'; // New Import
import '../theme/app_colors.dart';
import 'favorites.dart';
import 'account.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({Key? key}) : super(key: key);

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint("Could not launch $url");
    }
  }

  // Function to trigger the native share sheet
  void _shareArticle(String title, String url) {
    Share.share('Check out this article: $title \n\n$url');
  }

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
        decoration: const BoxDecoration(
          color: AppColors.sageGreen,
          image: DecorationImage(
            image: AssetImage('lib/theme/vinebg.png'),
            fit: BoxFit.none,
            scale: 1.8,
            opacity: 1.0,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildNavButton(context, Icons.favorite, const FavoritesScreen()),
                  _buildNavButton(context, Icons.person, const AccountScreen()),
                ],
              ),
              const SizedBox(height: 40),
              
              // Article Cards
              _buildArticleCard(
                title: "Healthy Eating",
                subtitle: "Choosing Healthy Foods for a Balanced Diet",
                url: "https://www.helpguide.org/wellness/nutrition/healthy-diet",
              ),
              _buildArticleCard(
                title: "115 Healthy Dinners That Are Ready in 40 Minutes or Less",
                subtitle: "Fast dinners at home!",
                url: "https://www.foodnetwork.com/healthy/packages/healthy-every-week/quick-and-simple/healthy-dinners-in-40-minutes-or-less",
              ),


              const Spacer(),
              const Text(
                'More features coming soon',
                style: TextStyle(fontSize: 14, color: AppColors.offWhite),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton(BuildContext context, IconData icon, Widget screen) {
    return SizedBox(
      width: 70,
      height: 70,
      child: ElevatedButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => screen)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.sageGreen,
          foregroundColor: AppColors.lightTan,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
          padding: const EdgeInsets.all(8),
        ),
        child: Icon(icon, size: 32, color: AppColors.lightTan),
      ),
    );
  }

  Widget _buildArticleCard({required String title, required String subtitle, required String url}) {
    return Card(
      color: Colors.white.withOpacity(0.1),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 20, right: 10, top: 10, bottom: 10),
        title: Text(title, style: const TextStyle(color: AppColors.offWhite, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppColors.lightTan, fontSize: 12)),
        // Trailing Row for two actions
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              icon: const Icon(Icons.share, color: AppColors.lightTan, size: 20),
              onPressed: () => _shareArticle(title, url),
            ),
            IconButton(
              icon: const Icon(Icons.open_in_new, color: AppColors.lightTan, size: 20),
              onPressed: () => _launchURL(url),
            ),
          ],
        ),
        onTap: () => _launchURL(url), // Tapping the whole card still opens the link
      ),
    );
  }
}