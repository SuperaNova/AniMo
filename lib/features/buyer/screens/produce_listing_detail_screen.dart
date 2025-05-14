import 'package:animo/core/models/produce_listing.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProduceListingDetailScreen extends StatelessWidget {
  static const String routeName = '/produce-listing-detail';
  final ProduceListing listing;

  const ProduceListingDetailScreen({super.key, required this.listing});

  @override
  Widget build(BuildContext context) {
    // Helper to build text rows for details
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

    String category = listing.produceCategory.displayName;
    if (listing.produceCategory == ProduceCategory.other && 
        listing.customProduceCategory != null && 
        listing.customProduceCategory!.isNotEmpty) {
      category += " (${listing.customProduceCategory})";
    }

    String harvestInfo = listing.harvestTimestamp != null 
        ? DateFormat.yMMMd().add_jm().format(listing.harvestTimestamp!) 
        : 'N/A';
    String expiryInfo = listing.expiryTimestamp != null 
        ? DateFormat.yMMMd().add_jm().format(listing.expiryTimestamp!) 
        : 'N/A';
    String availabilityStatus = listing.status.displayName;
    if (listing.quantity <= 0 && listing.status == ProduceListingStatus.available) {
        availabilityStatus = "Sold Out (Pending Update)";
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(listing.produceName),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Placeholder for Image Carousel/Display
            if (listing.photoUrls.isNotEmpty)
              Container(
                height: 250,
                color: Colors.grey[300],
                alignment: Alignment.center,
                margin: const EdgeInsets.only(bottom: 16.0),
                child: Text('Image for ${listing.photoUrls.first} (Display Coming Soon)'), // Simple display for now
                // TODO: Implement an image carousel if multiple photos
              )
            else
              Container(
                height: 200,
                color: Colors.grey[300],
                alignment: Alignment.center,
                margin: const EdgeInsets.only(bottom: 16.0),
                child: const Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey),
              ),

            Text(listing.produceName, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (listing.description != null && listing.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(listing.description!, style: Theme.of(context).textTheme.bodyLarge),
              ),
            
            _buildDetailRow('Category', category),
            _buildDetailRow('Price', '${listing.pricePerUnit} ${listing.currency} per ${listing.unit}'),
            _buildDetailRow('Available Quantity', '${listing.quantity.toStringAsFixed(1)} ${listing.unit}'),
             _buildDetailRow('Status', availabilityStatus, valueStyle: TextStyle(color: listing.status == ProduceListingStatus.available && listing.quantity > 0 ? Colors.green.shade700 : Colors.orange.shade700)),
            if (listing.estimatedWeightKgPerUnit != null)
                _buildDetailRow('Est. Weight/Unit', '${listing.estimatedWeightKgPerUnit} kg'),
            
            const SizedBox(height: 16),
            Text('Farmer & Pickup Information', style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            _buildDetailRow('Farmer', listing.farmerName ?? 'N/A'),
            _buildDetailRow('Pickup Barangay', listing.pickupLocation.barangay),
            _buildDetailRow('Pickup Municipality', listing.pickupLocation.municipality),
            if (listing.pickupLocation.addressHint != null && listing.pickupLocation.addressHint!.isNotEmpty)
              _buildDetailRow('Pickup Address Hint', listing.pickupLocation.addressHint),
            
            const SizedBox(height: 16),
            Text('Freshness Information', style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            _buildDetailRow('Harvest Date', harvestInfo),
            _buildDetailRow('Expiry Date', expiryInfo),
            
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.shopping_cart_checkout),
                label: const Text('Request to Order'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
                onPressed: () {
                  // TODO: Implement order initiation flow
                  // This could involve: 
                  // 1. Showing a dialog to confirm quantity to order.
                  // 2. Checking if requested quantity <= available quantity.
                  // 3. Navigating to an order confirmation screen or directly creating an Order object.
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Order for ${listing.produceName} coming soon!')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
} 