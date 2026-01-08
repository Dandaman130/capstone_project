/*
Current State 12/13/25 Last Modified v(Alpha 2.2)
-Consists of the app startup and bottom nav bar
-Refactored screen naming for clarity
-Added floating action buttons for Favorites and Account
-Bottom nav now has 3 items: Search, Scan, Community
*/

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/scan.dart'; // ScanScreen
import 'screens/search.dart'; // SearchScreen
import 'screens/community_screen.dart';
import 'services/local_product_loader.dart';
import 'theme/app_colors.dart';
import 'package:flutter_snake_navigationbar/flutter_snake_navigationbar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Required for asset loading
  await LocalProductLoader.load(); // Loading sample_products.json
  runApp(const ProviderScope(child: MyApp()));
}

// void main() => runApp(const ProviderScope(child: MyApp())); // The OG startup func

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bottom Nav Demo',
      theme: ThemeData(
        primaryColor: AppColors.lightTan,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.sageGreen,
          primary: AppColors.sageGreen,
        ),
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const SearchScreen(),
    const ScanScreen(),
    const CommunityScreen(),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sageGreen,
      body: _pages[_currentIndex],

      // Centered floating Snake Navigation Bar
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 16.0),
        child: SizedBox(
          height: 90,
          child: SnakeNavigationBar.color(
            behaviour: SnakeBarBehaviour.floating,
            snakeShape: SnakeShape.circle,

            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(18)),
            ),

            padding: EdgeInsets.zero,

            height: 64,

            backgroundColor: AppColors.lightTan,
            snakeViewColor: AppColors.mutedGreen,
            selectedItemColor: AppColors.softMint,
            unselectedItemColor: AppColors.sageGreen,

            shadowColor: Colors.black.withValues(alpha: 0.18),
            elevation: 8,

            showSelectedLabels: false,
            showUnselectedLabels: false,

            currentIndex: _currentIndex,
            onTap: _onTabTapped,

            items: [
              BottomNavigationBarItem(
                icon: Padding(
                  padding: const EdgeInsets.only(left: 0),
                  child: Icon(Icons.search, size: 38),
                ),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: Icon(Icons.qr_code_scanner, size: 38),
                ),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: Icon(Icons.people, size: 38),
                ),
                label: '',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
