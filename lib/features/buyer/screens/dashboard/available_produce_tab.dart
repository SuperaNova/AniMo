import 'package:animo/features/buyer/screens/produce_listing_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:animo/core/models/produce_listing.dart';
import 'package:animo/core/models/match_suggestion.dart'; // Import MatchSuggestion model
import 'package:animo/services/firestore_service.dart';

class AvailableProduceTab extends StatelessWidget {
  const AvailableProduceTab({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    return SingleChildScrollView( // To allow scrolling if content overflows
      padding: const EdgeInsets.only(bottom: 70.0), // Padding for FAB visibility
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Match Suggestions for You" section MOVED HERE
          const Padding(
            padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0), // Added top padding
            child: Text(
              'Match Suggestions for You:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          StreamBuilder<List<MatchSuggestion>>(
            stream: firestoreService.getBuyerMatchSuggestions(), // Assuming this method exists
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ));
              }
              if (snapshot.hasError) {
                debugPrint("Error in AvailableProduceTab Suggestions StreamBuilder: ${snapshot.error}");
                return Center(child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('Error fetching suggestions: ${snapshot.error}'),
                ));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                    child: Text('No new match suggestions for you at the moment.'),
                  ),
                );
              }
              final suggestions = snapshot.data!;
              final relevantSuggestions = suggestions.where((s) =>
              s.status == MatchStatus.pending_buyer_approval ||
                  s.status == MatchStatus.accepted_by_farmer).toList();

              if (relevantSuggestions.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                    child: Text('No suggestions currently requiring your action.'),
                  ),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(), // Important for nested lists
                itemCount: relevantSuggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = relevantSuggestions[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: ListTile(
                      title: Text('Suggestion for: ${suggestion.produceName}'),
                      subtitle: Text(
                          'Farmer: ${suggestion.farmerName ?? 'Unknown'}\nQuantity: ${suggestion.suggestedQuantity} ${suggestion.unit}\nPrice: ${suggestion.suggestedPricePerUnit} ${suggestion.currency} per ${suggestion.unit}\nStatus: ${suggestion.status.displayName}'),
                      isThreeLine: true, // Might need to be true if content is long
                      trailing: (suggestion.status == MatchStatus.pending_buyer_approval ||
                          suggestion.status == MatchStatus.accepted_by_farmer)
                          ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton(
                            icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                            tooltip: 'Accept Suggestion',
                            onPressed: () async {
                              try {
                                MatchStatus nextStatus;
                                // Logic to determine next status based on current suggestion status
                                if (suggestion.status == MatchStatus.pending_buyer_approval) {
                                  nextStatus = MatchStatus.accepted_by_buyer;
                                } else if (suggestion.status == MatchStatus.accepted_by_farmer) {
                                  nextStatus = MatchStatus.confirmed; // Both parties agreed
                                } else {
                                  debugPrint("Unexpected suggestion status on accept: ${suggestion.status}");
                                  return;
                                }
                                await firestoreService.updateMatchSuggestionStatus(
                                  suggestion.id!,
                                  nextStatus,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Suggestion accepted!')),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error accepting suggestion: $e')),
                                  );
                                }
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                            tooltip: 'Reject Suggestion',
                            onPressed: () async {
                              try {
                                await firestoreService.updateMatchSuggestionStatus(
                                  suggestion.id!,
                                  MatchStatus.rejected_by_buyer,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Suggestion rejected.')),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error rejecting suggestion: $e')),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      )
                          : null, // No actions if not actionable by buyer
                    ),
                  );
                },
              );
            },
          ),

          // Divider or SizedBox for separation
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Divider(height: 24.0, thickness: 1.0),
          ),

          // "Available Produce" section
          const Padding(
            padding: EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 8.0), // Adjusted top padding
            child: Text(
              'Available Produce:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          StreamBuilder<List<ProduceListing>>(
            stream: firestoreService.getAllAvailableProduceListings(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ));
              }
              if (snapshot.hasError) {
                debugPrint("Error in AvailableProduceTab StreamBuilder: ${snapshot.error}");
                debugPrintStack(stackTrace: snapshot.stackTrace);
                return Center(child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('Error fetching listings: ${snapshot.error}'),
                ));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                    child: Text('No produce currently available. Tap + to make a request if you don\'t see what you need.'),
                  ),
                );
              }
              final listings = snapshot.data!;
              return ListView.builder(
                padding: const EdgeInsets.only(top: 8.0), // Removed bottom padding here as it's on SingleChildScrollView
                itemCount: listings.length,
                shrinkWrap: true, // Important for nested lists
                physics: const NeverScrollableScrollPhysics(), // Important for nested lists
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
                      isThreeLine: true, // Set to true to ensure enough space for multiline subtitle
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
        ],
      ),
    );
  }
}