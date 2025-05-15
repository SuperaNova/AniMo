import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/models/produce_listing.dart';
import '../../../../services/firestore_service.dart';
import '../common_widgets.dart';

class AllListingsTabContent extends StatelessWidget {
  const AllListingsTabContent({super.key});

  @override
  Widget build(BuildContext context) {
    // Access the ProduceListingService.
    // This assumes ProduceListingService is provided in your widget tree
    // and its currentUserId is set (e.g., via ProxyProvider in main.dart).
    final produceListingService = Provider.of<FirestoreService>(context, listen: false);

    return StreamBuilder<List<ProduceListing>>(
      // Fetch all listings for the current farmer.
      stream: produceListingService.getFarmerProduceListings(),
      builder: (context, snapshot) {
        // Handle loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Handle error state
        if (snapshot.hasError) {
          if (kDebugMode) {
            print("Error in AllListingsTabContent StreamBuilder: ${snapshot.error}");
            print("Stack trace: ${snapshot.stackTrace}");
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Error loading your listings: ${snapshot.error?.toString()}',
                style: const TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        // Handle empty state or no data
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text(
                'You have no produce listings yet.\nTap the "+" button to add your first listing!',
                style: TextStyle(fontSize: 18, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        // Data is available, build the list
        final allListings = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(8.0), // Add some padding around the list
          itemCount: allListings.length,
          itemBuilder: (context, index) {
            final listing = allListings[index];

            // Map ProduceListing data to the parameters required by buildActivityDisplayItem.
            // Ensure your ProduceListing model has all the necessary fields
            // (produceCategory.icon, produceCategory.color, produceName, quantity, unit,
            // pricePerUnit, currency, status.displayName).
            return buildActivityDisplayItem(
              icon: listing.produceCategory.icon,
              iconBgColor: listing.produceCategory.color.withOpacity(0.15), // Lighter background for the icon
              iconColor: listing.produceCategory.color, // Icon with its primary category color
              title: listing.produceName,
              subtitle: "${listing.quantity.toStringAsFixed(1)} ${listing.unit} - ${listing.produceCategory.displayName}",
              amountOrStatus: "${listing.status.displayName}\n"
                  "${listing.pricePerUnit.toStringAsFixed(2)} ${listing.currency}",
            );
          },
        );
      },
    );
  }
}