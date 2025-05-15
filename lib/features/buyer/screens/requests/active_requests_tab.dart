import 'package:animo/features/buyer/screens/add_buyer_request_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:animo/core/models/buyer_request.dart';
import 'package:animo/services/firestore_service.dart';

class ActiveRequestsTab extends StatelessWidget {
  const ActiveRequestsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 70.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Your Active Requests" section
          const Padding(
            padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
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
                debugPrint("Error in ActiveRequestsTab YourRequests StreamBuilder: ${snapshot.error}");
                return Center(child: Text('Error fetching your requests: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('You have no active produce requests. Tap + to create one.'),
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
        ],
      ),
    );
  }
}