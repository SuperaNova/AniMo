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
    final authService = Provider.of<FirebaseAuthService>(context, listen: false);
    _currentUserId = authService.currentFirebaseUser?.uid;
    _firestoreService = Provider.of<FirestoreService>(context, listen: false);
    _produceListingService = Provider.of<ProduceListingService>(context, listen: false);

  }

  Future<void> _handleOrderAction(Order order, OrderStatus newStatus, {String? reason}) async {
    if (order.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Order ID is missing.')),
      );
      return;
    }
    try {
      await _firestoreService.updateOrderStatus(order.id!, newStatus, cancellationReason: reason);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order ${newStatus == OrderStatus.confirmed_by_platform ? "confirmed" : "rejected"}.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating order: ${e.toString()}')),
      );
    }
  }

  void _showRejectionDialog(Order order) {
    final TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Reject Order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Are you sure you want to reject this order for "${order.produceName}"?'),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason for rejection (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: Text('Reject Order', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _handleOrderAction(order, OrderStatus.cancelled_by_farmer, reason: reasonController.text.trim());
              },
            ),
          ],
        );
      },
    );
  }


  Map<String, dynamic> _getStyleForOrderStatus(OrderStatus status, ColorScheme colorScheme) {
    // ... (Implementation remains the same as in your previous version) ...
    switch (status) {
      case OrderStatus.pending_confirmation:
        return {'icon': Icons.hourglass_empty_outlined, 'color': colorScheme.tertiary, 'bgColor': colorScheme.tertiaryContainer.withOpacity(0.3)};
      case OrderStatus.confirmed_by_platform:
        return {'icon': Icons.playlist_add_check_circle_outlined, 'color': colorScheme.primary, 'bgColor': colorScheme.primaryContainer.withOpacity(0.3)};
      case OrderStatus.searching_for_driver:
        return {'icon': Icons.person_search_outlined, 'color': Colors.blueGrey[700]!, 'bgColor': Colors.blueGrey[100]!};
      case OrderStatus.driver_assigned:
        return {'icon': Icons.two_wheeler_outlined, 'color': colorScheme.secondary, 'bgColor': colorScheme.secondaryContainer.withOpacity(0.3)};
      case OrderStatus.driver_en_route_to_pickup:
      case OrderStatus.en_route_to_delivery:
        return {'icon': Icons.route_outlined, 'color': Colors.cyan[700]!, 'bgColor': Colors.cyan[100]!};
      case OrderStatus.at_pickup_location:
      case OrderStatus.at_delivery_location:
        return {'icon': Icons.storefront_outlined, 'color': Colors.brown[600]!, 'bgColor': Colors.brown[100]!};
      case OrderStatus.picked_up:
        return {'icon': Icons.takeout_dining_outlined, 'color': Colors.lime[800]!, 'bgColor': Colors.lime[100]!};
      case OrderStatus.delivered:
        return {'icon': Icons.local_shipping_outlined, 'color': Colors.lightGreen[700]!, 'bgColor': Colors.lightGreen[100]!};
      case OrderStatus.completed:
        return {'icon': Icons.check_circle_outline, 'color': colorScheme.secondary, 'bgColor': colorScheme.secondaryContainer.withOpacity(0.3)};
      case OrderStatus.cancelled_by_buyer:
      case OrderStatus.cancelled_by_farmer:
      case OrderStatus.cancelled_by_platform:
      case OrderStatus.failed_delivery:
      case OrderStatus.disputed:
        return {'icon': Icons.error_outline, 'color': colorScheme.error, 'bgColor': colorScheme.errorContainer.withOpacity(0.3)};
      default:
        return {'icon': Icons.info_outline, 'color': colorScheme.onSurfaceVariant, 'bgColor': colorScheme.surfaceVariant.withOpacity(0.3)};
    }
  }


  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Orders'),
        backgroundColor: colorScheme.inverseSurface,
        foregroundColor: colorScheme.surface,
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
                  style: TextStyle(fontSize: 18, color: colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          const terminalStatuses = [
            OrderStatus.completed,
            OrderStatus.cancelled_by_buyer,
            OrderStatus.cancelled_by_farmer,
            OrderStatus.cancelled_by_platform,
            OrderStatus.failed_delivery,
            OrderStatus.disputed,
          ];

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
                  style: TextStyle(fontSize: 18, color: colorScheme.onSurfaceVariant),
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
              return FutureBuilder<ProduceListing?>(
                future: _produceListingService.getProduceListingById(order.produceListingId),
                builder: (context, listingSnapshot) {
                  ProduceListing? produceListing = listingSnapshot.data;
                  final styleInfo = _getStyleForOrderStatus(order.status, colorScheme);
                  final DateFormat timeFormat = DateFormat('MMM d, hh:mm a');
                  bool isPendingFarmerConfirmation = order.status == OrderStatus.pending_confirmation;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    elevation: 2.0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                    color: colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: styleInfo['bgColor'] as Color,
                                child: Icon(styleInfo['icon'] as IconData, color: styleInfo['color'] as Color, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      produceListing?.produceName ?? order.produceName,
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.onSurface),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Qty: ${order.orderedQuantity.toStringAsFixed(1)} ${order.unit}',
                                      style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                NumberFormat.currency(symbol: '${order.currency} ', decimalDigits: 2).format(order.totalOrderAmount),
                                style: TextStyle(fontSize: 14, color: colorScheme.primary, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const Divider(height: 20, thickness: 0.5),
                          Text(
                            'Status: ${order.status.displayName}',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: styleInfo['color'] as Color),
                          ),
                          Text(
                            'Buyer: ${order.buyerId.substring(0, math.min(order.buyerId.length, 8))}...', // Show partial buyerId
                            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                          ),
                          Text(
                            'Last Updated: ${timeFormat.format(order.lastUpdated)}',
                            style: TextStyle(fontSize: 12, color: colorScheme.outline),
                          ),
                          if (order.deliveryLocation.addressHint != null && order.deliveryLocation.addressHint!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                'Delivery to: ${order.deliveryLocation.addressHint}',
                                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                            ),

                          if (isPendingFarmerConfirmation) ...[
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  icon: const Icon(Icons.cancel_outlined),
                                  label: const Text('Reject'),
                                  style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                                  onPressed: () => _showRejectionDialog(order),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: const Text('Confirm'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colorScheme.primary,
                                    foregroundColor: colorScheme.onPrimary,
                                  ),
                                  onPressed: () {
                                    // Farmer confirms, next status is typically confirmed_by_platform or searching_for_driver
                                    // Depending on your workflow, if platform also needs to confirm,
                                    // this might go to a different status first.
                                    // For this example, let's assume farmer confirmation moves it to confirmed_by_platform.
                                    _handleOrderAction(order, OrderStatus.confirmed_by_platform);
                                  },
                                ),
                              ],
                            ),
                          ]
                        ],
                      ),
                    ),
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
