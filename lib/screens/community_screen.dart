import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'favorites.dart';
import 'account.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({Key? key}) : super(key: key);

  // ── Logic ──────────────────────────────────────────────────────────────────

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint("Could not launch $url");
    }
  }

  void _shareArticle(String title, String url) {
    Share.share('Check out this article: $title \n\n$url');
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // We set the Scaffold background to transparent so the Container's
      // vine background is what shines through.
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Community',
          style: TextStyle(
            color: AppColors.parchment,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.parchment),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        // 🌿 Using the vineBackground from your AppTheme
        decoration: AppTheme.vineBackground,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Navigation Row (Centered Buttons)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavButton(
                        context,
                        Icons.favorite_rounded,
                        'Favorites',
                        const FavoritesScreen()
                    ),
                    _buildNavButton(
                        context,
                        Icons.person_rounded,
                        'Account',
                        AccountScreen()
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // Featured Articles
                _buildArticleCard(
                  context,
                  title: "Healthy Eating",
                  subtitle: "Choosing Healthy Foods for a Balanced Diet",
                  url: "https://www.helpguide.org/wellness/nutrition/healthy-diet",
                ),

                _buildArticleCard(
                  context,
                  title: "Quick Healthy Dinners",
                  subtitle: "115 meals ready in 40 minutes or less!",
                  url: "https://www.foodnetwork.com/healthy/packages/healthy-every-week/quick-and-simple/healthy-dinners-in-40-minutes-or-less",
                ),

                const Spacer(),


                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Nav Button Component (Centered Icons) ──────────────────────────────────

  Widget _buildNavButton(BuildContext context, IconData icon, String label, Widget screen) {
    return Column(
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.forestMid,
              foregroundColor: AppColors.agedGold,
              // padding: EdgeInsets.zero removes the default horizontal
              // padding that pushes icons off-center in small buttons.
              padding: EdgeInsets.zero,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.mossGreen.withOpacity(0.3)),
              ),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => screen),
            ),
            // Center ensures the icon is dead-center within the button.
            child: Center(
              child: Icon(icon, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
            label,
            style: const TextStyle(color: AppColors.parchment, fontSize: 12)
        ),
      ],
    );
  }

  // ── Article Card Component ─────────────────────────────────────────────────

  Widget _buildArticleCard(
      BuildContext context, {
        required String title,
        required String subtitle,
        required String url,
      }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppColors.forestMid.withOpacity(0.6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.mossGreen.withOpacity(0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        title: Text(
          title,
          style: const TextStyle(
              color: AppColors.parchment,
              fontWeight: FontWeight.bold,
              fontSize: 16
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            subtitle,
            style: const TextStyle(color: AppColors.mistGreen, fontSize: 13),
          ),
        ),
        trailing: Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: AppColors.agedGold.withOpacity(0.7)
        ),
        onTap: () => _launchURL(url),
      ),
    );
  }
}