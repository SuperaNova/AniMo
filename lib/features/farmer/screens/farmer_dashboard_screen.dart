import 'package:animo/core/models/produce_listing.dart';
import 'package:animo/core/models/match_suggestion.dart';
import 'package:animo/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/firebase_auth_service.dart';
import 'add_edit_produce_listing_screen.dart';

class FarmerDashboardScreen extends StatelessWidget {
  static const String routeName = '/farmer-dashboard';
  const FarmerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<FirebaseAuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final firebaseUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Farmer Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.signOut();
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
                'Welcome, Farmer ${firebaseUser?.displayName?.isNotEmpty == true ? firebaseUser!.displayName : firebaseUser?.email ?? ''}!',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Your Produce Listings:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            StreamBuilder<List<ProduceListing>>(
              stream: firestoreService.getFarmerProduceListings(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  debugPrint("Error in FarmerDashboard Listings StreamBuilder: ${snapshot.error}");
                  debugPrintStack(stackTrace: snapshot.stackTrace);
                  return Center(child: Text('Error fetching listings: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('You have no active produce listings. Tap + to add one.'),
                  ));
                }

                final listings = snapshot.data!;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: listings.length,
                  itemBuilder: (context, index) {
                    final listing = listings[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                      child: ListTile(
                        title: Text(listing.produceName),
                        subtitle: Text(
                            'Quantity: ${listing.quantity} ${listing.unit}${listing.estimatedWeightKgPerUnit != null ? " (~${(listing.quantity * listing.estimatedWeightKgPerUnit!).toStringAsFixed(1)}kg total)" : ""}\nCategory: ${listing.produceCategory.displayName}${listing.customProduceCategory != null && listing.customProduceCategory!.isNotEmpty ? " (${listing.customProduceCategory})" : ""}\nPrice: ${listing.pricePerUnit} ${listing.currency} per ${listing.unit}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => AddEditProduceListingScreen(
                                      farmerId: listing.farmerId,
                                      farmerName: listing.farmerName,
                                      existingListing: listing
                                    ),
                                  ),
                                );
                              },
                              tooltip: 'Edit Listing',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Listing?'),
                                    content: Text(
                                        'Are you sure you want to delete "${listing.produceName}"?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true && listing.id != null) {
                                  try {
                                    await firestoreService.deleteProduceListing(listing.id!);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Listing deleted successfully.')),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error deleting listing: $e')),
                                      );
                                    }
                                  }
                                }
                              },
                              tooltip: 'Delete Listing',
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                );
              },
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
              child: Text(
                'Incoming Match Suggestions:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            StreamBuilder<List<MatchSuggestion>>(
              stream: firestoreService.getFarmerMatchSuggestions(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  debugPrint("Error in FarmerDashboard Suggestions StreamBuilder: ${snapshot.error}");
                  debugPrintStack(stackTrace: snapshot.stackTrace);
                  return Center(child: Text('Error fetching suggestions: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No new match suggestions at the moment.'),
                  ));
                }

                final suggestions = snapshot.data!;
                final relevantSuggestions = suggestions.where((s) => 
                  s.status == MatchStatus.pending_farmer_approval || 
                  s.status == MatchStatus.accepted_by_buyer
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
                            'Buyer: ${suggestion.buyerName ?? 'Unknown'}\nQuantity: ${suggestion.suggestedQuantity} ${suggestion.unit}\nStatus: ${suggestion.status.displayName}'),
                        isThreeLine: true,
                        trailing: (suggestion.status == MatchStatus.pending_farmer_approval || 
                                   suggestion.status == MatchStatus.accepted_by_buyer) 
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                IconButton(
                                  icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                                  tooltip: 'Accept Suggestion',
                                  onPressed: () async {
                                    try {
                                      MatchStatus nextStatus;
                                      if (suggestion.status == MatchStatus.pending_farmer_approval) {
                                        nextStatus = MatchStatus.accepted_by_farmer;
                                      } else if (suggestion.status == MatchStatus.accepted_by_buyer) {
                                        nextStatus = MatchStatus.confirmed;
                                      } else {
                                        print("Unexpected suggestion status on accept in FarmerDashboard: ${suggestion.status}");
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
                                        MatchStatus.rejected_by_farmer,
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
                          : null, // No actions if not pending farmer action
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
          if (firebaseUser != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => AddEditProduceListingScreen(
                  farmerId: firebaseUser.uid,
                  farmerName: firebaseUser.displayName,
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error: User not found. Cannot add listing.'))
            );
          }
        },
        tooltip: 'Add New Listing',
        child: const Icon(Icons.add),
      ),
    );
  }
} 