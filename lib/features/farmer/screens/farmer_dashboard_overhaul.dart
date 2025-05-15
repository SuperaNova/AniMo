import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

import '../../../core/models/produce_listing.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import 'add_edit_produce_listing_screen.dart';

// Placeholder for data models that would come from your services
class FarmerStats {
  final int totalActiveListings;
  final double totalListingsValue;
  final int pendingMatchSuggestions;
  final List<ActivityItem> recentActivity;
  final String farmerName;

  FarmerStats({
    required this.totalActiveListings,
    required this.totalListingsValue,
    required this.pendingMatchSuggestions,
    required this.recentActivity,
    required this.farmerName,
  });
}

class ActivityItem {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String trailingText; // e.g., amount or status

  ActivityItem({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailingText,
  });
}

void main() {
  // Example: In a real app, you'd fetch this data after login or from a state manager
  final sampleFarmerStats = FarmerStats(
    farmerName: "J. Doe", // Example farmer name
    totalActiveListings: 5,
    totalListingsValue: 18840.00,
    pendingMatchSuggestions: 3,
    recentActivity: [
      ActivityItem(
        icon: Icons.eco_outlined,
        iconBgColor: Colors.green.shade100,
        iconColor: Colors.green.shade700,
        title: 'New Listing: Apples',
        subtitle: '100 kg, Grade A',
        trailingText: '+ \$550.00 est.',
      ),
      ActivityItem(
        icon: Icons.handshake_outlined,
        iconBgColor: Colors.blue.shade100,
        iconColor: Colors.blue.shade700,
        title: 'Match Accepted: Carrots',
        subtitle: 'Buyer: FreshMart Inc.',
        trailingText: 'Confirmed',
      ),
      ActivityItem(
        icon: Icons.eco_outlined,
        iconBgColor: Colors.orange.shade100,
        iconColor: Colors.orange.shade700,
        title: 'New Listing: Oranges',
        subtitle: '50 crates, Valencia',
        trailingText: '+ \$1200.00 est.',
      ),
    ],
  );

  runApp(NewFarmerDashboard());
}

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
  final FarmerStats stats = FarmerStats(
    totalActiveListings: 0,
    totalListingsValue: 0,
    pendingMatchSuggestions: 0,
    recentActivity: [
      ActivityItem(
      icon: Icons.eco_outlined,
      iconBgColor: Colors.green.shade100,
      iconColor: Colors.green.shade700,
      title: 'New Listing: Apples',
      subtitle: '100 kg, Grade A',
      trailingText: '+ \$550.00 est.'
    )],
    farmerName: "James Ewican");
  StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  String _selectedPeriod = 'Day'; // For 'Total'/'Day' toggle
  String? _selectedWeek = 'Week'; // For dropdown

  @override
  Widget build(BuildContext context) {
    // In a real app, user data (like profile image) might come from widget.stats or another service
    final authService = Provider.of<FirebaseAuthService>(context, listen: false);
    final String profileImageUrl = 'https://placehold.co/100x100/orange/white?text=${widget.stats.farmerName.isNotEmpty ? widget.stats.farmerName[0].toUpperCase() : "U"}';

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
                  await authService.signOut();
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
            _buildStatisticsCard(context, widget.stats),
            _buildUpcomingPaymentsCard(context, widget.stats),
            _buildHistorySection(context, widget.stats),
            const SizedBox(height: 80), // Space for FAB and BottomNav
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (authService.currentFirebaseUser != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => AddEditProduceListingScreen(
                  farmerId: authService.currentFirebaseUser!.uid,
                  farmerName: authService.currentFirebaseUser!.displayName,
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

  Widget _buildHistorySection(BuildContext context, FarmerStats stats) {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Activity', // Changed title
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4A2E2B)),
              ),
              TextButton(
                onPressed: () {
                  // Navigate to full history/activity screen
                },
                child: const Text(
                  'More',
                  style: TextStyle(color: Color(0xFFD95B5B), fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (stats.recentActivity.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Text("No recent activity.", style: TextStyle(color: Colors.grey)),
            )
          else
            StreamBuilder<List<ProduceListing>>(
              stream: firestoreService.getFarmerProduceListings(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  debugPrint("Error in FarmerDashboard Listings StreamBuilder: ${snapshot.error}");
                  debugPrintStack(stackTrace: snapshot.stackTrace);
                  return Center(child: Text('Error fetching listings: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('You have no active produce listings. Tap + to add one.'),
                  ));
                }

                final listings = snapshot.data!;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: listings.length,
                  itemBuilder: (context, index) {
                    final listing = listings[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                      child: ListTile(
                        title: Text(listing.produceName),
                        subtitle: Text(
                            'Quantity: ${listing.quantity} ${listing.unit}${listing.estimatedWeightKgPerUnit != null ? " (~${(listing.quantity * listing.estimatedWeightKgPerUnit!).toStringAsFixed(1)}kg total)" : ""}\nCategory: ${listing.produceCategory.displayName}${listing.customProduceCategory != null && listing.customProduceCategory!.isNotEmpty ? " (${listing.customProduceCategory})" : ""}\nPrice: ${listing.pricePerUnit} ${listing.currency} per ${listing.unit}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => AddEditProduceListingScreen(
                                        farmerId: listing.farmerId,
                                        farmerName: listing.farmerName,
                                        existingListing: listing
                                    ),
                                  ),
                                );
                              },
                              tooltip: 'Edit Listing',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Listing?'),
                                    content: Text(
                                        'Are you sure you want to delete "${listing.produceName}"?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true && listing.id != null) {
                                  try {
                                    await firestoreService.deleteProduceListing(listing.id!);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Listing deleted successfully.')),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error deleting listing: $e')),
                                      );
                                    }
                                  }
                                }
                              },
                              tooltip: 'Delete Listing',
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
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

