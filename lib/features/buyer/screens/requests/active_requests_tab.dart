import 'package:animo/features/buyer/screens/add_buyer_request_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:animo/core/models/buyer_request.dart';
import 'package:animo/services/firestore_service.dart';
import 'package:animo/core/models/produce_listing.dart'; // For ProduceCategory enum (to map icons)

// Helper function to map BuyerRequestStatus to a display string
String _mapBuyerRequestStatusToDisplay(BuyerRequestStatus status) {
  switch (status) {
    case BuyerRequestStatus.pending_match:
      return 'Pending';
    case BuyerRequestStatus.partially_fulfilled:
      return 'Partially Matched';
    case BuyerRequestStatus.fully_fulfilled:
      return 'Matched';
    case BuyerRequestStatus.expired_unmatched:
      return 'Expired';
    case BuyerRequestStatus.cancelled_by_buyer:
      return 'Cancelled';
    default:
      return status.name.replaceAll('_', ' '); // Fallback
  }
}

// Helper function to get an icon based on produce category string
IconData _getIconForCategory(String categoryString) {
  // Attempt to map string to ProduceCategory enum for robust matching
  ProduceCategory? categoryEnum;
  try {
    categoryEnum = ProduceCategory.values.firstWhere(
      (e) => e.displayName.toLowerCase() == categoryString.toLowerCase() || e.name.toLowerCase() == categoryString.toLowerCase()
    );
  } catch (e) {
    // category string doesn't match any enum display name or name
  }

  if (categoryEnum != null) {
    switch (categoryEnum) {
      case ProduceCategory.fruit:
        return Icons.apple; // Example icon for fruit
      case ProduceCategory.vegetable:
        return Icons.local_florist_outlined; // Example icon for vegetable (leaf)
      case ProduceCategory.herb:
        return Icons.grass; // Example icon for herb
      case ProduceCategory.grain:
        return Icons.grain_outlined; // Example icon for grain
      // Add more cases as per your ProduceCategory enum
      default:
        return Icons.inventory_2_outlined; // Default for other/unmatched
    }
  }
  // Fallback if string parsing to enum failed
  if (categoryString.toLowerCase().contains('fruit')) return Icons.apple;
  if (categoryString.toLowerCase().contains('vegetable')) return Icons.local_florist_outlined;
  return Icons.inventory_2_outlined;
}

class ActiveRequestsTab extends StatelessWidget {
  const ActiveRequestsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      color: colorScheme.surface, // Main light background for the tab content
      child: StreamBuilder<List<BuyerRequest>>(
        stream: firestoreService.getBuyerRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            debugPrint("Error in ActiveRequestsTab StreamBuilder: ${snapshot.error}");
            return Center(child: Text('Error fetching your requests: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'You have no active requests. Tap + to create one.',
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant)
                ),
              ),
            );
          }
          final requests = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.only(top:8.0, bottom: 70.0, left: 8.0, right: 8.0), // Padding for the list
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              final bool canEdit = request.status == BuyerRequestStatus.pending_match;
              final bool canCancel = request.status == BuyerRequestStatus.pending_match;

              return Card(
                color: colorScheme.surfaceContainerLow, // Light beige card background
                margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                elevation: 1.5,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12.0),
                  onTap: () {
                    // TODO: Navigate to request detail screen or show options
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Tapped on request: ${request.produceNeededName ?? 'request'}')),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        // Leading Icon
                        Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.red.shade100, // Light pink/red background for icon
                            child: Icon(
                              _getIconForCategory(request.produceNeededCategory),
                              size: 22,
                              color: Colors.red.shade700, // Darker red icon color
                            ),
                          ),
                        ),
                        // Center Content (Name, Quantity, Category)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                request.produceNeededName ?? 'Unnamed Request',
                                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${request.quantityNeeded.toStringAsFixed(1)} ${request.quantityUnit} - ${request.produceNeededCategory}',
                                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Trailing Content (Status, Price)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _mapBuyerRequestStatusToDisplay(request.status),
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant, 
                                fontWeight: FontWeight.bold
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              request.priceRangeMaxPerUnit != null
                                  ? '${request.priceRangeMaxPerUnit!.toStringAsFixed(2)} ${request.currency ?? 'PHP'}'
                                  : 'Any Price',
                              style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                        // Optional: Action buttons (Edit/Cancel) - can be added if needed
                        if (canEdit || canCancel)
                            PopupMenuButton<String>(
                                icon: Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant),
                                onSelected: (value) async {
                                    if (value == 'edit') {
                                        Navigator.of(context).push(
                                            MaterialPageRoute(
                                            builder: (context) => AddBuyerRequestScreen(existingRequest: request),
                                            ),
                                        );
                                    } else if (value == 'cancel') {
                                         bool confirm = await showDialog(
                                            context: context,
                                            builder: (BuildContext context) {
                                              return AlertDialog(
                                                title: const Text('Confirm Cancellation'),
                                                content: Text(
                                                    'Are you sure you want to cancel your request for "${request.produceNeededName ?? 'this produce'}"?'),
                                                actions: <Widget>[
                                                  TextButton(
                                                    child: const Text('Keep Request'),
                                                    onPressed: () => Navigator.of(context).pop(false),
                                                  ),
                                                  TextButton(
                                                    child: const Text('Cancel Request', style: TextStyle(color: Colors.red)),
                                                    onPressed: () => Navigator.of(context).pop(true),
                                                  ),
                                                ],
                                              );
                                            },
                                          ) ?? false;

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
                                    }
                                },
                                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                    if (canEdit)
                                        const PopupMenuItem<String>(
                                            value: 'edit',
                                            child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit Request')),
                                        ),
                                    if (canCancel)
                                        const PopupMenuItem<String>(
                                            value: 'cancel',
                                            child: ListTile(leading: Icon(Icons.cancel_outlined, color: Colors.red), title: Text('Cancel Request', style: TextStyle(color: Colors.red))),
                                        ),
                                ],
                            ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}