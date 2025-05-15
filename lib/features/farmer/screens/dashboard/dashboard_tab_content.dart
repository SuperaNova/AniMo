import 'package:animo/services/firebase_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:provider/provider.dart';

import '../../../../core/models/activity_item.dart';
import '../../../../core/models/farmer_stats.dart';
import '../../../../core/models/produce_listing.dart';
import '../../../../services/firestore_service.dart';
import '../../../../services/produce_listing_service.dart';
import '../common_widgets.dart';
import '../match_requests_screen.dart';

// This widget now holds the content previously in _StatisticsScreenState._buildDashboardContent
class DashboardTabContent extends StatefulWidget {
  final FarmerStats? farmerStats;
  final bool isLoadingStats;
  final String? statsErrorMessage;
  final FirestoreService firestoreService; // For real-time history
  final FirebaseAuthService firebaseAuthService;

  const DashboardTabContent({
    super.key,
    required this.farmerStats,
    required this.isLoadingStats,
    this.statsErrorMessage,
    required this.firestoreService,
    required this.firebaseAuthService
  });

  @override
  State<DashboardTabContent> createState() => _DashboardTabContentState();
}

class _DashboardTabContentState extends State<DashboardTabContent> {
  String _selectedPeriod = 'Day'; // Specific to this tab's content
  String? _selectedWeek = 'Week';  // Specific to this tab's content

  @override
  Widget build(BuildContext context) {
    if (widget.isLoadingStats) {
      return const Center(child: CircularProgressIndicator());
    }
    if (widget.statsErrorMessage != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(widget.statsErrorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16)),
      ));
    }
    if (widget.farmerStats == null) {
      return const Center(child: Text("No farmer data available for dashboard."));
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildStatisticsCard(context, widget.farmerStats!),
          _buildMatchesPromptCard(context, widget.farmerStats!),
          // Use the shared buildRealtimeHistorySection, passing the service
          buildRealtimeHistorySection(context, widget.firebaseAuthService),
          const SizedBox(height: 80), // Space for FAB if content is long
        ],
      ),
    );
  }

  // --- UI Building Methods specific to DashboardTabContent ---
  Widget _buildStatisticsCard(BuildContext context, FarmerStats stats) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: const BoxDecoration(
        color: Color(0xFF4A2E2B),
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
                      setState(() { // This setState is now local to DashboardTabContentState
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
              painter: SimplifiedGraphPainter(), // Defined below or imported
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
        setState(() { // This setState is now local to DashboardTabContentState
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

  Widget _buildMatchesPromptCard(BuildContext context, FarmerStats stats) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const MatchRequestsScreen()),
          );
        },
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
            child: _buildMatchSuggestions(stats)
        ),
      )
    );
  }
}

// --- Graph Painter (Simplified) ---
// This can be in its own file or a shared widgets file too.
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
    double pointX = size.width * (DateTime.now().weekday / 7.0);
    double pointY = size.height * 0.5;
    canvas.drawLine(Offset(pointX, pointY), Offset(pointX, size.height), paintVerticalLine);
    canvas.drawCircle(Offset(pointX, pointY), 5, paintPoint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Widget _buildMatchSuggestions(FarmerStats stats) { // Added BuildContext for potential future use
  // Define colors and icon based on pending actions
  bool noPendingActions = stats.pendingMatchSuggestions <= 0;

  Color iconBackgroundColor;
  Color iconColor;
  IconData iconData;
  String message;

  if (noPendingActions) {
    iconBackgroundColor = Colors.green.shade600;
    iconColor = Colors.white;
    iconData = Icons.check_circle_outline;
    message = 'No pending actions';
  } else {
    iconBackgroundColor = const Color(0xFFFFD700); // Default yellow
    iconColor = const Color(0xFF4A2E2B);       // Default dark brown
    iconData = Icons.lightbulb_outline;        // Default lightbulb icon
    message = '${stats.pendingMatchSuggestions} pending actions';
  }

  return Row(
    children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration( // Use BoxDecoration for dynamic color
          color: iconBackgroundColor, // Apply conditional background color
          shape: BoxShape.circle,
        ),
        child: Icon(
            iconData, // Apply conditional icon
            color: iconColor,
            size: 28
        ),
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
              message, // Display conditional message
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
  );
}

// --- Realtime History Section Builder ---
// This function builds the real-time history/activity list.
// It was previously part of the main screen state but is now a utility function
// or could be part of DashboardTabContent if only used there.
Widget buildRealtimeHistorySection(BuildContext context, FirebaseAuthService authService) {
  final ProduceListingService produceListingService = Provider.of<ProduceListingService>(context);

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Activity',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4A2E2B)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        StreamBuilder<List<ProduceListing>>(
          stream: produceListingService.getFarmerProduceListingsLimited(authService.currentFirebaseUser!.uid, 3),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              if (kDebugMode) {
                print("Error in RealtimeHistory StreamBuilder: ${snapshot.error}");
                print("Stack trace: ${snapshot.stackTrace}");
              }
              return Center(child: Text('Error loading activity: ${snapshot.error?.toString()}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No active produce listings found.'),
              ));
            }
            final listings = snapshot.data!;
            final List<ActivityItem> recentActivities = listings.map((listing) {
              return ActivityItem(
                icon: listing.produceCategory.icon,
                iconBgColor: listing.produceCategory.color.withOpacity(0.15),
                iconColor: listing.produceCategory.color,
                title: listing.produceName,
                subtitle: "${listing.quantity.toStringAsFixed(1)} ${listing.unit} - ${listing.produceCategory.displayName}",
                trailingText: listing.status.displayName,
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
                return buildActivityDisplayItem(
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
