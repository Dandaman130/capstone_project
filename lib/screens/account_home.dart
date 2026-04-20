import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/account_login.dart';
import '../models/session_manager.dart';
import '../models/account_gate.dart';
import '../models/user_profile.dart';

class AccountHomePage extends StatefulWidget {
  final AccountLogin user;

  const AccountHomePage({Key? key, required this.user}) : super(key: key);

  @override
  State<AccountHomePage> createState() => _AccountHomePageState();
}

class _AccountHomePageState extends State<AccountHomePage> {
  bool _isVegan = false;
  bool _isVegetarian = false;
  bool _isGlutenFree = false;
  bool _isDairyFree = false;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  //Load from local storage
  Future<void> _loadUserProfile() async {
    // 1. Get access to the device's local storage
    final prefs = await SharedPreferences.getInstance();
    
    // 2. Look for saved preferences (defaults to empty string if nothing is saved yet)
    // We append the userId to the key so if a different user logs in, they get their own settings!
    final savedPrefsString = prefs.getString('dietary_prefs_${widget.user.userId}') ?? '';

    // 3. Update the UI toggles based on what we loaded
    setState(() {
      _isVegan = savedPrefsString.toLowerCase().contains('vegan');
      _isVegetarian = savedPrefsString.toLowerCase().contains('vegetarian');
      _isGlutenFree = savedPrefsString.toLowerCase().contains('gluten-free');
      _isDairyFree = savedPrefsString.toLowerCase().contains('dairy-free');
      
      _isLoading = false;
    });
  }

  // Save to local storage
  Future<void> _savePreferences() async {
    List<String> activePrefs = [];
    if (_isVegan) activePrefs.add('Vegan');
    if (_isVegetarian) activePrefs.add('Vegetarian');
    if (_isGlutenFree) activePrefs.add('Gluten-Free');
    if (_isDairyFree) activePrefs.add('Dairy-Free');

    String finalPreferencesString = activePrefs.isNotEmpty ? activePrefs.join(', ') : 'None';

    // 1. Get access to the device's local storage
    final prefs = await SharedPreferences.getInstance();
    
    // 2. Save the string permanently to the device
    await prefs.setString('dietary_prefs_${widget.user.userId}', finalPreferencesString);

    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Preferences saved: $finalPreferencesString'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Account"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              SessionManager.logout();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AccountGate()),
              );
            }
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.green))
        : SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.green.shade100,
                        child: Icon(Icons.person, size: 36, color: Colors.green.shade800),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Welcome back!",
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              widget.user.email, 
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Dietary Preferences Section
                  Text(
                    "Dietary Preferences",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "We'll use these to highlight products that match your diet.",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  
                  // Toggles Container
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text("Vegan"),
                          secondary: const Icon(Icons.eco_outlined, color: Colors.green),
                          value: _isVegan,
                          onChanged: (bool value) {
                            setState(() { _isVegan = value; });
                          },
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text("Vegetarian"),
                          secondary: const Icon(Icons.local_florist_outlined, color: Colors.lightGreen),
                          value: _isVegetarian,
                          onChanged: (bool value) {
                            setState(() { _isVegetarian = value; });
                          },
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text("Gluten-Free"),
                          secondary: const Icon(Icons.grass_outlined, color: Colors.amber),
                          value: _isGlutenFree,
                          onChanged: (bool value) {
                            setState(() { _isGlutenFree = value; });
                          },
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text("Dairy-Free"),
                          secondary: const Icon(Icons.water_drop_outlined, color: Colors.blue),
                          value: _isDairyFree,
                          onChanged: (bool value) {
                            setState(() { _isDairyFree = value; });
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _savePreferences,
                      child: const Text(
                        "Save Preferences", 
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}