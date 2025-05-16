import 'dart:math' as math;

import 'package:animo/services/produce_listing_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/models/order.dart';
import '../../../../core/models/produce_listing.dart';
import '../../../../services/firebase_auth_service.dart';
import '../../../../services/firestore_service.dart';
import '../common_widgets.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  late final FirestoreService _firestoreService;
  late final ProduceListingService _produceListingService;
  late final String? _currentUserId;

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<FirebaseAuthService>(context, listen: false);
    _currentUserId = authService.currentFirebaseUser?.uid;
    _firestoreService = Provider.of<FirestoreService>(context, listen: false);
    _produceListingService = Provider.of<ProduceListingService>(context, listen: false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // final textTheme = Theme.of(context).textTheme; // Not explicitly used in the provided snippet

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order History'),
        backgroundColor: colorScheme.surfaceContainerHighest,
        foregroundColor: colorScheme.onSurfaceVariant,
        elevation: 1,
      ),
      backgroundColor: colorScheme.surfaceContainerLow,
      body: _currentUserId == null
          ? Center(child: Text("User not authenticated.", style: TextStyle(color: colorScheme.onSurfaceVariant)))
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
                child: Text('Error fetching order history: ${orderSnapshot.error}',
                    style: TextStyle(color: colorScheme.error)),
              ),
            );
          }
          if (!orderSnapshot.hasData || orderSnapshot.data!.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'No past orders found.',
                  style: TextStyle(fontSize: 18, color: colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          const List<OrderStatus> nonActiveStatuses = [
            OrderStatus.completed,
            OrderStatus.cancelled_by_buyer,
            OrderStatus.cancelled_by_farmer,
            OrderStatus.cancelled_by_platform,
            OrderStatus.failed_delivery,
            OrderStatus.disputed,
          ];

          List<Order> historicalOrders = orderSnapshot.data!
              .where((order) => nonActiveStatuses.contains(order.status))
              .toList();

          // Sort by lastUpdated (newest first)
          historicalOrders.sort((a, b) {
            return b.lastUpdated.compareTo(a.lastUpdated); // Use lastUpdated for sorting
          });

          if (historicalOrders.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'No historical orders found.',
                  style: TextStyle(fontSize: 18, color: colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: historicalOrders.length,
            itemBuilder: (context, index) {
              final order = historicalOrders[index];

              return FutureBuilder<ProduceListing?>(
                future: _produceListingService.getProduceListingById(order.produceListingId),
                builder: (context, listingSnapshot) {
                  ProduceListing? produceListing = listingSnapshot.data;
                  final styleInfo = getStyleForOrderStatus(order.status, colorScheme);
                  final DateFormat dateFormat = DateFormat('MMM d, yyyy'); // Consistent date format

                  // Use lastUpdated for the date display
                  final String dateString = dateFormat.format(order.lastUpdated);

                  return buildActivityDisplayItem( // Using your common widget
                    icon: styleInfo['icon'] as IconData,
                    iconBgColor: styleInfo['bgColor'] as Color,
                    iconColor: styleInfo['color'] as Color,
                    title: produceListing?.produceName ?? order.produceName,
                    subtitle: 'Qty: ${order.orderedQuantity.toStringAsFixed(1)} ${order.unit} \nBuyer: ${order.buyerId.substring(0, math.min(order.buyerId.length, 6))}...',
                    amountOrStatus: "${order.status.displayName}\n$dateString",
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
