import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/activity_item.dart';
import '../../../core/models/farmer_stats.dart';
import '../../../core/models/produce_listing.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import 'add_edit_produce_listing_screen.dart';

// Main application widget
class NewFarmerDashboard extends StatelessWidget {
  const NewFarmerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Farmer Dashboard UI',
      theme: ThemeData(
        primarySwatch: Colors.brown,
        fontFamily: 'Poppins', // Example font, replace if needed
        scaffoldBackgroundColor: const Color(0xFFF5F0E8), // Cream background
      ),
      home: StatisticsScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// The main screen widget
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  String _selectedPeriod = 'Day'; // For 'Total'/'Day' toggle
  String? _selectedWeek = 'Week'; // For dropdown

  late final FirebaseAuthService _authService;
  late final FirestoreService _firestoreService;
  FarmerStats? _farmerStats;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<FirebaseAuthService>(context, listen: false);
    _firestoreService = Provider.of<FirestoreService>(context, listen: false);;
    _fetchFarmerStats();
  }

  Future<void> _fetchFarmerStats() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final stats = await _firestoreService.getFarmerStats();
      setState(() {
        _farmerStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to load farmer stats: $e";
        _isLoading = false;
      });
      if (kDebugMode) {
        print("Error fetching farmer stats: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final String profileImageUrl = 'https://placehold.co/100x100/orange/white?text=${_farmerStats!.farmerName.isNotEmpty ? _farmerStats!.farmerName[0].toUpperCase() : "U"}';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A2E2B), // Dark brown
        elevation: 0,
        title: const Text(
          'Statistics', // Could be dynamic e.g., "Farmer Statistics"
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () async {
                  await _authService.signOut();
              },
              child: CircleAvatar(
                backgroundImage: NetworkImage(profileImageUrl),
                onBackgroundImageError: (exception, stackTrace) {
                  // Handle image loading error
                  print('Error loading profile image: $exception');
                },
                radius: 20,
              ),
            )
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildStatisticsCard(context, _farmerStats!),
            _buildUpcomingPaymentsCard(context, _farmerStats!),
            _buildHistorySection(context),
            const SizedBox(height: 80), // Space for FAB and BottomNav
          ],
        ),
      ),
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
        backgroundColor: const Color(0xFFD95B5B), // Accent Red
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
        tooltip: 'Add New Listing', // Tooltip from FarmerDashboardScreen
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
              _buildBottomNavItem(Icons.widgets_outlined, true), // Example: first item selected
              _buildBottomNavItem(Icons.search), // Could be search listings/matches
              const SizedBox(width: 40), // The space for the FAB
              _buildBottomNavItem(Icons.notifications_outlined), // For match suggestions/notifications
              _buildBottomNavItem(Icons.person_outline), // Farmer profile
            ],
          ),
        ),
      ),
    );
  }

  // Builds individual bottom navigation items
  Widget _buildBottomNavItem(IconData icon, [bool isSelected = false]) {
    // In a real app, selection state would be managed
    return IconButton(
      icon: Icon(
        icon,
        color: isSelected ? const Color(0xFFD95B5B) : Colors.grey[600],
        size: 28,
      ),
      onPressed: () {
        // Handle navigation for different sections
      },
    );
  }

  // Builds the top statistics card
  Widget _buildStatisticsCard(BuildContext context, FarmerStats stats) {
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
            // Could be "Last update: [date]" or current period
            'As of ${DateTime.now().day} ${DateTime.now().month}, ${DateTime.now().year}',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            '\$ ${stats.totalListingsValue.toStringAsFixed(2)}', // Displaying total listing value
            style: const TextStyle(
                color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
          ),
          Text(
            '${stats.totalActiveListings} Active Listings', // Displaying active listings count
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: CustomPaint(
              painter: SimplifiedGraphPainter(), // Graph could be adapted for farmer data
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
                if (day == 'Fri')
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
            ))
                .toList(),
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
              // Icon representing suggestions or actions
              child: const Icon(Icons.lightbulb_outline, color: Color(0xFF4A2E2B), size: 28),
            ),
            const SizedBox(width: 16),
            Expanded( // Use Expanded to prevent overflow if text is long
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Match Suggestions', // Changed title
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    // Displaying pending match suggestions count
                    '${stats.pendingMatchSuggestions} pending actions',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            // const Spacer(), // Spacer might not be needed if Expanded is used
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

  Widget _buildHistorySection(BuildContext context /*, FarmerStats stats - This might not be needed if activity comes from stream */) {
    // Access services - ensure these are correctly provided in your widget tree
    final String? currentUserId = _authService.currentFirebaseUser?.uid;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // Align title to the start
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Activity', // Or "Active Listings" if more appropriate
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4A2E2B)),
              ),
              TextButton(
                onPressed: () {
                  // Navigate to full history/activity or listings screen
                },
                child: const Text(
                  'More',
                  style: TextStyle(color: Color(0xFFD95B5B), fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // StreamBuilder now correctly drives the list's content and states
          StreamBuilder<List<ProduceListing>>(
            // Use produceListingService, not firestoreService if that's the renamed class
            stream: currentUserId != null && currentUserId.isNotEmpty
                ? _firestoreService.getFarmerProduceListings() // Assuming getFarmerProduceListings uses currentUserId internally
                : Stream.value([]), // Return empty stream if no user ID
            builder: (context, snapshot) {
              if (currentUserId == null || currentUserId.isEmpty) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('User not identified. Cannot load listings.'),
                ));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                debugPrint("Error in Recent Activity StreamBuilder: ${snapshot.error}");
                debugPrintStack(stackTrace: snapshot.stackTrace);
                return Center(child: Text('Error fetching listings: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No active produce listings found.'), // Updated message
                ));
              }

              final listings = snapshot.data!;
              // Determine the number of items to show, e.g., max 3 or all
              final itemCount = math.min(listings.length, 3); // Show up to 3 items

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: itemCount, // Correct itemCount based on loaded listings
                itemBuilder: (context, index) {
                  final listingItem = listings[index]; // Use the item from the stream's data

                  // Ensure your _buildHistoryItem can handle ProduceListing
                  // or adapt the data passed to it.
                  // The properties you're using (produceCategory.icon, etc.)
                  // seem to align with the ProduceListing model.
                  return _buildHistoryItem(
                    icon: listingItem.produceCategory.icon,
                    // To get a lighter background from the category color:
                    iconBgColor: listingItem.produceCategory.color.withOpacity(0.15),
                    iconColor: listingItem.produceCategory.color, // Icon itself can be the primary color
                    title: listingItem.produceName,
                    subtitle: listingItem.produceCategory.displayName,
                    amountOrStatus: listingItem.status.displayName, // Or price, quantity, etc.
                  );
                },
              );
            },
          )
        ],
      ),
    );
  }

  Widget _buildHistoryItem({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String amountOrStatus, // Changed from 'amount'
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF4A2E2B)),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            amountOrStatus,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF4A2E2B)),
          ),
        ],
      ),
    );
  }
}

// Simplified Custom Painter for the graph - remains unchanged for this update
// In a real app, this could be fed data from FarmerStats
class SimplifiedGraphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintLine1 = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final paintLine2 = Paint()
      ..color = const Color(0xFFD95B5B).withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final paintPoint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.fill;

    final paintVerticalLine = Paint()
      ..color = const Color(0xFFFFD700).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    Path path1 = Path();
    path1.moveTo(0, size.height * 0.6);
    path1.quadraticBezierTo(size.width * 0.25, size.height * 0.4, size.width * 0.5, size.height * 0.65);
    path1.quadraticBezierTo(size.width * 0.75, size.height * 0.9, size.width, size.height * 0.7);
    canvas.drawPath(path1, paintLine1);

    Path path2 = Path();
    path2.moveTo(0, size.height * 0.75);
    path2.quadraticBezierTo(size.width * 0.3, size.height * 0.5, size.width * 0.6, size.height * 0.6);
    path2.quadraticBezierTo(size.width * 0.85, size.height * 0.7, size.width, size.height * 0.4);
    canvas.drawPath(path2, paintLine2);

    double pointX = size.width * (5.5 / 7.0);
    double pointY = size.height * 0.5;

    canvas.drawLine(Offset(pointX, pointY), Offset(pointX, size.height), paintVerticalLine);
    canvas.drawCircle(Offset(pointX, pointY), 5, paintPoint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

