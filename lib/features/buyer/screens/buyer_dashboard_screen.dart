import 'package:animo/services/firebase_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animo/core/models/produce_listing.dart';
import 'package:animo/core/models/buyer_request.dart';
import 'package:animo/core/models/match_suggestion.dart';
import 'package:animo/services/firestore_service.dart';
import 'package:intl/intl.dart';
import 'add_buyer_request_screen.dart';
import 'produce_listing_detail_screen.dart';

// TODO: Import AddBuyerRequestScreen when it's created
// import 'add_buyer_request_screen.dart'; 

class BuyerDashboardScreen extends StatelessWidget {
  static const String routeName = '/buyer-dashboard';
  const BuyerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<FirebaseAuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final firebaseUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buyer Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.signOut();
              // Navigator.of(context).pushReplacementNamed(LoginScreen.routeName); // Assuming LoginScreen is the route after logout
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Welcome, Buyer ${firebaseUser?.displayName?.isNotEmpty == true ? firebaseUser!.displayName : firebaseUser?.email ?? ''}!',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Available Produce:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            StreamBuilder<List<ProduceListing>>(
              stream: firestoreService.getAllAvailableProduceListings(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  debugPrint("Error in BuyerDashboard AvailableProduce StreamBuilder: ${snapshot.error}");
                  debugPrintStack(stackTrace: snapshot.stackTrace);
                  return Center(child: Text('Error fetching listings: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No produce currently available. Tap + to make a request if you don\'t see what you need.'),
                  ));
                }
                final listings = snapshot.data!;
                return ListView.builder(
                  itemCount: listings.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    final listing = listings[index];
                    String category = listing.produceCategory.displayName;
                    if (listing.produceCategory == ProduceCategory.other && listing.customProduceCategory != null && listing.customProduceCategory!.isNotEmpty) {
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
                        isThreeLine: false,
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
            const Padding(
              padding: EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
              child: Text(
                'Your Active Requests:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            StreamBuilder<List<BuyerRequest>>(
              stream: firestoreService.getBuyerRequests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  debugPrint("Error in BuyerDashboard YourRequests StreamBuilder: ${snapshot.error}");
                  debugPrintStack(stackTrace: snapshot.stackTrace);
                  return Center(child: Text('Error fetching your requests: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('You have no active produce requests. Tap + to create one.'),
                  ));
                }
                final requests = snapshot.data!;
                return ListView.builder(
                  itemCount: requests.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    String requestStatus = request.status.name.replaceAll('_', ' ');
                    requestStatus = requestStatus[0].toUpperCase() + requestStatus.substring(1);
                    final bool canEdit = request.status == BuyerRequestStatus.pending_match;
                    final bool canCancel = request.status == BuyerRequestStatus.pending_match;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                      child: ListTile(
                        title: Text(request.produceNeededName ?? 'Unnamed Produce', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Category: ${request.produceNeededCategory}'),
                            Text('Desired: ${request.quantityNeeded.toStringAsFixed(1)} ${request.quantityUnit}'),
                            Text('Status: $requestStatus'),
                            Text('Requested: ${DateFormat.yMMMd().format(request.requestDateTime.toDate())}'),
                            if (request.deliveryDeadline != null)
                              Text('Needed by: ${DateFormat.yMMMd().format(request.deliveryDeadline.toDate())}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (canEdit)
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                tooltip: 'Edit Request',
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => AddBuyerRequestScreen(existingRequest: request),
                                    ),
                                  );
                                },
                              ),
                            if (canCancel)
                              IconButton(
                                icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                                tooltip: 'Cancel Request',
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Cancel Request?'),
                                      content: Text(
                                          'Are you sure you want to cancel your request for "${request.produceNeededName ?? 'this produce'}"?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(false),
                                          child: const Text('Keep Request'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(true),
                                          child: const Text('Yes, Cancel'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true && request.id != null) {
                                    try {
                                      await firestoreService.updateBuyerRequestStatus(request.id!, BuyerRequestStatus.cancelled_by_buyer);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Request for "${request.produceNeededName ?? 'this produce'}" cancelled.')),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error cancelling request: $e')),
                                        );
                                      }
                                    }
                                  }
                                },
                              ),
                          ],
                        ),
                        onTap: () {
                          // TODO: Implement navigation to request detail screen
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Tapped on request for ${request.produceNeededName}')),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),

            // ADDED: New section for Match Suggestions for Buyer
            const Padding(
              padding: EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
              child: Text(
                'Match Suggestions for You:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            StreamBuilder<List<MatchSuggestion>>(
              stream: firestoreService.getBuyerMatchSuggestions(), 
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  debugPrint("Error in BuyerDashboard Suggestions StreamBuilder: ${snapshot.error}");
                  debugPrintStack(stackTrace: snapshot.stackTrace);
                  return Center(child: Text('Error fetching your suggestions: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No new match suggestions for you at the moment.'),
                  ));
                }

                final suggestions = snapshot.data!;
                // Filter suggestions that are pending buyer action or accepted by farmer (waiting for buyer)
                final relevantSuggestions = suggestions.where((s) => 
                  s.status == MatchStatus.pending_buyer_approval ||
                  s.status == MatchStatus.accepted_by_farmer
                ).toList();

                if (relevantSuggestions.isEmpty) {
                   return const Center(child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No suggestions currently requiring your action.'),
                  ));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: relevantSuggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = relevantSuggestions[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                      child: ListTile(
                        title: Text('Suggestion for: ${suggestion.produceName}'),
                        subtitle: Text(
                            'Farmer: ${suggestion.farmerName ?? 'Unknown'}\nQuantity: ${suggestion.suggestedQuantity} ${suggestion.unit}\nStatus: ${suggestion.status.displayName}'),
                        isThreeLine: true,
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
                                      if (suggestion.status == MatchStatus.pending_buyer_approval) {
                                        nextStatus = MatchStatus.accepted_by_buyer;
                                      } else if (suggestion.status == MatchStatus.accepted_by_farmer) {
                                        nextStatus = MatchStatus.confirmed;
                                      } else {
                                        print("Unexpected suggestion status on accept in BuyerDashboard: ${suggestion.status}");
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
                          : null,
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddBuyerRequestScreen()),
          );
          // ScaffoldMessenger.of(context).showSnackBar(
          //   const SnackBar(content: Text('Navigate to Add Buyer Request Screen (Coming Soon)')),
          // );
        },
        tooltip: 'Make a Produce Request',
        child: const Icon(Icons.add_shopping_cart),
      ),
    );
  }
} 