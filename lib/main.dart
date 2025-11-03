/*
Current State 9/24/25 Last Modified v(beta 1.0)
Consists of the app startup and bottom nav bar

Update 9/29/25
Snake bar has been implemented, though positioning needs to be fixed slightly
Code still needs to be reformatted
*/

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/screen1.dart';
import 'screens/screen2.dart';
import 'screens/screen3.dart';
import 'screens/screen4.dart';
import 'services/local_product_loader.dart';
import 'package:flutter_snake_navigationbar/flutter_snake_navigationbar.dart';
import { WorkOS } from '@workos-inc/node';

const workos = new WorkOS('v7.72.1');
void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Required for asset loading
  await LocalProductLoader.load();           // Loading sample_products.json
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
        primarySwatch: Colors.blue,
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

  final List<Widget> _pages = const [
    Screen1(),
    Screen2(),
    Screen3(),
    Screen4(),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    //Theme color for snake (keeps color consistent with app theme)
    final Color primary = Theme.of(context).primaryColor;

    return Scaffold(
      body: _pages[_currentIndex],

      //Centered floating Snake Navigation Bar
      bottomNavigationBar: Padding(
        //Creates equal vertical & horizontal distance/padding/whatever
        padding: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 16.0),
        child: SizedBox(
          //Fixed height (need to look into this to fix RenderFlex overflow)
          height: 90,
          child: SnakeNavigationBar.color(
            behaviour: SnakeBarBehaviour.floating,
            snakeShape: SnakeShape.circle,

            //Round
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(24)),
            ),

            //IMPORTANT: Internal padding set to zero so the library distributes
            //items evenly across the full width of this SizedBox.
            padding: EdgeInsets.zero,

            //Inner height of the bar
            height: 64,

            //Color of the bar (can adjust this to whatever, I just like purple :D)
            backgroundColor: Colors.deepPurple[200], //Snakebar background color
            snakeViewColor: primary,              //Color of the snake indicator
            selectedItemColor: Colors.white,      //The color of the icon when it's selected (circled)
            unselectedItemColor: Colors.black,     //The color of the icon when it's not selected

            // Float shadow to emphasize elevation
            shadowColor: Colors.black.withOpacity(0.18),
            elevation: 8,

            // keep labels visible (optional)
            showSelectedLabels: true,
            showUnselectedLabels: true,

            // navigation handling
            currentIndex: _currentIndex,
            onTap: _onTabTapped,

            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.qr_code_scanner),
                label: 'Scan',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.store),
                label: 'Products',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.favorite),
                label: 'Favorites',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Account',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
