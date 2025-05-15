import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/models/activity_item.dart';
import '../core/models/app_user.dart';
import '../core/models/farmer_stats.dart';
import '../core/models/order.dart';
import '../core/models/produce_listing.dart';
import '../core/models/match_suggestion.dart';
import '../core/models/order.dart' as app_order;
import '../core/models/buyer_request.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // Produce Listings
  Future<void> addProduceListing(ProduceListing listing) async {
    if (currentUserId == null) throw Exception('User not logged in');
    final docRef = _db.collection('produceListings').doc();
    await docRef.set(listing.copyWith(id: docRef.id, farmerId: listing.farmerId).toFirestore());
  }

  Stream<List<ProduceListing>> getFarmerProduceListings() {
    if (currentUserId == null) return Stream.value([]);
    return _db
        .collection('produceListings')
        .where('farmerId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ProduceListing.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  Future<void> updateProduceListing(ProduceListing listing) async {
    if (listing.id == null) throw Exception('Listing ID cannot be null');
    await _db.collection('produceListings').doc(listing.id).update(listing.toFirestore());
  }

  Future<void> deleteProduceListing(String listingId) async {
    await _db.collection('produceListings').doc(listingId).delete();
  }

  // Get all available produce listings for buyers
  Stream<List<ProduceListing>> getAllAvailableProduceListings() {
    return _db
        .collection('produceListings')
        .where('status', isEqualTo: ProduceListingStatus.available.name)
        .orderBy('lastUpdated', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ProduceListing.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Buyer Requests
  Future<void> addBuyerRequest(BuyerRequest request) async {
    if (currentUserId == null || currentUserId != request.buyerId) {
      throw Exception('User not logged in or mismatch in buyer ID');
    }
    final docRef = _db.collection('buyerRequests').doc();
    await docRef.set(request.copyWith(id: docRef.id).toFirestore());
  }

  Stream<List<BuyerRequest>> getBuyerRequests() {
    if (currentUserId == null) return Stream.value([]);
    return _db
        .collection('buyerRequests')
        .where('buyerId', isEqualTo: currentUserId)
        .orderBy('requestDateTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BuyerRequest.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
            .toList());
  }

  Future<void> updateBuyerRequest(BuyerRequest request) async {
    if (request.id == null) throw Exception('BuyerRequest ID cannot be null for an update.');
    if (currentUserId == null || currentUserId != request.buyerId) {
      throw Exception('User not logged in or mismatch in buyer ID for update.');
    }
    // Ensure lastUpdated is set, though the form should already do this.
    final updatedRequest = request.copyWith(lastUpdated: Timestamp.now());
    await _db.collection('buyerRequests').doc(request.id).update(updatedRequest.toFirestore());
  }

  Future<void> updateBuyerRequestStatus(String requestId, BuyerRequestStatus newStatus) async {
    if (currentUserId == null) {
      throw Exception('User not logged in.');
    }
    // Optional: You might want to add a check here to ensure the currentUserId
    // is indeed the buyerId of the request being cancelled, for security.
    // However, this method is generic for status updates, so direct buyerId check might be too specific.
    // For cancellation, the calling UI should ensure it's the buyer's own request.

    final updateData = {
      'status': newStatus.name, // Assumes your BuyerRequestStatus enum uses .name for Firestore string
      'lastUpdated': Timestamp.now(),
    };
    await _db.collection('buyerRequests').doc(requestId).update(updateData);
  }

  // Match Suggestions
  Stream<List<MatchSuggestion>> getFarmerMatchSuggestions() {
    if (currentUserId == null) return Stream.value([]);
    return _db
        .collection('matchSuggestions')
        .where('farmerId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MatchSuggestion.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  Stream<List<MatchSuggestion>> getBuyerMatchSuggestions() {
    if (currentUserId == null) return Stream.value([]);
    return _db
        .collection('matchSuggestions')
        .where('buyerId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MatchSuggestion.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  Future<void> updateMatchSuggestionStatus(String suggestionId, MatchStatus newStatus, {String? rejectionReason}) async {
    Map<String, dynamic> updateData = {'status': newStatus.name};
    if (rejectionReason != null && rejectionReason.isNotEmpty) {
      if (newStatus == MatchStatus.rejected_by_farmer) {
        updateData['farmerRejectionReason'] = rejectionReason;
      } else if (newStatus == MatchStatus.rejected_by_buyer) {
        updateData['buyerRejectionReason'] = rejectionReason;
      }
    }
    updateData['lastUpdated'] = Timestamp.now();
    await _db.collection('matchSuggestions').doc(suggestionId).update(updateData);
  }

  // Orders
  Stream<List<app_order.Order>> getFarmerOrders() {
    if (currentUserId == null) return Stream.value([]);
    return _db
        .collection('orders')
        .where('farmerId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => app_order.Order.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  Future<FarmerStats> getFarmerStats() async {
    if (currentUserId == null || currentUserId!.isEmpty) {
      debugPrint("User not logged in. Cannot fetch farmer stats.");
      throw Exception("User not logged in. Cannot fetch farmer stats.");
    }

    String farmerName = "Unknown Farmer";
    try {
      final userDoc = await _db.collection('users').doc(currentUserId).get(); // Assuming a 'users' collection for farmer name
      if (userDoc.exists && userDoc.data()?['displayName'] != null) {
        farmerName = userDoc.data()!['displayName'];
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error fetching user's display name for FarmerStats: $e");
      }
    }


    final activeListingsQuery = _db
        .collection('produceListings')
        .where('farmerId', isEqualTo: currentUserId)
        .where('status', isEqualTo: ProduceListingStatus.available.name);

    int totalActiveListingsCount = 0;
    double totalListingsValue = 0;
    try {
      final activeListingsSnapshot = await activeListingsQuery.get();
      List<ProduceListing> activeListings = activeListingsSnapshot.docs
          .map((doc) => ProduceListing.fromFirestore(doc.data(), doc.id))
          .toList();

      totalActiveListingsCount = activeListings.length;
      for (var listing in activeListings) {
        totalListingsValue += listing.quantity * listing.pricePerUnit;
      }
      // Fallback for farmer name if not found via users collection and listings are available
      if (farmerName == "Unknown Farmer" && activeListings.isNotEmpty) {
        farmerName = activeListings.first.farmerName ?? "Unknown Farmer";
      }
    } catch (e) {
      debugPrint("Error fetching active listings for stats: $e");
    }

    // This query remains for "Match Suggestions" card
    final pendingMatchSuggestionsQuery = _db
        .collection('matchSuggestions')
        .where('farmerId', isEqualTo: currentUserId)
        .where('status', isEqualTo: MatchStatus.pending_farmer_approval.name);

    int pendingMatchSuggestionsCount = 0;
    try {
      final pendingSuggestionsSnapshot = await pendingMatchSuggestionsQuery.get();
      pendingMatchSuggestionsCount = pendingSuggestionsSnapshot.docs.length;
    } catch(e) {
      debugPrint("Error fetching pending match suggestions count: $e");
    }

    // This query remains for the "Orders to Confirm" card (which might be hidden)
    final pendingConfirmationOrdersQuery = _db
        .collection('orders')
        .where('farmerId', isEqualTo: currentUserId)
        .where('status', isEqualTo: OrderStatus.pending_confirmation.name);

    int pendingConfirmationOrdersCount = 0;
    try {
      final pendingOrdersSnapshot = await pendingConfirmationOrdersQuery.get();
      pendingConfirmationOrdersCount = pendingOrdersSnapshot.docs.length;
    } catch (e) {
      debugPrint("Error fetching pending confirmation orders count: $e");
    }

    // --- NEW: Query for "Active In-Progress Orders" ---
    // These are orders past 'pending_confirmation' but not yet 'completed' or any terminal state.
    // Define statuses that are considered "active and in-progress" for the farmer.
    final List<String> activeInProgressOrderStatuses = [
      OrderStatus.confirmed_by_platform.name,
      OrderStatus.searching_for_driver.name,
      OrderStatus.driver_assigned.name,
      OrderStatus.driver_en_route_to_pickup.name,
      OrderStatus.at_pickup_location.name,
      OrderStatus.picked_up.name,
      OrderStatus.en_route_to_delivery.name,
      OrderStatus.at_delivery_location.name,
      OrderStatus.delivered.name, // 'delivered' is active until 'completed' (payment settled)
    ];

    int activeInProgressOrdersCount = 0;
    if (activeInProgressOrderStatuses.isNotEmpty) { // Check to prevent empty 'whereIn' query
      final activeOrdersQuery = _db
          .collection('orders')
          .where('farmerId', isEqualTo: currentUserId)
          .where('status', whereIn: activeInProgressOrderStatuses);
      try {
        final activeOrdersSnapshot = await activeOrdersQuery.get();
        activeInProgressOrdersCount = activeOrdersSnapshot.docs.length;
      } catch (e) {
        debugPrint("Error fetching active in-progress orders count: $e");
      }
    }


    return FarmerStats(
      totalActiveListings: totalActiveListingsCount,
      totalListingsValue: totalListingsValue,
      pendingMatchSuggestions: pendingMatchSuggestionsCount,
      farmerName: farmerName,
      pendingConfirmationOrdersCount: pendingConfirmationOrdersCount,
      activeInProgressOrdersCount: activeInProgressOrdersCount, // Pass the new count
    );
  }

  Stream<int> watchPendingConfirmationOrdersCount() {
    if (currentUserId == null || currentUserId!.isEmpty) {
      debugPrint("FirestoreService: No currentUserId, returning stream with 0 for pending orders count.");
      return Stream.value(0);
    }
    try {
      return _db
          .collection('orders')
          .where('farmerId', isEqualTo: currentUserId)
          .where('status', isEqualTo: app_order.OrderStatus.pending_confirmation.name)
          .snapshots()
          .map((snapshot) => snapshot.docs.length) // Map the snapshot to the count of documents
          .handleError((error, stackTrace) {
        debugPrint("Error in watchPendingConfirmationOrdersCount stream: $error");
        debugPrintStack(stackTrace: stackTrace);
        return 0; // Return 0 on error
      });
    } catch (e, stackTrace) {
      debugPrint("Exception caught in watchPendingConfirmationOrdersCount: $e");
      debugPrintStack(stackTrace: stackTrace);
      return Stream.value(0);
    }
  }

  Stream<int> watchActiveInProgressOrdersCount() {
    if (currentUserId == null || currentUserId!.isEmpty) {
      debugPrint("FirestoreService: No currentUserId, returning stream with 0 for active orders count.");
      return Stream.value(0);
    }
    final List<String> activeInProgressOrderStatuses = [
      OrderStatus.confirmed_by_platform.name,
      OrderStatus.searching_for_driver.name,
      OrderStatus.driver_assigned.name,
      OrderStatus.driver_en_route_to_pickup.name,
      OrderStatus.at_pickup_location.name,
      OrderStatus.picked_up.name,
      OrderStatus.en_route_to_delivery.name,
      OrderStatus.at_delivery_location.name,
      OrderStatus.delivered.name,
    ];

    if (activeInProgressOrderStatuses.isEmpty) return Stream.value(0);

    try {
      return _db
          .collection('orders')
          .where('farmerId', isEqualTo: currentUserId)
          .where('status', whereIn: activeInProgressOrderStatuses)
          .snapshots()
          .map((snapshot) => snapshot.docs.length)
          .handleError((error, stackTrace) {
        debugPrint("Error in watchActiveInProgressOrdersCount stream: $error");
        debugPrintStack(stackTrace: stackTrace);
        return 0;
      });
    } catch (e, stackTrace) {
      debugPrint("Exception caught in watchActiveInProgressOrdersCount: $e");
      debugPrintStack(stackTrace: stackTrace);
      return Stream.value(0);
    }
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus, {String? farmerNotes, String? cancellationReason}) async {
    if (currentUserId == null || currentUserId!.isEmpty) {
      throw Exception("User not authenticated. Cannot update order status.");
    }
    if (orderId.isEmpty) {
      throw ArgumentError("Order ID cannot be empty.");
    }

    Map<String, dynamic> updateData = {
      'status': newStatus.name,
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    // Add farmer notes if provided
    if (farmerNotes != null && farmerNotes.isNotEmpty) {
      updateData['farmerNotes'] = farmerNotes;
    }

    // Add cancellation reason if the new status is a cancellation by farmer
    if (newStatus == OrderStatus.cancelled_by_farmer && cancellationReason != null && cancellationReason.isNotEmpty) {
      // Assuming you have a field like 'cancellationReason' or 'farmerCancellationReason' in your Order model
      // If not, you might store it in 'farmerNotes' or add a dedicated field.
      // For this example, let's assume 'farmerNotes' can hold this.
      updateData['farmerNotes'] = "Cancelled by farmer: $cancellationReason ${farmerNotes ?? ''}".trim();
      // Or, if you have a specific field:
      // updateData['cancellationReason'] = cancellationReason;
    }

    // Add a new entry to statusHistory
    final statusUpdate = OrderStatusUpdate(
      status: newStatus,
      timestamp: DateTime.now(), // Firestore server timestamp will be more accurate for 'lastUpdated'
      updatedBy: currentUserId, // Log who made the change
      reason: newStatus == OrderStatus.cancelled_by_farmer ? cancellationReason : null,
    );
    updateData['statusHistory'] = FieldValue.arrayUnion([statusUpdate.toMap()]);


    try {
      // Optional: Verify the order belongs to the current farmer before updating
      final orderDoc = await _db.collection('orders').doc(orderId).get();
      if (!orderDoc.exists || orderDoc.data()?['farmerId'] != currentUserId) {
        throw Exception("Order not found or permission denied.");
      }

      await _db.collection('orders').doc(orderId).update(updateData);
      debugPrint("Order $orderId status updated to ${newStatus.name}");
    } catch (e) {
      debugPrint("Error updating order $orderId: $e");
      rethrow; // Rethrow to be handled by the UI
    }
  }

  // Helper to get AppUser data
  Future<AppUser?> getAppUser(String userId) async {
    final docSnap = await _db.collection('users').doc(userId).get();
    if (docSnap.exists && docSnap.data() != null) {
      return AppUser.fromFirestore(docSnap.data()!, docSnap.id);
    }
    return null;
  }

} 