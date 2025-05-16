import 'package:animo/core/models/match_suggestion.dart';
import 'package:animo/core/models/order.dart' as app_order;
import 'package:animo/features/buyer/screens/match_suggestions_screen.dart';
import 'package:animo/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animo/core/models/produce_listing.dart'; // For ProduceCategory enum
// import 'package:intl/intl.dart'; // If date formatting is needed

// Helper function to get an icon based on produce category
IconData _getIconForOrderProduceCategory(ProduceCategory category) {
  switch (category) {
    case ProduceCategory.fruit:
      return Icons.apple_outlined;
    case ProduceCategory.vegetable:
      return Icons.local_florist_outlined;
    case ProduceCategory.herb:
      return Icons.grass_outlined;
    case ProduceCategory.grain:
      return Icons.grain_outlined;
    case ProduceCategory.processed:
      return Icons.settings_input_component_outlined;
    case ProduceCategory.other:
    default:
      return Icons.inventory_2_outlined;
  }
}

// Optional: Helper to get color for status
Color _getColorForOrderStatus(app_order.OrderStatus status, ColorScheme colorScheme) {
  switch (status) {
    case app_order.OrderStatus.pending_confirmation:
      return Colors.orange.shade700;
    case app_order.OrderStatus.confirmed_by_platform:
      return Colors.teal.shade700;
    case app_order.OrderStatus.searching_for_driver:
      return Colors.orange.shade700;
    case app_order.OrderStatus.driver_assigned:
    case app_order.OrderStatus.driver_en_route_to_pickup:
    case app_order.OrderStatus.at_pickup_location:
    case app_order.OrderStatus.picked_up:
    case app_order.OrderStatus.en_route_to_delivery:
    case app_order.OrderStatus.at_delivery_location:
      return Colors.blue.shade700;
    case app_order.OrderStatus.delivered:
    case app_order.OrderStatus.completed:
      return Colors.green.shade700;
    case app_order.OrderStatus.cancelled_by_buyer:
    case app_order.OrderStatus.cancelled_by_farmer:
    case app_order.OrderStatus.cancelled_by_platform:
    case app_order.OrderStatus.failed_delivery:
    case app_order.OrderStatus.disputed:
      return colorScheme.error;
    default:
      return colorScheme.onSurfaceVariant;
  }
}


class NotificationsTab extends StatefulWidget {
  const NotificationsTab({super.key});

  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab> {
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_currentUser == null) {
      return Center(
        child: Text(
          'Please log in to see your orders.',
          style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    return DefaultTabController(
      length: 1,
      child: Container(
        color: colorScheme.surface, // Main light background
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF4A2E2B),
              ),
              child: TabBar(
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(
                    text: 'Orders',
                    icon: Icon(Icons.shopping_bag_outlined),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Orders Tab
                  _buildOrdersList(firestoreService, colorScheme, textTheme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList(FirestoreService firestoreService, ColorScheme colorScheme, TextTheme textTheme) {
    return StreamBuilder<List<app_order.Order>>(
      stream: firestoreService.getOrdersForBuyer(_currentUser!.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          debugPrint("Error in NotificationsTab StreamBuilder: ${snapshot.error}\n${snapshot.stackTrace}");
          return Center(child: Text('Error fetching your orders: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 20),
                  Text(
                    'No orders yet.',
                    textAlign: TextAlign.center,
                    style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurfaceVariant.withOpacity(0.8)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your placed orders will appear here.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant.withOpacity(0.7)),
                  ),
                ],
              ),
            ),
          );
        }
        final orders = snapshot.data!;

        // Sort orders
        orders.sort((a, b) {
          int getSortPriority(app_order.OrderStatus status) {
            switch (status) {
              case app_order.OrderStatus.confirmed_by_platform:
                return 0;
              case app_order.OrderStatus.pending_confirmation:
                return 1;
              case app_order.OrderStatus.delivered:
                return 3;
              default:
                return 2; // Other statuses
            }
          }
          return getSortPriority(a.status).compareTo(getSortPriority(b.status));
        });

        return ListView.builder(
          padding: const EdgeInsets.only(top:8.0, bottom: 70.0, left: 8.0, right: 8.0),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            
            // Determine icon background color based on status for visual cue
            Color iconBgColor = Colors.grey.shade200;
            Color iconColor = Colors.grey.shade700;

            if (order.status == app_order.OrderStatus.completed || order.status == app_order.OrderStatus.delivered) {
              iconBgColor = Colors.green.shade100;
              iconColor = Colors.green.shade800;
            } else if (order.status == app_order.OrderStatus.cancelled_by_buyer ||
                       order.status == app_order.OrderStatus.cancelled_by_farmer ||
                       order.status == app_order.OrderStatus.cancelled_by_platform ||
                       order.status == app_order.OrderStatus.failed_delivery) {
              iconBgColor = colorScheme.errorContainer.withOpacity(0.5);
              iconColor = colorScheme.onErrorContainer;
            } else if (order.status.name.contains('pending') || order.status.name.contains('searching')) {
               iconBgColor = Colors.orange.shade100;
               iconColor = Colors.orange.shade800;
            } else if (order.status == app_order.OrderStatus.confirmed_by_platform) { // Added specific check for confirmed_by_platform for icon
               iconBgColor = Colors.teal.shade100;
               iconColor = Colors.teal.shade800;
            } else if (order.status.name.contains('driver') || order.status.name.contains('pickup') || order.status.name.contains('route')) {
               iconBgColor = Colors.blue.shade100;
               iconColor = Colors.blue.shade800;
            }


            return Card(
              color: colorScheme.surfaceContainerLow,
              margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              elevation: 1.5,
              child: InkWell(
                borderRadius: BorderRadius.circular(12.0),
                onTap: () {
                  // TODO: Navigate to a detailed order screen if needed
                  // For now, maybe show a dialog or SnackBar
                  showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                            title: Text('Order: ${order.produceName}'),
                            content: SingleChildScrollView(
                              child: ListBody(
                                children: <Widget>[
                                  Text('Status: ${order.status.displayName}'),
                                  Text('Quantity: ${order.orderedQuantity} ${order.unit}'),
                                  Text('Goods Price: ${order.totalGoodsPrice.toStringAsFixed(2)} ${order.currency}'),
                                  if (order.deliveryFeeDetails != null)
                                    Text('Delivery Fee: ${order.deliveryFeeDetails!.grossDeliveryFee.toStringAsFixed(2)} ${order.currency}'),
                                  Text('Total Amount: ${order.totalOrderAmount.toStringAsFixed(2)} ${order.currency}'),
                                  // Text('Farmer ID: ${order.farmerId}'), // For debug or future use
                                  // Text('Order ID: ${order.id}'),
                                ],
                              ),
                            ),
                            actions: <Widget>[
                              TextButton(
                                child: const Text('Close'),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                              ),
                            ],
                          ));
                },
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: CircleAvatar(
                          radius: 24,
                          backgroundColor: iconBgColor,
                          child: Icon(
                            _getIconForOrderProduceCategory(order.produceCategory),
                            size: 22,
                            color: iconColor,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.produceName,
                              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${order.orderedQuantity.toStringAsFixed(1)} ${order.unit}',
                              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                             const SizedBox(height: 1),
                             Text(
                              // Using totalOrderAmount which includes delivery if applicable
                              'Total: ${order.totalOrderAmount.toStringAsFixed(2)} ${order.currency}',
                              style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: _getColorForOrderStatus(order.status, colorScheme).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4)
                            ),
                            child: Text(
                              order.status.displayName, // Using display name from enum
                              textAlign: TextAlign.end,
                              style: textTheme.bodySmall?.copyWith(
                                color: _getColorForOrderStatus(order.status, colorScheme),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}