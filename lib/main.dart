/*
Current State 11/3/25 - FAB Navigation Design v2.0
-------------------------------------------------
- Replaced SnakeNavigationBar with BottomAppBar + FAB
- Navigation: Products – Scan – Favorites
- Scan button is centered and prominent
- Account button shown in top-right corner on Products & Favorites
*/

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/scanner.dart';
import 'screens/products.dart';
import 'screens/favorites.dart';
import 'screens/account.dart';
import 'services/local_product_loader.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalProductLoader.load(); // Load local JSON assets
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bottom Nav Demo',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
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
  int _currentIndex = 1;

  final List<Widget> _pages = const [
    Products(),
    Scanner(),
    Favorites(),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //AppBar visible on Products & Favorites
      appBar: (_currentIndex == 0 || _currentIndex == 2)
          ? AppBar(
        title: Text(
          _currentIndex == 0 ? 'Products' : 'Favorites',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Account()),
              );
            },
          ),
        ],
      )
          : null,

      body: _pages[_currentIndex],

      //Floating Scan Button (centered and prominent)
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        elevation: 6,
        tooltip: 'Scan Product',
        onPressed: () => _onTabTapped(1), // Navigate to Scan screen
        child: const Icon(Icons.qr_code_scanner, size: 32, color: Colors.white),
      ),

      //BottomAppBar with notch for the FAB
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: Colors.deepPurple[200],
        height: 64,
        elevation: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Products
            IconButton(
              icon: const Icon(Icons.store),
              iconSize: 28,
              color: _currentIndex == 0 ? Colors.white : Colors.black,
              onPressed: () => _onTabTapped(0),
            ),

            // Space for FAB
            const SizedBox(width: 48),

            // Favorites
            IconButton(
              icon: const Icon(Icons.favorite),
              iconSize: 28,
              color: _currentIndex == 2 ? Colors.white : Colors.black,
              onPressed: () => _onTabTapped(2),
            ),
          ],
        ),
      ),
    );
  }
}
