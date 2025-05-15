import 'package:animo/services/firebase_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Import your new tab screens
import 'dashboard/available_produce_tab.dart';
import 'requests/active_requests_tab.dart';
import 'notifications/notifications_tab.dart';
import 'profile/profile_tab.dart';

// Import the screen for adding a buyer request
import 'package:animo/features/buyer/screens/add_buyer_request_screen.dart'; // Assuming this path

class MainBuyerScreen extends StatefulWidget {
  static const String routeName = '/main-buyer';
  const MainBuyerScreen({super.key});

  @override
  State<MainBuyerScreen> createState() => _MainBuyerScreenState();
}

class _MainBuyerScreenState extends State<MainBuyerScreen> {
  int _selectedIndex = 0; // Current selected tab index

  // List of widgets to display for each tab
  static const List<Widget> _widgetOptions = <Widget>[
    AvailableProduceTab(),
    ActiveRequestsTab(),
    NotificationsTab(),
    ProfileTab(),
  ];

  // Titles for the AppBar corresponding to each tab
  static const List<String> _appBarTitles = <String>[
    'Available Produce',
    'My Requests & Suggestions',
    'Notifications',
    'My Profile',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<FirebaseAuthService>(context, listen: false);
    final firebaseUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitles[_selectedIndex]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0), // Adds 8.0 logical pixels of margin to the right
            child: IconButton(
              icon: const Icon(Icons.account_circle_outlined),
              iconSize: 35.0, // Increased icon size
              tooltip: 'Profile',
              onPressed: () {
                _onItemTapped(3); // Index 3 is for the ProfileTab
              },
            ),
          ),
        ],
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(), // Creates a notch for the FAB
        notchMargin: 6.0, // Margin for the notch
        child: SizedBox(
          height: 60.0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              _buildNavItem(Icons.grid_view_rounded, 'Produce', 0),
              _buildNavItem(Icons.search, 'Requests', 1), // Using search icon as per image
              const SizedBox(width: 40), // The space for the FAB
              _buildNavItem(Icons.notifications_outlined, 'Alerts', 2),
              _buildNavItem(Icons.person_outline, 'Profile', 3),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddBuyerRequestScreen()),
          );
        },
        tooltip: 'Make a Produce Request',
        backgroundColor: Colors.redAccent, // Matching the color in the image
        child: const Icon(Icons.add, color: Colors.white),
          shape: const CircleBorder(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked, // Docks the FAB in the center
    );
  }

  // Helper method to build navigation bar items to reduce redundancy
  Widget _buildNavItem(IconData icon, String label, int index) {
    final bool isSelected = _selectedIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index),
        borderRadius: BorderRadius.circular(20), // Optional: for ripple effect shape
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10, // Adjusted for better fit
                color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}