import 'package:animo/core/models/location_data.dart';
import 'package:animo/core/models/order.dart' as app_order;
import 'package:animo/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class DriverActiveOrderDetailScreen extends StatefulWidget {
  static const String routeName = '/driver-active-order-detail';
  final app_order.Order order;

  const DriverActiveOrderDetailScreen({super.key, required this.order});

  @override
  State<DriverActiveOrderDetailScreen> createState() => _DriverActiveOrderDetailScreenState();
}

class _DriverActiveOrderDetailScreenState extends State<DriverActiveOrderDetailScreen> {
  bool _isUpdatingStatus = false;

  Future<void> _confirmDelivery() async {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final driverId = FirebaseAuth.instance.currentUser?.uid;

    if (driverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Driver not logged in.')),
      );
      return;
    }

    bool confirm = await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Delivery'),
              content: Text('Are you sure you have delivered the order for "${widget.order.produceName}"?'),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton(
                  child: const Text('Confirm'),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            );
          },
        ) ?? false;

    if (confirm && widget.order.id != null) {
      setState(() {
        _isUpdatingStatus = true;
      });
      try {
        await firestoreService.updateOrderStatusForDriver(
          widget.order.id!,
          driverId,
          app_order.OrderStatus.delivered,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order for "${widget.order.produceName}" marked as delivered!')),
        );
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating order status: ${e.toString()}')),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isUpdatingStatus = false;
          });
        }
      }
    }
  }

  Widget _buildDetailRow(BuildContext context, String label, String value, {bool isStatus = false}) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500, color: colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: isStatus 
                  ? textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)
                  : textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAddressCard(BuildContext context, String title, LocationData location) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    String fullAddress = [
      location.addressHint,
      location.barangay,
      location.municipality,
    ].where((s) => s != null && s.isNotEmpty).join(', ');

    if (fullAddress.isEmpty) {
      fullAddress = 'Address not fully specified.';
    }
    
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary)),
            const SizedBox(height: 8),
            Text(fullAddress, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Order Details: ${order.produceName.characters.take(20)}${order.produceName.length > 20 ? "..." : ""}'),
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.produceName,
                      style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary),
                    ),
                    const SizedBox(height: 4),
                     Text(
                      'Category: ${order.produceCategory.displayName}${order.customProduceCategory != null && order.customProduceCategory!.isNotEmpty ? " (${order.customProduceCategory})" : ""}',
                      style: textTheme.titleSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(context, 'Status:', order.status.displayName, isStatus: true),
                    _buildDetailRow(context, 'Quantity:', '${order.orderedQuantity.toStringAsFixed(1)} ${order.unit}'),
                    _buildDetailRow(context, 'Price per Unit:', '${order.pricePerUnit.toStringAsFixed(2)} ${order.currency}'),
                    _buildDetailRow(context, 'Goods Total:', '${order.totalGoodsPrice.toStringAsFixed(2)} ${order.currency}'),
                     if (order.deliveryFeeDetails != null)
                      _buildDetailRow(context, 'Delivery Fee:', '${order.deliveryFeeDetails!.grossDeliveryFee.toStringAsFixed(2)} ${order.currency}'),
                    _buildDetailRow(context, 'Order Total:', '${order.totalOrderAmount.toStringAsFixed(2)} ${order.currency}'),
                     if (order.paymentType == app_order.PaymentType.cod)
                       _buildDetailRow(context, 'Collect (COD):', '${order.codAmountToCollectFromBuyer.toStringAsFixed(2)} ${order.currency}'),
                    _buildDetailRow(context, 'Order Placed:', DateFormat.yMMMd().add_jm().format(order.createdAt.toLocal())),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            _buildAddressCard(context, 'Pickup From (Farmer)', order.pickupLocation),
            _buildAddressCard(context, 'Deliver To (Buyer)', order.deliveryLocation),

             if (order.buyerNotes != null && order.buyerNotes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerLowest,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Buyer Notes:', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary)),
                      const SizedBox(height: 8),
                      Text(order.buyerNotes!, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            if (order.status != app_order.OrderStatus.delivered && order.status != app_order.OrderStatus.completed && order.status != app_order.OrderStatus.cancelled_by_buyer && order.status != app_order.OrderStatus.cancelled_by_farmer && order.status != app_order.OrderStatus.cancelled_by_platform && order.status != app_order.OrderStatus.failed_delivery)
              _isUpdatingStatus
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.local_shipping_outlined),
                      label: const Text('Confirm Delivery'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        textStyle: textTheme.labelLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _confirmDelivery,
                    ),
            const SizedBox(height: 20), // Bottom padding
          ],
        ),
      ),
    );
  }
} 