import 'package:animo/core/models/order.dart' as app_order;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DriverOrderDetailScreen extends StatelessWidget {
  static const String routeName = '/driver-order-detail';
  final app_order.Order order;

  const DriverOrderDetailScreen({super.key, required this.order});

  Widget _buildDetailRow(String label, String? value, {TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value ?? 'N/A', style: valueStyle)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_PH', symbol: order.currency); // Assuming PHP for now
    String pickupAddressString = order.pickupLocation.addressHint ?? 'Details not specified';
    String pBarangay = order.pickupLocation.barangay ?? '';
    String pMunicipality = order.pickupLocation.municipality ?? '';
    if (pBarangay.isNotEmpty || pMunicipality.isNotEmpty) {
      pickupAddressString += '\n';
      pickupAddressString += pBarangay.isNotEmpty ? pBarangay : '';
      pickupAddressString += (pBarangay.isNotEmpty && pMunicipality.isNotEmpty) ? ', ' : '';
      pickupAddressString += pMunicipality.isNotEmpty ? pMunicipality : '';
    }

    String deliveryAddressString = order.deliveryLocation.addressHint ?? 'Details not specified';
    String dBarangay = order.deliveryLocation.barangay ?? '';
    String dMunicipality = order.deliveryLocation.municipality ?? '';
    if (dBarangay.isNotEmpty || dMunicipality.isNotEmpty) {
      deliveryAddressString += '\n';
      deliveryAddressString += dBarangay.isNotEmpty ? dBarangay : '';
      deliveryAddressString += (dBarangay.isNotEmpty && dMunicipality.isNotEmpty) ? ', ' : '';
      deliveryAddressString += dMunicipality.isNotEmpty ? dMunicipality : '';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${order.id?.substring(0, 6) ?? 'Details'}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Order for: ${order.produceName}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildDetailRow('Status', order.status.displayName, valueStyle: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
            _buildDetailRow('Ordered Quantity', '${order.orderedQuantity} ${order.unit}'),
            _buildDetailRow('Total Goods Price', currencyFormat.format(order.totalGoodsPrice)),
            if (order.deliveryFeeDetails != null)
              _buildDetailRow('Delivery Fee', currencyFormat.format(order.deliveryFeeDetails!.grossDeliveryFee)),
            _buildDetailRow('Total Order Amount', currencyFormat.format(order.totalOrderAmount)),
            _buildDetailRow('Payment Type', order.paymentType.displayName),
            if (order.paymentType == app_order.PaymentType.cod)
              _buildDetailRow('COD Amount to Collect', currencyFormat.format(order.codAmountToCollectFromBuyer)),
            
            const SizedBox(height: 16),
            Text('Pickup Information', style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            // _buildDetailRow('Farmer Name', order.farmerName ?? 'N/A'), // TODO: Fetch farmer name using order.farmerId
            _buildDetailRow('Pickup Address', pickupAddressString),
            _buildDetailRow('Pickup Coordinates', 'Lat: ${order.pickupLocation.latitude.toStringAsFixed(5)}, Lng: ${order.pickupLocation.longitude.toStringAsFixed(5)}'),
            if (order.estimatedPickupTime != null)
              _buildDetailRow('Est. Pickup Time', DateFormat.yMMMd().add_jm().format(order.estimatedPickupTime!)),

            const SizedBox(height: 16),
            Text('Delivery Information', style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            // _buildDetailRow('Buyer Name', order.buyerName ?? 'N/A'), // TODO: Fetch buyer name using order.buyerId
            _buildDetailRow('Delivery Address', deliveryAddressString),
            _buildDetailRow('Delivery Coordinates', 'Lat: ${order.deliveryLocation.latitude.toStringAsFixed(5)}, Lng: ${order.deliveryLocation.longitude.toStringAsFixed(5)}'),
             if (order.estimatedDeliveryTime != null)
              _buildDetailRow('Est. Delivery Time', DateFormat.yMMMd().add_jm().format(order.estimatedDeliveryTime!)),

            if(order.buyerNotes != null && order.buyerNotes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top:16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Text('Buyer Notes', style: Theme.of(context).textTheme.titleMedium),
                     const SizedBox(height: 4),
                     Text(order.buyerNotes!)
                  ],
                ),
              ),

            const SizedBox(height: 30),
            if (order.status == app_order.OrderStatus.confirmed_by_platform || order.status == app_order.OrderStatus.searching_for_driver)
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: const Text('Accept & Pickup Order'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                  onPressed: () {
                    // TODO: Implement order pickup logic
                    // This would involve:
                    // 1. Updating order status (e.g., to 'driver_assigned' or 'driver_en_route_to_pickup')
                    // 2. Assigning currentDriverId to the order
                    // 3. Potentially navigating or showing further instructions
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Pickup logic for order ${order.id} coming soon!')),
                    );
                  },
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
} 