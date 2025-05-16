import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/models/produce_listing.dart';
import '../../../../services/firebase_auth_service.dart';
import '../../../../services/firestore_service.dart';
import '../add_edit_produce_listing_screen.dart';
import '../common_widgets.dart';

class AllListingsTabContent extends StatefulWidget {
  const AllListingsTabContent({super.key});

  @override
  State<AllListingsTabContent> createState() => _AllListingsTabContentState();
}

class _AllListingsTabContentState extends State<AllListingsTabContent> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final int _numberOfTabs = 4; // Define number of tabs

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _numberOfTabs, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final colorScheme = Theme.of(context).colorScheme;
    final authService = Provider.of<FirebaseAuthService>(context, listen: false);


    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLow, // Use theme background
      appBar: TabBar( // TabBar is typically placed within an AppBar or as a PreferredSizeWidget
        controller: _tabController,
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        indicatorColor: colorScheme.primary,
        indicatorWeight: 3.0,
        isScrollable: false, // Set to true if tabs don't fit
        tabs: const [
          Tab(text: 'Available'),
          Tab(text: 'Committed'),
          Tab(text: 'Sold Out'),
          Tab(text: 'Other'),
        ],
      ),
      body: StreamBuilder<List<ProduceListing>>(
        stream: firestoreService.getFarmerProduceListings(), // Fetches ALL listings
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            if (kDebugMode) {
              print("Error in AllListingsTabContent StreamBuilder: ${snapshot.error}");
            }
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error loading your listings: ${snapshot.error?.toString()}',
                  style: TextStyle(color: colorScheme.error, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'You have no produce listings yet.\nTap the "+" button to add your first listing!',
                  style: TextStyle(fontSize: 18, color: colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final allListings = snapshot.data!;
          final availableListings = allListings.where((listing) => listing.status == ProduceListingStatus.available).toList();
          final committedListings = allListings.where((listing) => listing.status == ProduceListingStatus.committed).toList();
          final soldOutListings = allListings.where((listing) => listing.status == ProduceListingStatus.sold_out).toList();

          // "Other" will include statuses not explicitly covered above (e.g., expired, delisted)
          final otherStatuses = [
            ProduceListingStatus.available,
            ProduceListingStatus.committed,
            ProduceListingStatus.sold_out,
          ];
          final otherListings = allListings.where((listing) => !otherStatuses.contains(listing.status)).toList();


          return TabBarView(
            controller: _tabController,
            children: [
              _buildListingsListView(context, availableListings, authService, "No available listings."),
              _buildListingsListView(context, committedListings, authService, "No listings committed to orders."),
              _buildListingsListView(context, soldOutListings, authService, "No sold out listings."),
              _buildListingsListView(context, otherListings, authService, "No listings with other statuses."),
            ],
          );
        },
      ),
    );
  }

  Widget _buildListingsListView(
      BuildContext context,
      List<ProduceListing> listings,
      FirebaseAuthService authService,
      String emptyListMessage
      ) {
    final colorScheme = Theme.of(context).colorScheme;

    if (listings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            emptyListMessage,
            style: TextStyle(fontSize: 18, color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12.0),
      itemCount: listings.length,
      itemBuilder: (context, index) {
        final listing = listings[index];
        // Calculate remaining quantity for display.
        // Your ProduceListing model has `quantity` (current available),
        // `initialQuantity`, `quantityCommitted`, `quantitySoldAndDelivered`.
        // For "Available" tab, `listing.quantity` should be the correct remaining quantity.
        // For other statuses, the meaning of `listing.quantity` might differ or be 0.
        double displayQuantity = listing.quantity;
        if (listing.status != ProduceListingStatus.available) {
          // For non-available items, you might want to show initial quantity or 0,
          // or just rely on the status text. Let's show current quantity for now.
          // If current quantity is 0 for sold_out, that's fine.
        }


        return buildProduceListingItem(
            context: context,
            iconData: listing.produceCategory.icon,
            iconBgColor: listing.produceCategory.color.withOpacity(0.15),
            iconColor: listing.produceCategory.color,
            title: listing.produceName,
            categoryName: listing.produceCategory.displayName,
            remainingQuantity: displayQuantity, // Use the determined quantity
            unit: listing.unit,
            pricePerUnit: listing.pricePerUnit,
            currency: listing.currency,
            status: listing.status,
            onTap: () {
              if (authService.currentFirebaseUser != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => AddEditProduceListingScreen(
                      farmerId: authService.currentFirebaseUser!.uid,
                      farmerName: authService.currentFirebaseUser!.displayName,
                      existingListing: listing,
                    ),
                  ),
                );
              }
            }
        );
      },
    );
  }
}
