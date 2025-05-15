import 'package:animo/features/buyer/screens/produce_listing_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:animo/core/models/produce_listing.dart';
import 'package:animo/services/firestore_service.dart';

class AvailableProduceTab extends StatelessWidget {
  const AvailableProduceTab({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    // final firebaseUser = FirebaseAuth.instance.currentUser; // If needed for display

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Optional: Welcome message or other introductory UI
        // Padding(
        //   padding: const EdgeInsets.all(16.0),
        //   child: Text(
        //     'Welcome, Buyer ${firebaseUser?.displayName?.isNotEmpty == true ? firebaseUser!.displayName : firebaseUser?.email ?? ''}!',
        //     style: Theme.of(context).textTheme.titleLarge,
        //   ),
        // ),
        // The "Available Produce" section from your original BuyerDashboardScreen
        // The Padding for the title "Available Produce" is now handled by the AppBar
        Expanded(
          child: StreamBuilder<List<ProduceListing>>(
            stream: firestoreService.getAllAvailableProduceListings(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                debugPrint("Error in AvailableProduceTab StreamBuilder: ${snapshot.error}");
                debugPrintStack(stackTrace: snapshot.stackTrace);
                return Center(child: Text('Error fetching listings: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No produce currently available. Tap + to make a request if you don\'t see what you need.'),
                  ),
                );
              }
              final listings = snapshot.data!;
              return ListView.builder(
                padding: const EdgeInsets.only(top: 8.0, bottom: 70.0), // Added bottom padding for FAB visibility
                itemCount: listings.length,
                // shrinkWrap: true, // Not needed if Expanded is used and this is the main scrollable
                // physics: const NeverScrollableScrollPhysics(), // Allow scrolling
                itemBuilder: (context, index) {
                  final listing = listings[index];
                  String category = listing.produceCategory.displayName;
                  if (listing.produceCategory == ProduceCategory.other &&
                      listing.customProduceCategory != null &&
                      listing.customProduceCategory!.isNotEmpty) {
                    category += " (${listing.customProduceCategory})";
                  }
                  String harvestInfo = 'Not specified';
                  if (listing.harvestTimestamp != null) {
                    harvestInfo = DateFormat.yMMMd().format(listing.harvestTimestamp!);
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                    child: ListTile(
                      leading: const Icon(Icons.inventory_2_outlined, size: 40, color: Colors.green),
                      title: Text(listing.produceName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Category: $category'),
                          Text('Price: ${listing.pricePerUnit} ${listing.currency} per ${listing.unit}'),
                          Text('Available: ${listing.quantity.toStringAsFixed(1)} ${listing.unit}'),
                          if (listing.farmerName != null && listing.farmerName!.isNotEmpty)
                            Text('Farmer: ${listing.farmerName}'),
                          Text('Location: ${listing.pickupLocation.barangay}, ${listing.pickupLocation.municipality}'),
                          Text('Harvested: $harvestInfo'),
                        ],
                      ),
                      isThreeLine: false, // Adjust based on content, might need to be true
                      contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ProduceListingDetailScreen(listing: listing),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}