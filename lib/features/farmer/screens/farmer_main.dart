import 'package:animo/features/farmer/screens/profile/profile_tab_content.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/farmer_stats.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import 'add_edit_produce_listing_screen.dart';
import 'dashboard/dashboard_tab_content.dart';
import 'listings/all_listings_tab_content.dart';
import 'notifications/notifications_tab_content.dart';

class FarmerMainScreen extends StatefulWidget {
  const FarmerMainScreen({super.key});

  @override
  State<FarmerMainScreen> createState() => _FarmerMainScreenState();
}

class _FarmerMainScreenState extends State<FarmerMainScreen> {
  int _selectedIndex = 0;

  late final FirebaseAuthService _authService;
  late final FirestoreService _firestoreService;
  FarmerStats? _farmerStats; // This will be passed to DashboardTabContent
  bool _isLoadingStats = true;
  String? _statsErrorMessage;

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<FirebaseAuthService>(context, listen: false);
    _firestoreService = Provider.of<FirestoreService>(context, listen: false);
    _fetchFarmerStats();
  }

  Future<void> _fetchFarmerStats() async {
    if (!mounted) return;
    setState(() {
      _isLoadingStats = true;
      _statsErrorMessage = null;
    });
    try {
      if (_authService.currentFirebaseUser?.uid == null) {
        throw Exception("User not authenticated. Cannot fetch stats.");
      }
      final stats = await _firestoreService.getFarmerStats();
      if (!mounted) return;
      setState(() {
        _farmerStats = stats;
        _isLoadingStats = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statsErrorMessage = "Failed to load dashboard data: ${e.toString()}";
        _isLoadingStats = false;
      });
      if (kDebugMode) {
        print("Error fetching farmer stats for shell: $e");
      }
    }
  }

  List<Widget> _buildScreens() {
    // Pass necessary data/services to each tab content widget
    return [
      DashboardTabContent(
        farmerStats: _farmerStats, // Pass fetched stats
        isLoadingStats: _isLoadingStats,
        statsErrorMessage: _statsErrorMessage,
        firestoreService: _firestoreService, // Pass service for real-time history
        firebaseAuthService: _authService,
      ),
      const AllListingsTabContent(),
      const NotificationsTabContent(),
      const ProfileTabContent(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  String _getAppBarTitle(int index) {
    switch (index) {
      case 0: return 'Dashboard';
      case 1: return 'My Listings';
      case 2: return 'Notifications';
      case 3: return 'Profile';
      default: return 'Farmer Dashboard';
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = _buildScreens();
    Widget currentScreen;

    // Map UI index to screens list index (since FAB is not a screen)
    if (_selectedIndex == 0) currentScreen = screens[0];
    else if (_selectedIndex == 1) currentScreen = screens[1];
    else if (_selectedIndex == 2) currentScreen = screens[2]; // UI index 2 maps to screens[2]
    else if (_selectedIndex == 3) currentScreen = screens[3]; // UI index 3 maps to screens[3]
    else currentScreen = screens[0]; // Default

    final String profileImageUrl = _farmerStats != null && _farmerStats!.farmerName.isNotEmpty
        ? 'https://placehold.co/100x100/orange/white?text=${_farmerStats!.farmerName[0].toUpperCase()}'
        : 'https://placehold.co/100x100/grey/white?text=U';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A2E2B),
        elevation: 0,
        title: Text(
          _getAppBarTitle(_selectedIndex),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
                backgroundImage: NetworkImage(profileImageUrl),
                onBackgroundImageError: (exception, stackTrace) {
                  if (kDebugMode) print('Error loading profile image: $exception');
                },
                radius: 20,
              ),
          ),
        ],
      ),
      body: currentScreen,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_authService.currentFirebaseUser != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => AddEditProduceListingScreen(
                  farmerId: _authService.currentFirebaseUser!.uid,
                  farmerName: _authService.currentFirebaseUser!.displayName,
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User not logged in. Cannot add listing.'))
            );
          }
        },
        backgroundColor: const Color(0xFFD95B5B),
        shape: const CircleBorder(),
        tooltip: 'Add New Listing',
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: Colors.white,
        elevation: 10,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              _buildBottomNavItem(icon: Icons.dashboard_outlined, index: 0, label: "Dashboard"), // Changed icon
              _buildBottomNavItem(icon: Icons.list_alt_outlined, index: 1, label: "Listings"),
              const SizedBox(width: 40), // Space for FAB
              _buildBottomNavItem(icon: Icons.notifications_outlined, index: 2, label: "Alerts"),
              _buildBottomNavItem(icon: Icons.person_outline, index: 3, label: "Profile"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({required IconData icon, required int index, required String label}) {
    return IconButton(
      icon: Icon(
        icon,
        color: _selectedIndex == index ? const Color(0xFFD95B5B) : Colors.grey[600],
        size: 28,
      ),
      tooltip: label,
      onPressed: () => _onItemTapped(index),
    );
  }
}