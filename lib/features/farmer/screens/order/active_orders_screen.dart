import 'dart:math' as math;

import 'package:animo/services/produce_listing_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/models/order.dart';
import '../../../../core/models/produce_listing.dart';
import '../../../../services/firebase_auth_service.dart';
import '../../../../services/firestore_service.dart';
import '../common_widgets.dart';

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

  Future<void> _handleOrderAction(Order order, OrderStatus newStatus, {String? reason, String? farmerNotes}) async {
    if (order.id == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Order ID is missing.')),
        );
      }
      return;
    }
    try {
      await _firestoreService.updateOrderStatus(
        order.id!,
        newStatus,
        cancellationReason: reason, // For cancellations
        farmerNotes: farmerNotes, // For general notes or completion notes
      );
      if (mounted) {
        String successMessage = 'Order status updated.';
        if (newStatus == OrderStatus.confirmed_by_platform) {
          successMessage = 'Order confirmed.';
        } else if (newStatus == OrderStatus.cancelled_by_farmer) {
          successMessage = 'Order rejected.';
        } else if (newStatus == OrderStatus.completed) {
          successMessage = 'Order marked as completed.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating order: ${e.toString()}')),
        );
      }
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

  void _showMarkAsCompletedDialog(Order order) {
    // Optional: Add a notes field if farmers need to add completion notes
    // final TextEditingController notesController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Mark Order as Completed'),
          content: Text('Are you sure you want to mark this order for "${order.produceName}" as completed? This usually signifies payment has been settled and the transaction is finished.'),
          // Optional: Add notes field
          // content: Column(
          //   mainAxisSize: MainAxisSize.min,
          //   children: [
          //     Text('Mark order for "${order.produceName}" as completed?'),
          //     SizedBox(height: 16),
          //     TextField(
          //       controller: notesController,
          //       decoration: InputDecoration(
          //         labelText: 'Completion notes (optional)',
          //         border: OutlineInputBorder(),
          //       ),
          //       maxLines: 2,
          //     ),
          //   ],
          // ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: Text('Mark Completed', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _handleOrderAction(
                  order,
                  OrderStatus.completed,
                  // farmerNotes: notesController.text.trim(), // If notes field is added
                );
              },
            ),
          ],
        );
      },
    );
  }


  // _getStyleForOrderStatus is now directly available from OrderStatus enum
  // Map<String, dynamic> _getStyleForOrderStatus(OrderStatus status, ColorScheme colorScheme) {
  //   return status.getStyle(colorScheme);
  // }


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

          // Define terminal statuses to filter out from "Active Orders" view
          const terminalStatuses = [
            OrderStatus.completed,
            OrderStatus.cancelled_by_buyer,
            OrderStatus.cancelled_by_farmer,
            OrderStatus.cancelled_by_platform,
            OrderStatus.failed_delivery,
            OrderStatus.disputed,   // Assuming disputed is also terminal for this view
          ];

          List<Order> activeOrders = orderSnapshot.data!
              .where((order) => !terminalStatuses.contains(order.status))
              .toList();

          // Sort active orders: pending_confirmation first, then by lastUpdated
          activeOrders.sort((a, b) {
            if (a.status == OrderStatus.pending_confirmation && b.status != OrderStatus.pending_confirmation) {
              return -1; // a comes first
            }
            if (b.status == OrderStatus.pending_confirmation && a.status != OrderStatus.pending_confirmation) {
              return 1; // b comes first
            }
            return b.lastUpdated.compareTo(a.lastUpdated); // Then by last updated
          });


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
                // Assuming getProduceListingById is on FirestoreService
                future: _produceListingService.getProduceListingById(order.produceListingId),
                builder: (context, listingSnapshot) {
                  ProduceListing? produceListing = listingSnapshot.data;
                  final styleInfo = getStyleForOrderStatus(order.status, colorScheme); // Use enum's method
                  final DateFormat timeFormat = DateFormat('MMM d, hh:mm a');
                  bool isPendingFarmerConfirmation = order.status == OrderStatus.pending_confirmation;
                  bool isDelivered = order.status == OrderStatus.delivered;

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
                                NumberFormat.currency(locale: Intl.defaultLocale, symbol: '${order.currency} ', decimalDigits: 2).format(order.totalOrderAmount),
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
                            'Buyer: ${order.buyerId.substring(0, math.min(order.buyerId.length, 8))}...',
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
                                    _handleOrderAction(order, OrderStatus.confirmed_by_platform);
                                  },
                                ),
                              ],
                            ),
                          ] else if (isDelivered) ...[ // NEW: Action for Delivered orders
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.done_all_outlined),
                                  label: const Text('Mark Completed'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colorScheme.secondary, // Use secondary color for completion
                                    foregroundColor: colorScheme.onSecondary,
                                  ),
                                  onPressed: () => _showMarkAsCompletedDialog(order),
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
