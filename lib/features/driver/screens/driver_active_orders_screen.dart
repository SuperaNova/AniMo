import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animo/core/models/order.dart' as app_order;
import 'package:animo/core/models/produce_listing.dart'; // Import for ProduceCategory enum
import 'package:animo/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:animo/features/driver/screens/driver_active_order_detail_screen.dart'; // For navigation

class DriverActiveOrdersScreen extends StatefulWidget {
  static const String routeName = '/driver-active-orders';
  const DriverActiveOrdersScreen({super.key});

  @override
  State<DriverActiveOrdersScreen> createState() => _DriverActiveOrdersScreenState();
}

class _DriverActiveOrdersScreenState extends State<DriverActiveOrdersScreen> {
  Stream<List<app_order.Order>>? _activeOrdersStream;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser != null) {
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      _activeOrdersStream = firestoreService.getDriverActiveOrders(_currentUser!.uid);
    }
  }

  Color _getStatusColor(app_order.OrderStatus status, ColorScheme colorScheme) {
    // Using the getStyleForOrderStatus from order.dart might be better if it exists and is suitable
    // For now, direct mapping as in screenshot
    if (status == app_order.OrderStatus.delivered || status == app_order.OrderStatus.completed) {
      return Colors.green.shade700;
    } else if (status == app_order.OrderStatus.confirmed_by_platform || 
               status == app_order.OrderStatus.driver_assigned ||
               status == app_order.OrderStatus.driver_en_route_to_pickup ||
               status == app_order.OrderStatus.at_pickup_location ||
               status == app_order.OrderStatus.picked_up ||
               status == app_order.OrderStatus.en_route_to_delivery ||
               status == app_order.OrderStatus.at_delivery_location
              ) {
      return const Color(0xFFC77700); // Amber/Brownish color for 'Confirmed by Platform' & active statuses
    } else if (status == app_order.OrderStatus.cancelled_by_buyer || 
               status == app_order.OrderStatus.cancelled_by_farmer || 
               status == app_order.OrderStatus.cancelled_by_platform || 
               status == app_order.OrderStatus.failed_delivery) {
      return colorScheme.error;
    }
    return colorScheme.onSurfaceVariant; // Default
  }

  IconData _getProduceIcon(ProduceCategory category) { // Changed to use ProduceCategory directly
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
        return Icons.settings_input_composite_outlined;
      case ProduceCategory.other:
      default:
        return Icons.inventory_2_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Orders'),
        backgroundColor: const Color(0xFF4A2E2B), // Dark brown color from screenshot
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      backgroundColor: colorScheme.surface, // Light background for the list
      body: StreamBuilder<List<app_order.Order>>(
        stream: _activeOrdersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            debugPrint("Error in DriverActiveOrdersScreen StreamBuilder: ${snapshot.error}");
            return Center(child: Text('Error fetching active orders: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No active orders at the moment.'),
                ],
              ),
            );
          }

          final orders = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final statusColor = _getStatusColor(order.status, colorScheme);
              final produceIcon = _getProduceIcon(order.produceCategory); // Uses direct ProduceCategory from Order model
              
              List<String> addressParts = [];
              if (order.deliveryLocation.addressHint != null && order.deliveryLocation.addressHint!.trim().isNotEmpty) {
                addressParts.add(order.deliveryLocation.addressHint!.trim());
              }
              if (order.deliveryLocation.barangay != null && order.deliveryLocation.barangay!.trim().isNotEmpty) {
                addressParts.add(order.deliveryLocation.barangay!.trim());
              }
              if (order.deliveryLocation.municipality != null && order.deliveryLocation.municipality!.trim().isNotEmpty) {
                addressParts.add(order.deliveryLocation.municipality!.trim());
              }
              String deliveryAddress = addressParts.join(', ');
              if (deliveryAddress.isEmpty) deliveryAddress = 'Address not fully specified';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                elevation: 1.5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                color: colorScheme.surfaceContainerLow, // Light beige card background
                child: InkWell(
                  borderRadius: BorderRadius.circular(12.0),
                  onTap: () {
                     Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => DriverActiveOrderDetailScreen(order: order),
                      ));
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 12.0, top: 4.0),
                              child: CircleAvatar(
                                radius: 22,
                                backgroundColor: produceIcon == Icons.local_shipping_outlined // Specific check for delivery truck icon
                                    ? Colors.green.shade100 
                                    : statusColor.withOpacity(0.15),
                                child: Icon(produceIcon, 
                                  size: 20, 
                                  color: produceIcon == Icons.local_shipping_outlined 
                                    ? Colors.green.shade700
                                    : statusColor),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    order.produceName,
                                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Qty: ${order.orderedQuantity.toStringAsFixed(order.orderedQuantity.truncateToDouble() == order.orderedQuantity ? 0 : 1)} ${order.unit}',
                                    style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                              child: Text(
                                '${order.currency} ${order.totalOrderAmount.toStringAsFixed(2)}',
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFB54B21), // Brownish price color from screenshot
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Divider(),
                        const SizedBox(height: 8),
                        RichText(
                          text: TextSpan(
                            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                            children: [
                              const TextSpan(text: 'Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
                              TextSpan(
                                text: order.status.displayName,
                                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        Text('Buyer ID: ${order.buyerId}', style: textTheme.bodySmall), // Using buyerId
                        Text(
                          'Last Updated: ${DateFormat.yMMMd().add_jm().format(order.lastUpdated)}', // Removed .toDate()
                           style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant.withOpacity(0.7)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Delivery to: $deliveryAddress',
                          style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant.withOpacity(0.7)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
} 