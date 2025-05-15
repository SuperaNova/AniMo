import 'package:animo/services/firebase_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for SystemUiOverlayStyle
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
  // Note: Consider if these titles accurately reflect the content
  // e.g., AvailableProduceTab now has suggestions.
  static const List<String> _appBarTitles = <String>[
    'Available Produce',
    'My Requests  ',
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
    final colorScheme = Theme.of(context).colorScheme;

    const Color darkBrownHeaderColor = Color(0xFF4A2E2B);

    // AppBar colors now depend on whether index 0 OR 1 is selected
    bool isDarkHeaderTabActive = _selectedIndex == 0 || _selectedIndex == 1;
    Color appBarBackgroundColor = isDarkHeaderTabActive ? darkBrownHeaderColor : colorScheme.surface;
    Color appBarForegroundColor = isDarkHeaderTabActive ? Colors.white : colorScheme.onSurface;
    Brightness statusBarIconBrightness = isDarkHeaderTabActive ? Brightness.light : Brightness.dark;
    Brightness statusBarBrightness = isDarkHeaderTabActive ? Brightness.dark : Brightness.light; // For iOS status bar text/icons

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(_appBarTitles[_selectedIndex],style: TextStyle(fontWeight: FontWeight.bold, color: appBarForegroundColor)),
        backgroundColor: appBarBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: appBarForegroundColor),
        actionsIconTheme: IconThemeData(color: appBarForegroundColor),
        systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: appBarBackgroundColor, // Match status bar background to AppBar
            statusBarIconBrightness: statusBarIconBrightness, // For Android status bar icons
            statusBarBrightness: statusBarBrightness, // For iOS status bar icons
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.account_circle_outlined), // Color will be from actionsIconTheme
              iconSize: 35.0,
              tooltip: 'Profile',
              onPressed: () {
                _onItemTapped(3);
              },
            ),
          ),
        ],
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6.0,
        color: colorScheme.surface, // BottomAppBar is light
        elevation: 8.0,
        child: SizedBox(
          height: 60.0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              _buildNavItem(Icons.grid_view_rounded, 'Produce', 0),
              _buildNavItem(Icons.search, 'Requests', 1),
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
        backgroundColor: Colors.redAccent, // This is the FAB's own color
        child: const Icon(Icons.add, color: Colors.white),
        shape: const CircleBorder(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  // Helper method to build navigation bar items to reduce redundancy
  Widget _buildNavItem(IconData icon, String label, int index) {
    final bool isSelected = _selectedIndex == index;
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index),
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              color: isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.6),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.6),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}