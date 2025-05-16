import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:animo/core/models/produce_listing.dart';
import 'package:animo/services/firestore_service.dart';
import 'package:animo/features/buyer/screens/produce_listing_detail_screen.dart';

class MatchSuggestionsScreen extends StatelessWidget {
  static const String routeName = '/buyer-match-suggestions';
  final String? buyerRequestId;
  final String? buyerRequestName;
  
  const MatchSuggestionsScreen({super.key, this.buyerRequestId, this.buyerRequestName});

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final bool isSpecificRequest = buyerRequestId != null && buyerRequestId!.isNotEmpty;
    String appBarTitle = 'Match Suggestions';
    if (isSpecificRequest && buyerRequestName != null && buyerRequestName!.isNotEmpty) {
      appBarTitle = 'Matches for: $buyerRequestName';
    } else if (isSpecificRequest) {
      appBarTitle = 'Matches for Your Request';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
      ),
      body: StreamBuilder<List<ProduceListing>>(
        stream: isSpecificRequest 
                  ? firestoreService.getMatchSuggestionsForRequest(buyerRequestId!) 
                  : firestoreService.getProduceListingsFromMatchSuggestions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            debugPrint("Error in MatchSuggestionsScreen: ${snapshot.error}");
            debugPrintStack(stackTrace: snapshot.stackTrace);
            return Center(child: Text('Error fetching suggestions: ${snapshot.error}'));
          }
          
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            debugPrint("MatchSuggestionsScreen: Snapshot has no data or is empty. Specific request: $isSpecificRequest");
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(isSpecificRequest 
                  ? 'No specific matches found for this request right now.' 
                  : 'No match suggestions available at the moment.'),
              )
            );
          }

          final listings = snapshot.data!;
          debugPrint("MatchSuggestionsScreen: Fetched ${listings.length} matched listings.");
          
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(context, 'Produce Matching Your Needs'),
                _buildListingsList(context, listings),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 4.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildListingsList(
    BuildContext context, 
    List<ProduceListing> listings
  ) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8.0, bottom: 70.0, left: 8.0, right: 8.0),
      itemCount: listings.length,
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
          elevation: 2,
          child: ListTile(
            leading: Icon(
              _getCategoryIcon(listing.produceCategory),
              size: 40, 
              color: Colors.green
            ),
            title: Text(
              listing.produceName, 
              style: const TextStyle(fontWeight: FontWeight.bold)
            ),
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
                const Text('AI Matched: ✓', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
            isThreeLine: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
            onTap: () {
              // Navigate to the produce detail screen
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
  }
  
  IconData _getCategoryIcon(ProduceCategory category) {
    switch (category) {
      case ProduceCategory.vegetable:
        return Icons.eco;
      case ProduceCategory.fruit:
        return Icons.apple;
      case ProduceCategory.grain:
        return Icons.grass;
      case ProduceCategory.herb:
        return Icons.spa;
      case ProduceCategory.processed:
        return Icons.fastfood;
      case ProduceCategory.other:
      default:
        return Icons.inventory_2_outlined;
    }
  }
} 