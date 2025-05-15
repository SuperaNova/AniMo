import 'dart:math' as math;

import 'package:animo/services/produce_listing_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/models/order.dart';
import '../../../core/models/produce_listing.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import 'common_widgets.dart';

class ActiveOrdersScreen extends StatefulWidget {
  const ActiveOrdersScreen({super.key});

  // If you navigate to this screen using named routes, define routeName:
  // static const String routeName = '/active-orders';

  @override
  State<ActiveOrdersScreen> createState() => _ActiveOrdersScreenState();
}

class _ActiveOrdersScreenState extends State<ActiveOrdersScreen> {
  late final FirestoreService _firestoreService;
  late final ProduceListingService _produceListingService;
  late final String? _currentUserId;

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<FirebaseAuthService>(
        context, listen: false);
    _currentUserId = authService.currentFirebaseUser?.uid;
    _firestoreService = Provider.of<FirestoreService>(context, listen: false);
    _produceListingService =
        Provider.of<ProduceListingService>(context, listen: false);

  }
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme
        .of(context)
        .colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Orders'),
        backgroundColor: colorScheme.inverseSurface,
        // Using themed AppBar color
        foregroundColor: colorScheme.surface,
      ),
      backgroundColor: colorScheme.surfaceContainerLow, // Themed background
      body: _currentUserId == null
          ? Center(child: Text("User not authenticated.",
          style: TextStyle(color: colorScheme.onSurfaceVariant)))
          : StreamBuilder<List<Order>>(
        stream: _firestoreService.getFarmerOrders(),
        builder: (context, orderSnapshot) {
          if (orderSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (orderSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error fetching orders: ${orderSnapshot.error}',
                    style: TextStyle(color: colorScheme.error)),
              ),
            );
          }
          if (!orderSnapshot.hasData || orderSnapshot.data!.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'No orders found.',
                  style: TextStyle(
                      fontSize: 18, color: colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          // Define terminal statuses to filter out
          const terminalStatuses = [
            OrderStatus.completed,
            OrderStatus.cancelled_by_buyer,
            OrderStatus.cancelled_by_farmer,
            OrderStatus.cancelled_by_platform,
            OrderStatus.failed_delivery,
            OrderStatus.disputed,
          ];

          // Filter for active orders (not in terminal statuses)
          // and sort by lastUpdated so most recently changed orders are at the top.
          List<Order> activeOrders = orderSnapshot.data!
              .where((order) => !terminalStatuses.contains(order.status))
              .toList();

          activeOrders.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));


          if (activeOrders.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'No active orders at the moment.',
                  style: TextStyle(
                      fontSize: 18, color: colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: activeOrders.length,
            itemBuilder: (context, index) {
              final order = activeOrders[index];
              // Use a FutureBuilder to get the ProduceListing details for each order
              return FutureBuilder<ProduceListing?>(
                future: _produceListingService.getProduceListingById(
                    order.produceListingId),
                builder: (context, listingSnapshot) {
                  // We don't show a big loader here, card will build with available info
                  // and update if listing details arrive.

                  ProduceListing? produceListing = listingSnapshot.data;

                  final styleInfo = _getStyleForOrderStatus(
                      order.status, colorScheme);
                  final DateFormat timeFormat = DateFormat('MMM d, hh:mm a');

                  return buildActivityDisplayItem( // Using your common widget
                    icon: styleInfo['icon'] as IconData,
                    iconBgColor: styleInfo['bgColor'] as Color,
                    iconColor: styleInfo['color'] as Color,
                    title: produceListing?.produceName ?? order.produceName,
                    subtitle: 'Qty: ${order.orderedQuantity.toStringAsFixed(
                        1)} ${order.unit} • Buyer: ${order.buyerId.substring(
                        0, math.min(order.buyerId.length, 6))}...',
                    // Show partial buyerId for privacy
                    amountOrStatus: "${order.status
                        .displayName}\nUpdated: ${timeFormat.format(
                        order.lastUpdated)}",
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Map<String, dynamic> _getStyleForOrderStatus(OrderStatus status,
      ColorScheme colorScheme) {
    switch (status) {
      case OrderStatus.pending_confirmation:
        return {
          'icon': Icons.hourglass_empty_outlined,
          'color': colorScheme.tertiary,
          'bgColor': colorScheme.tertiaryContainer.withOpacity(0.3)
        };
      case OrderStatus.confirmed_by_platform:
        return {
          'icon': Icons.playlist_add_check_circle_outlined,
          'color': colorScheme.primary,
          'bgColor': colorScheme.primaryContainer.withOpacity(0.3)
        };
      case OrderStatus.searching_for_driver:
        return {
          'icon': Icons.person_search_outlined,
          'color': Colors.blueGrey[700],
          'bgColor': Colors.blueGrey[100]
        };
      case OrderStatus.driver_assigned:
        return {
          'icon': Icons.two_wheeler_outlined,
          'color': colorScheme.secondary,
          'bgColor': colorScheme.secondaryContainer.withOpacity(0.3)
        };
      case OrderStatus.driver_en_route_to_pickup:
      case OrderStatus.en_route_to_delivery:
        return {
          'icon': Icons.route_outlined,
          'color': Colors.cyan[700],
          'bgColor': Colors.cyan[100]
        };
      case OrderStatus.at_pickup_location:
      case OrderStatus.at_delivery_location:
        return {
          'icon': Icons.storefront_outlined,
          'color': Colors.brown[600],
          'bgColor': Colors.brown[100]
        };
      case OrderStatus.picked_up:
        return {
          'icon': Icons.takeout_dining_outlined,
          'color': Colors.lime[800],
          'bgColor': Colors.lime[100]
        };
      case OrderStatus
          .delivered: // Before final completion and payment settlement
        return {
          'icon': Icons.local_shipping_outlined,
          'color': Colors.lightGreen[700],
          'bgColor': Colors.lightGreen[100]
        };
      case OrderStatus
          .completed: // This screen filters these out, but for completeness
        return {
          'icon': Icons.check_circle_outline,
          'color': colorScheme.secondary,
          'bgColor': colorScheme.secondaryContainer.withOpacity(0.3)
        };
      case OrderStatus.cancelled_by_buyer:
      case OrderStatus.cancelled_by_farmer:
      case OrderStatus.cancelled_by_platform:
      case OrderStatus.failed_delivery:
      case OrderStatus.disputed:
        return {
          'icon': Icons.error_outline,
          'color': colorScheme.error,
          'bgColor': colorScheme.errorContainer.withOpacity(0.3)
        };
      default:
        return {
          'icon': Icons.info_outline,
          'color': colorScheme.onSurfaceVariant,
          'bgColor': colorScheme.surfaceVariant.withOpacity(0.3)
        };
    }
  }
}
