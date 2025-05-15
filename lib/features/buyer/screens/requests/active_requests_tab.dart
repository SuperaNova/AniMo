import 'package:animo/features/buyer/screens/add_buyer_request_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:animo/core/models/buyer_request.dart';
import 'package:animo/core/models/match_suggestion.dart'; // Ensure correct path
import 'package:animo/services/firestore_service.dart';

class ActiveRequestsTab extends StatelessWidget {
  const ActiveRequestsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(
        context, listen: false);

    return SingleChildScrollView( // Allows both lists to scroll together if content exceeds screen height
      padding: const EdgeInsets.only(bottom: 70.0),
      // Added bottom padding for FAB visibility
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Your Active Requests" section
          const Padding(
            padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            // Adjusted top padding
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
                debugPrint(
                    "Error in ActiveRequestsTab YourRequests StreamBuilder: ${snapshot
                        .error}");
                return Center(child: Text(
                    'Error fetching your requests: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                        'You have no active produce requests. Tap + to create one.'),
                  ),
                );
              }
              final requests = snapshot.data!;
              return ListView.builder(
                itemCount: requests.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final request = requests[index];
                  String requestStatus = request.status.name.replaceAll(
                      '_', ' ');
                  requestStatus = requestStatus[0].toUpperCase() +
                      requestStatus.substring(1);
                  final bool canEdit = request.status ==
                      BuyerRequestStatus.pending_match;
                  final bool canCancel = request.status ==
                      BuyerRequestStatus.pending_match;

                  return Card(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 6.0),
                    child: ListTile(
                      title: Text(
                          request.produceNeededName ?? 'Unnamed Produce',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Category: ${request.produceNeededCategory}'),
                          Text('Desired: ${request.quantityNeeded
                              .toStringAsFixed(1)} ${request.quantityUnit}'),
                          Text('Status: $requestStatus'),
                          Text('Requested: ${DateFormat.yMMMd().format(
                              request.requestDateTime.toDate())}'),
                          Text('Needed by: ${DateFormat.yMMMd().format(
                              request.deliveryDeadline.toDate())}'),
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
                                    builder: (context) =>
                                        AddBuyerRequestScreen(
                                            existingRequest: request),
                                  ),
                                );
                              },
                            ),
                          if (canCancel)
                            IconButton(
                              icon: const Icon(
                                  Icons.cancel_outlined, color: Colors.red),
                              tooltip: 'Cancel Request',
                              onPressed: () async {
                                // ... (Keep your existing cancel request logic here)
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) =>
                                      AlertDialog(
                                        title: const Text('Cancel Request?'),
                                        content: Text(
                                            'Are you sure you want to cancel your request for "${request
                                                .produceNeededName ??
                                                'this produce'}"?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(
                                                    false),
                                            child: const Text('Keep Request'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(true),
                                            child: const Text('Yes, Cancel'),
                                          ),
                                        ],
                                      ),
                                );
                                if (confirm == true && request.id != null) {
                                  try {
                                    await firestoreService
                                        .updateBuyerRequestStatus(request.id!,
                                        BuyerRequestStatus.cancelled_by_buyer);
                                    if (context.mounted) {
                                      ScaffoldMessenger
                                          .of(context)
                                          .showSnackBar(
                                        SnackBar(content: Text(
                                            'Request for "${request
                                                .produceNeededName ??
                                                'this produce'}" cancelled.')),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger
                                          .of(context)
                                          .showSnackBar(
                                        SnackBar(content: Text(
                                            'Error cancelling request: $e')),
                                      );
                                    }
                                  }
                                }
                              },
                            ),
                        ],
                      ),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(
                              'Tapped on request for ${request
                                  .produceNeededName}')),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),

          // "Match Suggestions for You" section
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
                debugPrint(
                    "Error in ActiveRequestsTab Suggestions StreamBuilder: ${snapshot
                        .error}");
                return Center(child: Text(
                    'Error fetching your suggestions: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                        'No new match suggestions for you at the moment.'),
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
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                        'No suggestions currently requiring your action.'),
                  ),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: relevantSuggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = relevantSuggestions[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 4.0),
                    child: ListTile(
                      title: Text('Suggestion for: ${suggestion.produceName}'),
                      subtitle: Text(
                          'Farmer: ${suggestion.farmerName ??
                              'Unknown'}\nQuantity: ${suggestion
                              .suggestedQuantity} ${suggestion
                              .unit}\nStatus: ${suggestion.status
                              .displayName}'),
                      isThreeLine: true,
                      trailing: (suggestion.status ==
                          MatchStatus.pending_buyer_approval ||
                          suggestion.status == MatchStatus.accepted_by_farmer)
                          ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton(
                            icon: const Icon(Icons.check_circle_outline,
                                color: Colors.green),
                            tooltip: 'Accept Suggestion',
                            onPressed: () async {
                              // ... (Keep your existing accept suggestion logic here)
                              try {
                                MatchStatus nextStatus;
                                if (suggestion.status ==
                                    MatchStatus.pending_buyer_approval) {
                                  nextStatus = MatchStatus.accepted_by_buyer;
                                } else if (suggestion.status ==
                                    MatchStatus.accepted_by_farmer) {
                                  nextStatus = MatchStatus.confirmed;
                                } else {
                                  print(
                                      "Unexpected suggestion status on accept in BuyerDashboard: ${suggestion
                                          .status}");
                                  return;
                                }
                                await firestoreService
                                    .updateMatchSuggestionStatus(
                                  suggestion.id!,
                                  nextStatus,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Suggestion accepted!')),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(
                                        'Error accepting suggestion: $e')),
                                  );
                                }
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                                Icons.cancel_outlined, color: Colors.red),
                            tooltip: 'Reject Suggestion',
                            onPressed: () async {
                              // ... (Keep your existing reject suggestion logic here)
                              try {
                                await firestoreService
                                    .updateMatchSuggestionStatus(
                                  suggestion.id!,
                                  MatchStatus.rejected_by_buyer,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Suggestion rejected.')),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(
                                        'Error rejecting suggestion: $e')),
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
    );
  }
}