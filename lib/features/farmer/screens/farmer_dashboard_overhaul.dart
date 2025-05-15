import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/models/activity_item.dart';
import '../../../core/models/farmer_stats.dart';
import '../../../core/models/produce_listing.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../services/produce_listing_service.dart';
import 'add_edit_produce_listing_screen.dart';

// Main application widget
class NewFarmerDashboard extends StatelessWidget {
  const NewFarmerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    // Assuming FirebaseAuthService and FirestoreService are provided higher up
    // For this example, we'll instantiate them directly or they can be provided.
    return MultiProvider(
      providers: [
        Provider<FirebaseAuthService>(create: (_) => FirebaseAuthService()),
        // FirestoreService might depend on FirebaseAuthService for currentUserId
        ProxyProvider<FirebaseAuthService, FirestoreService>(
          update: (context, authService, previousFirestoreService) =>
              FirestoreService(),
        ),
      ],
      child: MaterialApp(
        title: 'Farmer Dashboard UI',
        theme: ThemeData(
          primarySwatch: Colors.brown,
          fontFamily: 'Poppins',
          scaffoldBackgroundColor: const Color(0xFFF5F0E8),
        ),
        home: const StatisticsScreen(), // Changed to const
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  int _selectedIndex = 0; // Index for the currently selected tab

  String _selectedPeriod = 'Day';
  String? _selectedWeek = 'Week';

  late final FirebaseAuthService _authService;
  late final FirestoreService _firestoreService;
  FarmerStats? _farmerStats;
  bool _isLoadingStats = true; // Separate loading for stats
  String? _statsErrorMessage;

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<FirebaseAuthService>(context, listen: false);
    // FirestoreService is now dependent on authService for currentUserId
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
      // Ensure currentUserId is passed or set in FirestoreService
      if (_authService.currentFirebaseUser?.uid == null) {
        throw Exception("User not authenticated. Cannot fetch stats.");
      }
      // If your FirestoreService doesn't automatically use the auth user ID,
      // you might need to ensure it's set, e.g., _firestoreService.currentUserId = _authService.currentFirebaseUser!.uid;
      final stats = await _firestoreService.getFarmerStats();
      if (!mounted) return;
      setState(() {
        _farmerStats = stats;
        _isLoadingStats = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statsErrorMessage = "Failed to load farmer stats: ${e.toString()}";
        _isLoadingStats = false;
      });
      if (kDebugMode) {
        print("Error fetching farmer stats: $e");
      }
    }
  }

  // List of widgets to display for each tab
  // We'll define these as separate methods or classes for clarity
  List<Widget> _buildScreens() {
    return [
      _buildDashboardContent(), // Tab 0: Main statistics content
      const AllListingsScreen(),    // Tab 1: Placeholder for "All Listings"
      // Tab 2 is the FAB, so no screen here
      const NotificationsScreen(),  // Tab 3: Placeholder for "Notifications"
      const ProfileScreen(),        // Tab 4: Placeholder for "Profile"
    ];
  }

  // Method to build the main dashboard content (your existing SingleChildScrollView)
  Widget _buildDashboardContent() {
    if (_isLoadingStats) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_statsErrorMessage != null) {
      return Center(child: Text(_statsErrorMessage!, style: const TextStyle(color: Colors.red)));
    }
    if (_farmerStats == null) {
      return const Center(child: Text("No farmer data available."));
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildStatisticsCard(context, _farmerStats!),
          _buildUpcomingPaymentsCard(context, _farmerStats!),
          _buildHistorySection(context, _firestoreService), // Pass the service instance
          const SizedBox(height: 80),
        ],
      ),
    );
  }


  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Here you could also use Navigator if your tabs represent completely different routes
    // but for simple view switching, managing _selectedIndex is common.
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = _buildScreens();
    // Determine the correct body based on selectedIndex, handling the FAB gap.
    // The actual content for index 0, 1, 2, 3 (mapping to UI buttons 0,1,3,4)
    Widget currentScreen;
    if (_selectedIndex == 0) currentScreen = screens[0]; // Dashboard
    else if (_selectedIndex == 1) currentScreen = screens[1]; // All Listings
    else if (_selectedIndex == 2) currentScreen = screens[2]; // Notifications (mapped from UI button 3)
    else if (_selectedIndex == 3) currentScreen = screens[3]; // Profile (mapped from UI button 4)
    else currentScreen = screens[0]; // Default to dashboard


    final String profileImageUrl = _farmerStats != null && _farmerStats!.farmerName.isNotEmpty
        ? 'https://placehold.co/100x100/orange/white?text=${_farmerStats!.farmerName[0].toUpperCase()}'
        : 'https://placehold.co/100x100/grey/white?text=U';


    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A2E2B),
        elevation: 0,
        title: Text(
          _getAppBarTitle(_selectedIndex), // Dynamic AppBar title
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: GestureDetector(
                onTap: () async {
                  await _authService.signOut();
                  // Potentially navigate to login screen after sign out
                },
                child: CircleAvatar(
                  backgroundImage: NetworkImage(profileImageUrl),
                  onBackgroundImageError: (exception, stackTrace) {
                    if (kDebugMode) print('Error loading profile image: $exception');
                  },
                  radius: 20,
                ),
              )
          ),
        ],
      ),
      body: currentScreen, // Display the selected screen
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
                const SnackBar(content: Text('Error: User not found. Cannot add listing.'))
            );
          }
        },
        backgroundColor: const Color(0xFFD95B5B),
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
        tooltip: 'Add New Listing',
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
              _buildBottomNavItem(icon: Icons.widgets_outlined, index: 0, label: "Dashboard"),
              _buildBottomNavItem(icon: Icons.list_alt_outlined, index: 1, label: "Listings"),
              const SizedBox(width: 40), // The space for the FAB
              _buildBottomNavItem(icon: Icons.notifications_outlined, index: 2, label: "Alerts"),
              _buildBottomNavItem(icon: Icons.person_outline, index: 3, label: "Profile"),
            ],
          ),
        ),
      ),
    );
  }

  String _getAppBarTitle(int index) {
    switch (index) {
      case 0: return 'Statistics';
      case 1: return 'All Listings';
      case 2: return 'Notifications';
      case 3: return 'Profile';
      default: return 'Farmer Dashboard';
    }
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

  // --- Methods for building UI sections (Statistics, Payments, History) ---
  // These methods are largely the same as in your provided code,
  // ensure they use _farmerStats correctly or fetch their own data if needed.

  Widget _buildStatisticsCard(BuildContext context, FarmerStats stats) {
    // Your existing _buildStatisticsCard implementation
    // Ensure it uses the `stats` parameter.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: const BoxDecoration(
        color: Color(0xFF4A2E2B), // Dark brown
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildPeriodToggleItem("Total"),
                  const SizedBox(width: 8),
                  _buildPeriodToggleItem("Day"),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedWeek,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                    dropdownColor: Colors.grey[700],
                    style: const TextStyle(color: Colors.white),
                    items: <String>['Week', 'Month', 'Year']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedWeek = newValue;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'As of ${DateFormat('MMM').format(DateTime.now())} ${DateTime.now().day}, ${DateTime.now().year}',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            '\$ ${stats.totalListingsValue.toStringAsFixed(2)}',
            style: const TextStyle(
                color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
          ),
          Text(
            '${stats.totalActiveListings} Active Listings',
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: CustomPaint(
              painter: SimplifiedGraphPainter(),
              child: Container(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['Sun', 'Mon', 'Tue', 'Web', 'Thu', 'Fri', 'Sat']
                .map((day) => Column(
              children: [
                Text(day, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                if (day == DateFormat('E').format(DateTime.now()))
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    height: 4,
                    width: 4,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFD700),
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    height: 4,
                    width: 1,
                    color: Colors.white.withOpacity(0.5),
                  )
              ],
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodToggleItem(String period) {
    bool isSelected = _selectedPeriod == period;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPeriod = period;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFD95B5B) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: isSelected ? null : Border.all(color: Colors.white.withOpacity(0.5))
        ),
        child: Text(
          period,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingPaymentsCard(BuildContext context, FarmerStats stats) {
    // Your existing _buildUpcomingPaymentsCard implementation
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
            color: const Color(0xFF8C524C),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              )
            ]
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFFFD700),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lightbulb_outline, color: Color(0xFF4A2E2B), size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Match Suggestions',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${stats.pendingMatchSuggestions} pending actions',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  // Use the _buildHistorySection from the flutter_ui_realtime_history artifact
  // Pass the FirestoreService instance to it.
  Widget _buildHistorySection(BuildContext context, FirestoreService firestoreService) {
    // This is where you'd integrate the content of _buildHistorySection
    // from the flutter_ui_realtime_history artifact.
    // For brevity, I'm calling the method from that artifact directly.
    // Ensure that the dependencies (like ActivityItem, ProduceListing, etc.) are available.
    return buildRealtimeHistorySection(context, _authService);
  }
}

// --- Placeholder Screens for Navigation ---
class AllListingsScreen extends StatelessWidget {
  const AllListingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('All Listings Screen', style: TextStyle(fontSize: 24)));
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Notifications Screen', style: TextStyle(fontSize: 24)));
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Profile Screen', style: TextStyle(fontSize: 24)));
  }
}

// --- Graph Painter (Simplified) ---
class SimplifiedGraphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintLine1 = Paint()..color = Colors.white.withOpacity(0.3)..style = PaintingStyle.stroke..strokeWidth = 2.0;
    final paintLine2 = Paint()..color = const Color(0xFFD95B5B).withOpacity(0.7)..style = PaintingStyle.stroke..strokeWidth = 2.5;
    final paintPoint = Paint()..color = const Color(0xFFFFD700)..style = PaintingStyle.fill;
    final paintVerticalLine = Paint()..color = const Color(0xFFFFD700).withOpacity(0.5)..style = PaintingStyle.stroke..strokeWidth = 1.0;
    Path path1 = Path()..moveTo(0, size.height * 0.6)..quadraticBezierTo(size.width * 0.25, size.height * 0.4, size.width * 0.5, size.height * 0.65)..quadraticBezierTo(size.width * 0.75, size.height * 0.9, size.width, size.height * 0.7);
    canvas.drawPath(path1, paintLine1);
    Path path2 = Path()..moveTo(0, size.height * 0.75)..quadraticBezierTo(size.width * 0.3, size.height * 0.5, size.width * 0.6, size.height * 0.6)..quadraticBezierTo(size.width * 0.85, size.height * 0.7, size.width, size.height * 0.4);
    canvas.drawPath(path2, paintLine2);
    double pointX = size.width * (DateTime.now().weekday / 7.0); // Approximate current day
    double pointY = size.height * 0.5;
    canvas.drawLine(Offset(pointX, pointY), Offset(pointX, size.height), paintVerticalLine);
    canvas.drawCircle(Offset(pointX, pointY), 5, paintPoint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- Integration of _buildHistorySection from flutter_ui_realtime_history ---
// This function is essentially the _buildHistorySection from your other artifact,
// adapted to be callable here.
Widget buildRealtimeHistorySection(BuildContext context, FirebaseAuthService authService) {
  final ProduceListingService produceListingService = Provider.of<ProduceListingService>(context, listen: false);

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row( // Keep the title consistent if desired
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Activity',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4A2E2B)),
            ),
            // Removed "More" button for this integration, can be added back if needed
          ],
        ),
        const SizedBox(height: 10),
        StreamBuilder<List<ProduceListing>>(
          stream: produceListingService.getFarmerProduceListings(authService.currentFirebaseUser!.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              debugPrint("Error in RealtimeHistory StreamBuilder: ${snapshot.error}");
              return Center(child: Text('Error: ${snapshot.error?.toString()}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No active produce listings found.'),
              ));
            }
            final listings = snapshot.data!;
            final List<ActivityItem> recentActivities = listings.map((listing) {
              return ActivityItem( // Assuming ActivityItem and ProduceListing models are compatible
                icon: listing.produceCategory.icon,
                iconBgColor: listing.produceCategory.color.withOpacity(0.15),
                iconColor: listing.produceCategory.color,
                title: listing.produceName,
                subtitle: "${listing.quantity.toStringAsFixed(1)} ${listing.unit} - ${listing.produceCategory.displayName}",
                trailingText: "${listing.pricePerUnit.toStringAsFixed(2)} ${listing.currency}",
              );
            }).toList();
            final itemCountToShow = math.min(recentActivities.length, 3);
            if (itemCountToShow == 0) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No recent activity to display.'),
              ));
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: itemCountToShow,
              itemBuilder: (context, index) {
                final activity = recentActivities[index];
                return _buildActivityDisplayItem( // Using the local display item builder
                  icon: activity.icon,
                  iconBgColor: activity.iconBgColor,
                  iconColor: activity.iconColor,
                  title: activity.title,
                  subtitle: activity.subtitle,
                  amountOrStatus: activity.trailingText,
                );
              },
            );
          },
        )
      ],
    ),
  );
}

// Copied from flutter_ui_realtime_history artifact for completeness
Widget _buildActivityDisplayItem({
  required IconData icon,
  required Color iconBgColor,
  required Color iconColor,
  required String title,
  required String subtitle,
  required String amountOrStatus,
}) {
  return Card(
    margin: const EdgeInsets.symmetric(vertical: 4.0),
    elevation: 1.0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: iconBgColor,
        child: Icon(icon, color: iconColor, size: 24),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
      trailing: Text(
        amountOrStatus,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: Color(0xFF4A2E2B)),
      ),
    ),
  );
}