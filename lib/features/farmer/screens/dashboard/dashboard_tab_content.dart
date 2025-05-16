import 'package:animo/services/produce_listing_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:provider/provider.dart';

import '../../../../core/models/farmer_stats.dart';
import '../../../../core/models/order.dart';
import '../../../../core/models/produce_listing.dart';
import '../../../../services/firebase_auth_service.dart';
import '../../../../services/firestore_service.dart';
import '../order/active_orders_screen.dart';
import '../order/order_history_screen.dart';

class DashboardTabContent extends StatefulWidget {
  final FarmerStats? farmerStats;
  final bool isLoadingStats;
  final String? statsErrorMessage;
  final FirebaseAuthService firebaseAuthService;
  final FirestoreService firestoreService;
  final ProduceListingService produceListingService;


  const DashboardTabContent({
    super.key,
    required this.farmerStats,
    required this.isLoadingStats,
    this.statsErrorMessage,
    required this.firestoreService,
    required this.firebaseAuthService,
    required this.produceListingService,
  });

  @override
  State<DashboardTabContent> createState() => _DashboardTabContentState();
}

class _DashboardTabContentState extends State<DashboardTabContent> with SingleTickerProviderStateMixin {
  String _selectedPeriod = 'Day';
  String? _selectedWeek = 'Week';

  late AnimationController _cardAnimationController;
  late Animation<double> _cardFadeAnimation;

  @override
  void initState() {
    super.initState();
    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );

    _cardFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.easeIn,
    ));

    if (widget.farmerStats != null && !widget.isLoadingStats) {
      _cardAnimationController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant DashboardTabContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.farmerStats != null && !widget.isLoadingStats && (oldWidget.farmerStats == null || oldWidget.isLoadingStats)) {
      _cardAnimationController.reset();
      _cardAnimationController.forward();
    }
  }

  @override
  void dispose() {
    _cardAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (widget.isLoadingStats) {
      return Container(
          color: colorScheme.inverseSurface,
          child: Center(child: CircularProgressIndicator(color: colorScheme.surface))
      );
    }
    if (widget.statsErrorMessage != null) {
      return Container(
        color: colorScheme.inverseSurface,
        child: Center(child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(widget.statsErrorMessage!, style: TextStyle(color: colorScheme.error, fontSize: 16)),
        )),
      );
    }
    if (widget.farmerStats == null) {
      return Container(
          color: colorScheme.inverseSurface,
          child: Center(child: Text("No farmer data available for dashboard.", style: TextStyle(color: colorScheme.surface)))
      );
    }

    if (_cardAnimationController.status == AnimationStatus.dismissed) {
      _cardAnimationController.forward();
    }

    return Container(
      color: colorScheme.inverseSurface,
      child: SingleChildScrollView(
        child: Column(
          children: [
            SizeTransition(
              sizeFactor: CurvedAnimation(
                parent: _cardAnimationController,
                curve: Curves.easeOutCubic,
              ),
              axis: Axis.vertical,
              axisAlignment: -1.0,
              child: FadeTransition(
                opacity: _cardFadeAnimation,
                child: _buildStatisticsCard(context, widget.farmerStats!, colorScheme),
              ),
            ),
            Container(
              color: colorScheme.surfaceContainerLow,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildUnifiedOrdersPromptCard(context, widget.firestoreService, colorScheme),
                  _buildRecentCompletedOrdersSection(context, widget.firebaseAuthService, widget.firestoreService, widget.produceListingService, colorScheme),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard(BuildContext context, FarmerStats stats, ColorScheme colorScheme) {
    // ... (Implementation remains the same) ...
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.inverseSurface,
        borderRadius: const BorderRadius.only(
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
                  _buildPeriodToggleItem("Total", colorScheme),
                  const SizedBox(width: 8),
                  _buildPeriodToggleItem("Day", colorScheme),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedWeek,
                    icon: Icon(Icons.keyboard_arrow_down, color: colorScheme.surface),
                    dropdownColor: colorScheme.surfaceContainerHighest,
                    style: TextStyle(color: colorScheme.surface),
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
            style: TextStyle(color: colorScheme.surface.withOpacity(0.7), fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            NumberFormat.currency(locale: Intl.defaultLocale, symbol: '₱', decimalDigits: 2).format(stats.totalListingsValue),
            style: TextStyle(
                color: colorScheme.surface, fontSize: 36, fontWeight: FontWeight.bold),
          ),
          Text(
            '${stats.totalActiveListings} Active Listings',
            style: TextStyle(color: colorScheme.surface.withOpacity(0.8), fontSize: 16),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: CustomPaint(
              painter: SimplifiedGraphPainter(
                  line1Color: colorScheme.surface.withOpacity(0.3),
                  line2Color: colorScheme.tertiary.withOpacity(0.7),
                  pointColor: colorScheme.inversePrimary
              ),
              child: Container(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['Sun', 'Mon', 'Tue', 'Web', 'Thu', 'Fri', 'Sat']
                .map((day) => Column(
              children: [
                Text(day, style: TextStyle(color: colorScheme.surface.withOpacity(0.7), fontSize: 12)),
                if (day == DateFormat('E').format(DateTime.now()))
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    height: 4,
                    width: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.inversePrimary,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    height: 4,
                    width: 1,
                    color: colorScheme.surface.withOpacity(0.5),
                  )
              ],
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodToggleItem(String period, ColorScheme colorScheme) {
    // ... (Implementation remains the same) ...
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
            color: isSelected ? colorScheme.tertiary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: isSelected ? null : Border.all(color: colorScheme.surface.withOpacity(0.5))
        ),
        child: Text(
          period,
          style: TextStyle(
            color: colorScheme.surface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildUnifiedOrdersPromptCard(BuildContext context, FirestoreService firestoreService, ColorScheme colorScheme) {
    // ... (Implementation remains the same) ...
    return StreamBuilder<int>(
      stream: firestoreService.watchPendingConfirmationOrdersCount(),
      initialData: widget.farmerStats?.pendingConfirmationOrdersCount ?? 0,
      builder: (context, pendingSnapshot) {
        int pendingOrdersCount = widget.farmerStats?.pendingConfirmationOrdersCount ?? 0;
        if (pendingSnapshot.hasData) {
          pendingOrdersCount = pendingSnapshot.data!;
        } else if (pendingSnapshot.hasError && kDebugMode) {
          print("Error in PendingOrdersStream (Unified Card): ${pendingSnapshot.error}");
        }

        if (pendingOrdersCount > 0) {
          return _buildPromptCardContent(
            context: context,
            colorScheme: colorScheme,
            title: 'Orders to Confirm',
            count: pendingOrdersCount,
            messageSuffix: 'orders to confirm',
            iconData: Icons.pending_actions_outlined,
            cardColor: colorScheme.tertiaryContainer,
            iconBgColor: colorScheme.tertiary,
            iconColor: colorScheme.onTertiary,
            textColor: colorScheme.onTertiaryContainer,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ActiveOrdersScreen()),
              );
            },
          );
        } else {
          return StreamBuilder<int>(
            stream: firestoreService.watchActiveInProgressOrdersCount(),
            initialData: widget.farmerStats?.activeInProgressOrdersCount ?? 0,
            builder: (context, activeSnapshot) {
              int activeOrdersCount = widget.farmerStats?.activeInProgressOrdersCount ?? 0;
              if (activeSnapshot.hasData) {
                activeOrdersCount = activeSnapshot.data!;
              } else if (activeSnapshot.hasError && kDebugMode) {
                print("Error in ActiveOrdersStream (Unified Card): ${activeSnapshot.error}");
              }

              if (activeOrdersCount > 0) {
                return _buildPromptCardContent(
                  context: context,
                  colorScheme: colorScheme,
                  title: 'Active Orders',
                  count: activeOrdersCount,
                  messageSuffix: 'active orders',
                  iconData: Icons.local_shipping_outlined,
                  cardColor: colorScheme.secondaryContainer,
                  iconBgColor: colorScheme.secondary,
                  iconColor: colorScheme.onSecondary,
                  textColor: colorScheme.onSecondaryContainer,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const ActiveOrdersScreen()),
                    );
                  },
                );
              } else {
                return _buildPromptCardContent(
                    context: context,
                    colorScheme: colorScheme,
                    title: 'Order Updates',
                    count: 0,
                    messageSuffix: 'No pending or active orders',
                    iconData: Icons.playlist_add_check_circle_outlined,
                    cardColor: colorScheme.primaryContainer.withOpacity(0.7),
                    iconBgColor: colorScheme.primary,
                    iconColor: colorScheme.onPrimary,
                    textColor: colorScheme.onPrimaryContainer,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const ActiveOrdersScreen()),
                      );
                    }
                );
              }
            },
          );
        }
      },
    );
  }

  Widget _buildPromptCardContent({
    required BuildContext context,
    required ColorScheme colorScheme,
    required String title,
    required int count,
    required String messageSuffix,
    required IconData iconData,
    required Color cardColor,
    required Color iconBgColor,
    required Color iconColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    // ... (Implementation remains the same) ...
    String message = count <= 0 ? messageSuffix : '$count $messageSuffix';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16,16,16,8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ]
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, color: iconColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: TextStyle(
                          color: textColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: textColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_forward_ios, color: textColor, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentCompletedOrdersSection(BuildContext context, FirebaseAuthService authService, FirestoreService firestoreService, ProduceListingService produceListingService, ColorScheme colorScheme) {
    final String? currentUserId = authService.currentFirebaseUser?.uid;
    if (currentUserId == null) {
      return Center(child: Text("User not authenticated for recent activity.", style: TextStyle(color: colorScheme.onSurfaceVariant)));
    }
    Stream<List<Order>> stream = firestoreService.getFarmerOrders();

    return Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
        child: Container(
          padding: const EdgeInsets.all(16.0), // Inner padding for the card content
          decoration: BoxDecoration(
              color: colorScheme.surfaceContainer, // Card background
              borderRadius: const BorderRadius.all(Radius.circular(20))
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recently Completed Orders',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant),
                  ),
                  // --- ADDED "View All" BUTTON ---
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const OrderHistoryScreen()),
                      );
                    },
                    child: Text(
                      'View All',
                      style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              StreamBuilder<List<Order>>(
                stream: stream,
                builder: (context, orderSnapshot) {
                  if (orderSnapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: colorScheme.primary));
                  }
                  if (orderSnapshot.hasError) {
                    if (kDebugMode) {
                      print("Error in RecentCompletedOrders StreamBuilder: ${orderSnapshot.error}");
                    }
                    return Center(child: Text('Error loading orders: ${orderSnapshot.error?.toString()}', style: TextStyle(color: colorScheme.error)));
                  }
                  if (!orderSnapshot.hasData || orderSnapshot.data!.isEmpty) {
                    return Center(child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('No orders found yet.', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                    ));
                  }

                  List<Order> completedOrders = orderSnapshot.data!
                      .where((order) => order.status == OrderStatus.completed)
                      .toList();

                  completedOrders.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));

                  if (completedOrders.isEmpty) {
                    return Center(child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('No recent completed orders.', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                    ));
                  }

                  final itemCountToShow = math.min(completedOrders.length, 3);

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: itemCountToShow,
                    itemBuilder: (context, index) {
                      final order = completedOrders[index];
                      return FutureBuilder<ProduceListing?>(
                        future: produceListingService.getProduceListingById(order.produceListingId),
                        builder: (context, listingSnapshot) {
                          ProduceListing? produceListing = listingSnapshot.data;
                          return _buildCompletedOrderItem(
                            context: context,
                            order: order,
                            produceListing: produceListing,
                            colorScheme: colorScheme,
                          );
                        },
                      );
                    },
                  );
                },
              )
            ],
          ),
        )
    );
  }

  Widget _buildCompletedOrderItem({
    required BuildContext context,
    required Order order,
    required ProduceListing? produceListing,
    required ColorScheme colorScheme,
  }) {
    // ... (Implementation remains the same) ...
    final DateFormat dateFormat = DateFormat('MMM d, yy'); // Slightly shorter date
    final String completedDateString =  dateFormat.format(order.lastUpdated);

    IconData itemIcon = produceListing?.produceCategory.icon ?? Icons.inventory_2_outlined;
    Color itemIconColor = produceListing?.produceCategory.color ?? colorScheme.onSurfaceVariant;
    Color itemIconBgColor = (produceListing?.produceCategory.color ?? colorScheme.surfaceVariant).withOpacity(0.15);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      elevation: 0.0, // Flat design within the parent card
      color: Colors.transparent, // Transparent as parent card has color
      // color: colorScheme.surface, // Or a slightly different surface if desired
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
        // side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)) // Optional border
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0), // Adjusted padding
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: itemIconBgColor,
              child: Icon(itemIcon, color: itemIconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    produceListing?.produceName ?? order.produceName,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: colorScheme.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Qty: ${order.orderedQuantity.toStringAsFixed(1)} ${order.unit}',
                    style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  NumberFormat.currency(locale: Intl.defaultLocale, symbol: '${order.currency} ', decimalDigits: 2).format(order.totalOrderAmount),
                  style: TextStyle(fontSize: 14, color: colorScheme.primary, fontWeight: FontWeight.bold),
                ),
                Text(
                  completedDateString,
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SimplifiedGraphPainter extends CustomPainter {
  final Color line1Color;
  final Color line2Color;
  final Color pointColor;

  SimplifiedGraphPainter({
    this.line1Color = Colors.white54,
    this.line2Color = Colors.redAccent,
    this.pointColor = Colors.amber,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintLine1 = Paint()..color = line1Color..style = PaintingStyle.stroke..strokeWidth = 2.0;
    final paintLine2 = Paint()..color = line2Color..style = PaintingStyle.stroke..strokeWidth = 2.5;
    final paintPoint = Paint()..color = pointColor..style = PaintingStyle.fill;
    final paintVerticalLine = Paint()..color = pointColor.withOpacity(0.5)..style = PaintingStyle.stroke..strokeWidth = 1.0;

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
  bool shouldRepaint(covariant SimplifiedGraphPainter oldDelegate) =>
      line1Color != oldDelegate.line1Color ||
          line2Color != oldDelegate.line2Color ||
          pointColor != oldDelegate.pointColor;
}
