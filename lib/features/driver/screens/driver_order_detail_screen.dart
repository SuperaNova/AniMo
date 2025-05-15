import 'package:animo/core/models/order.dart' as app_order;
import 'package:animo/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class DriverOrderDetailScreen extends StatefulWidget {
  static const String routeName = '/driver-order-detail';
  final app_order.Order order;

  const DriverOrderDetailScreen({super.key, required this.order});

  @override
  State<DriverOrderDetailScreen> createState() => _DriverOrderDetailScreenState();
}

class _DriverOrderDetailScreenState extends State<DriverOrderDetailScreen> {
  bool _isAcceptingOrder = false;

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

  Future<void> _acceptOrder() async {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final driverId = FirebaseAuth.instance.currentUser?.uid;

    if (driverId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Driver not logged in.')),
      );
      return;
    }

    bool confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Accept Order'),
          content: Text('Are you sure you want to accept this order for "${widget.order.produceName}"?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Accept'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    ) ?? false;

    if (confirm && widget.order.id != null) {
      setState(() {
        _isAcceptingOrder = true;
      });
      try {
        await firestoreService.acceptOrderForDriver(widget.order.id!, driverId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order for "${widget.order.produceName}" accepted successfully!')),
        );
        Navigator.of(context).pop(); // Pop back to dashboard
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept order: ${e.toString()}')),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isAcceptingOrder = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_PH', symbol: widget.order.currency); // Assuming PHP for now
    String pickupAddressString = widget.order.pickupLocation.addressHint ?? 'Details not specified';
    String pBarangay = widget.order.pickupLocation.barangay ?? '';
    String pMunicipality = widget.order.pickupLocation.municipality ?? '';
    if (pBarangay.isNotEmpty || pMunicipality.isNotEmpty) {
      pickupAddressString += '\n';
      pickupAddressString += pBarangay.isNotEmpty ? pBarangay : '';
      pickupAddressString += (pBarangay.isNotEmpty && pMunicipality.isNotEmpty) ? ', ' : '';
      pickupAddressString += pMunicipality.isNotEmpty ? pMunicipality : '';
    }

    String deliveryAddressString = widget.order.deliveryLocation.addressHint ?? 'Details not specified';
    String dBarangay = widget.order.deliveryLocation.barangay ?? '';
    String dMunicipality = widget.order.deliveryLocation.municipality ?? '';
    if (dBarangay.isNotEmpty || dMunicipality.isNotEmpty) {
      deliveryAddressString += '\n';
      deliveryAddressString += dBarangay.isNotEmpty ? dBarangay : '';
      deliveryAddressString += (dBarangay.isNotEmpty && dMunicipality.isNotEmpty) ? ', ' : '';
      deliveryAddressString += dMunicipality.isNotEmpty ? dMunicipality : '';
    }

    // Determine if the accept button should be shown
    bool canAcceptOrder = (widget.order.status == app_order.OrderStatus.confirmed_by_platform || 
                           widget.order.status == app_order.OrderStatus.searching_for_driver) && 
                           (widget.order.assignedDriverId == null || widget.order.assignedDriverId!.isEmpty);

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${widget.order.id?.substring(0, 6) ?? 'Details'}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Order for: ${widget.order.produceName}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildDetailRow('Status', widget.order.status.displayName, valueStyle: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
            _buildDetailRow('Ordered Quantity', '${widget.order.orderedQuantity} ${widget.order.unit}'),
            _buildDetailRow('Total Goods Price', currencyFormat.format(widget.order.totalGoodsPrice)),
            if (widget.order.deliveryFeeDetails != null)
              _buildDetailRow('Delivery Fee', currencyFormat.format(widget.order.deliveryFeeDetails!.grossDeliveryFee)),
            _buildDetailRow('Total Order Amount', currencyFormat.format(widget.order.totalOrderAmount)),
            _buildDetailRow('Payment Type', widget.order.paymentType.displayName),
            if (widget.order.paymentType == app_order.PaymentType.cod)
              _buildDetailRow('COD Amount to Collect', currencyFormat.format(widget.order.codAmountToCollectFromBuyer)),
            
            const SizedBox(height: 16),
            Text('Pickup Information', style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            // _buildDetailRow('Farmer Name', widget.order.farmerName ?? 'N/A'), // TODO: Fetch farmer name using widget.order.farmerId
            _buildDetailRow('Pickup Address', pickupAddressString),
            _buildDetailRow('Pickup Coordinates', 'Lat: ${widget.order.pickupLocation.latitude.toStringAsFixed(5)}, Lng: ${widget.order.pickupLocation.longitude.toStringAsFixed(5)}'),
            if (widget.order.estimatedPickupTime != null)
              _buildDetailRow('Est. Pickup Time', DateFormat.yMMMd().add_jm().format(widget.order.estimatedPickupTime!)),

            const SizedBox(height: 16),
            Text('Delivery Information', style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            // _buildDetailRow('Buyer Name', widget.order.buyerName ?? 'N/A'), // TODO: Fetch buyer name using widget.order.buyerId
            _buildDetailRow('Delivery Address', deliveryAddressString),
            _buildDetailRow('Delivery Coordinates', 'Lat: ${widget.order.deliveryLocation.latitude.toStringAsFixed(5)}, Lng: ${widget.order.deliveryLocation.longitude.toStringAsFixed(5)}'),
             if (widget.order.estimatedDeliveryTime != null)
              _buildDetailRow('Est. Delivery Time', DateFormat.yMMMd().add_jm().format(widget.order.estimatedDeliveryTime!)),

            if(widget.order.buyerNotes != null && widget.order.buyerNotes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top:16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Text('Buyer Notes', style: Theme.of(context).textTheme.titleMedium),
                     const SizedBox(height: 4),
                     Text(widget.order.buyerNotes!)
                  ],
                ),
              ),

            const SizedBox(height: 30),
            if (canAcceptOrder)
              Center(
                child: _isAcceptingOrder 
                    ? const CircularProgressIndicator() 
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.local_shipping_outlined),
                        label: const Text('Accept & Pickup Order'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        ),
                        onPressed: _acceptOrder,
                      ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
} 