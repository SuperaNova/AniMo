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
    debugPrint("FirestoreService: getBuyerMatchSuggestions called.");
    if (currentUserId == null) {
      debugPrint("FirestoreService: currentUserId is null, returning empty stream.");
      return Stream.value([]);
    }
    
    // TEST: Direct document fetch by ID
    // This bypasses the query logic entirely and fetches the document directly
    debugPrint("FirestoreService: TEST - Fetching document directly by ID");
    _db.collection('matchSuggestions').doc('eSDa5zYujmPmkKv0Jk6a').get().then((doc) {
      if (doc.exists) {
        debugPrint("DIRECT FETCH SUCCESS! Document exists: ${doc.id}");
        final data = doc.data();
        debugPrint("Document data: buyerId=${data?['buyerId']}, status=${data?['status']}");
      } else {
        debugPrint("DIRECT FETCH FAILED. Document does not exist.");
      }
    }).catchError((e) {
      debugPrint("DIRECT FETCH ERROR: $e");
    });
    
    // Collection name variations
    const collectionNames = [
      'matchSuggestions',  // Original
      'MatchSuggestions',  // Capital M
      'matchsuggestions',  // All lowercase
      'match_suggestions', // Underscore
    ];
    
    for (final collName in collectionNames) {
      debugPrint("FirestoreService: Testing collection name: '$collName'");
      _db.collection(collName)
        .where('buyerId', isEqualTo: 'AkX4izwagvfM7BrE0dd2FAUBKNp2') // Hardcoded ID for test
        .get()
        .then((snapshot) {
          debugPrint("TEST: '$collName' query returned ${snapshot.docs.length} docs");
          if (snapshot.docs.isNotEmpty) {
            for (final doc in snapshot.docs) {
              debugPrint("Found doc ID: ${doc.id} with buyerId=${doc.data()['buyerId']}");
            }
          }
        })
        .catchError((e) {
          debugPrint("TEST: '$collName' query error: $e");
        });
    }

    // Regular query with debug info
    debugPrint("FirestoreService: Regular query for buyerId: $currentUserId");
    return _db
        .collection('matchSuggestions')
        .where('buyerId', isEqualTo: currentUserId)
        // .orderBy('suggestionTimestamp', descending: true) // Temporarily remove orderBy
        .snapshots()
        .map((snapshot) {
          debugPrint("FirestoreService: Snapshot received with ${snapshot.docs.length} docs for buyerId: $currentUserId (Simplified)");
          // SIMPLIFIED MAPPING
          try {
            final suggestions = snapshot.docs.map((doc) {
                debugPrint("FirestoreService: Simplified mapping doc ID: ${doc.id}");
                return MatchSuggestion.fromFirestore(doc.data(), doc.id);
            }).toList();
            debugPrint("FirestoreService: Simplified successfully mapped ${suggestions.length} suggestions for buyerId: $currentUserId");
            return suggestions;
          } catch (e,s) {
            debugPrint("FirestoreService: ERROR in SIMPLIFIED stream map for getBuyerMatchSuggestions: $e\n$s");
            return <MatchSuggestion>[];
          }
        });
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

  Future<String> placeOrder(app_order.Order order) async {
    if (currentUserId == null || currentUserId != order.buyerId) {
      throw Exception('User not logged in or buyer ID mismatch.');
    }
    final docRef = _db.collection('orders').doc();
    // Use server timestamp for createdAt and lastUpdated if they are meant to be set on write
    // Assuming Order model's toFirestore handles this, or we adjust here.
    // For now, assuming Order object is pre-populated with DateTime.now() for these.
    // If Order's toFirestore expects FieldValue.serverTimestamp() for these, adjust there or here.
    // The current Order model toFirestore method does not seem to handle server timestamps.
    // Let's create a new order object with server timestamps for critical date fields.

    final orderWithTimestamps = order.copyWith(
      id: docRef.id,
      createdAt: null, // Will be set by serverTimestamp in toFirestore logic if adapted
      lastUpdated: null, // Will be set by serverTimestamp in toFirestore logic if adapted
      // For now, we'll assume toFirestore needs to be adapted or we pass it explicitly
    );
    
    Map<String, dynamic> orderData = orderWithTimestamps.toFirestore();
    orderData['createdAt'] = FieldValue.serverTimestamp(); // Override if toFirestore doesn't do it
    orderData['lastUpdated'] = FieldValue.serverTimestamp(); // Override if toFirestore doesn't do it
    
    await docRef.set(orderData);
    return docRef.id;
  }

  Stream<List<app_order.Order>> getPickupOrdersForDriver() {
    return _db
        .collection('orders')
        .where('assignedDriverId', isEqualTo: null) // Only fetch orders not yet assigned
        // .where('status', isEqualTo: app_order.OrderStatus.confirmed_by_platform.name) // Stricter: only platform confirmed
        .where('status', whereIn: [ // More lenient: platform confirmed OR actively searching
          app_order.OrderStatus.confirmed_by_platform.name,
          app_order.OrderStatus.searching_for_driver.name,
        ])
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
      final userDoc = await _db.collection('users').doc(currentUserId).get();
      if (userDoc.exists && userDoc.data()?['displayName'] != null) {
        farmerName = userDoc.data()!['displayName'];
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error fetching user's display name for FarmerStats: $e");
      }
    }

    // Fetch Active ProduceListings for totalActiveListingsCount AND totalActiveListingsValue
    final activeListingsQuery = _db
        .collection('produceListings')
        .where('farmerId', isEqualTo: currentUserId)
        .where('status', isEqualTo: ProduceListingStatus.available.name);

    int totalActiveListingsCount = 0;
    double totalActiveListingsValue = 0; // New variable for this sum
    try {
      final activeListingsSnapshot = await activeListingsQuery.get();
      List<ProduceListing> activeListings = activeListingsSnapshot.docs
          .map((doc) => ProduceListing.fromFirestore(doc.data(), doc.id))
          .toList();

      totalActiveListingsCount = activeListings.length;
      for (var listing in activeListings) {
        // Calculate value of active listings: current quantity * price
        totalActiveListingsValue += listing.quantity * listing.pricePerUnit;
      }

      if (farmerName == "Unknown Farmer" && activeListings.isNotEmpty) {
        farmerName = activeListings.first.farmerName ?? "Unknown Farmer";
      }
    } catch (e) {
      debugPrint("Error fetching active listings for stats: $e");
    }

    // Calculate totalValueFromCompletedOrders (this was previously totalListingsValue)
    double totalValueFromCompletedOrders = 0;
    final completedOrdersQuery = _db
        .collection('orders')
        .where('farmerId', isEqualTo: currentUserId)
        .where('status', isEqualTo: OrderStatus.completed.name);

    try {
      final completedOrdersSnapshot = await completedOrdersQuery.get();
      List<app_order.Order> completedOrders = completedOrdersSnapshot.docs
          .map((doc) => app_order.Order.fromFirestore(doc.data(), doc.id))
          .toList();

      for (var order in completedOrders) {
        totalValueFromCompletedOrders += order.totalOrderAmount;
      }
    } catch (e) {
      debugPrint("Error fetching completed orders value for stats: $e");
    }

    // ... (rest of the counts remain the same: pendingMatchSuggestions, pendingConfirmationOrders, activeInProgress, delivered)
    final pendingMatchSuggestionsQuery = _db
        .collection('matchSuggestions')
        .where('farmerId', isEqualTo: currentUserId)
        .where('status', isEqualTo: MatchStatus.pending_farmer_approval.name);
    int pendingMatchSuggestionsCount = 0;
    try {
      final snap = await pendingMatchSuggestionsQuery.get();
      pendingMatchSuggestionsCount = snap.docs.length;
    } catch(e) { debugPrint("Error: $e");}


    final pendingConfirmationOrdersQuery = _db
        .collection('orders')
        .where('farmerId', isEqualTo: currentUserId)
        .where('status', isEqualTo: OrderStatus.pending_confirmation.name);
    int pendingConfirmationOrdersCount = 0;
    try {
      final snap = await pendingConfirmationOrdersQuery.get();
      pendingConfirmationOrdersCount = snap.docs.length;
    } catch(e) { debugPrint("Error: $e");}

    final List<String> activeInProgressOrderStatuses = [
      OrderStatus.confirmed_by_platform.name,
      OrderStatus.searching_for_driver.name,
      OrderStatus.driver_assigned.name,
      OrderStatus.driver_en_route_to_pickup.name,
      OrderStatus.at_pickup_location.name,
      OrderStatus.picked_up.name,
      OrderStatus.en_route_to_delivery.name,
      OrderStatus.at_delivery_location.name,
    ];
    int activeInProgressOrdersCount = 0;
    if(activeInProgressOrderStatuses.isNotEmpty){
      final activeOrdersQuery = _db
          .collection('orders')
          .where('farmerId', isEqualTo: currentUserId)
          .where('status', whereIn: activeInProgressOrderStatuses);
      try{
        final snap = await activeOrdersQuery.get();
        activeInProgressOrdersCount = snap.docs.length;
      } catch(e) { debugPrint("Error: $e");}
    }


    final deliveredOrdersQuery = _db
        .collection('orders')
        .where('farmerId', isEqualTo: currentUserId)
        .where('status', isEqualTo: OrderStatus.delivered.name);
    int deliveredOrdersToCompleteCount = 0;
    try {
      final snap = await deliveredOrdersQuery.get();
      deliveredOrdersToCompleteCount = snap.docs.length;
    } catch(e) { debugPrint("Error: $e");}


    return FarmerStats(
      totalActiveListings: totalActiveListingsCount,
      totalActiveListingsValue: totalActiveListingsValue, // Pass new value
      totalListingsValue: totalValueFromCompletedOrders, // This now clearly means completed orders value
      pendingMatchSuggestions: pendingMatchSuggestionsCount,
      farmerName: farmerName,
      pendingConfirmationOrdersCount: pendingConfirmationOrdersCount,
      activeInProgressOrdersCount: activeInProgressOrdersCount,
      deliveredOrdersToCompleteCount: deliveredOrdersToCompleteCount,
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

  Stream<int> watchDeliveredOrdersToCompleteCount() {
    if (currentUserId == null || currentUserId!.isEmpty) {
      debugPrint("FirestoreService: No currentUserId, returning stream with 0 for delivered orders count.");
      return Stream.value(0);
    }
    try {
      return _db
          .collection('orders')
          .where('farmerId', isEqualTo: currentUserId)
          .where('status', isEqualTo: OrderStatus.delivered.name)
          .snapshots()
          .map((snapshot) => snapshot.docs.length)
          .handleError((error, stackTrace) {
        debugPrint("Error in watchDeliveredOrdersToCompleteCount stream: $error");
        debugPrintStack(stackTrace: stackTrace);
        return 0;
      });
    } catch (e, stackTrace) {
      debugPrint("Exception caught in watchDeliveredOrdersToCompleteCount: $e");
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

  // Method to update user's default delivery location
  Future<void> updateUserDefaultDeliveryLocation(String userId, Map<String, dynamic> locationData) async {
    if (userId.isEmpty) throw Exception('User ID cannot be empty.');
    try {
      await _db.collection('users').doc(userId).update({
        'defaultDeliveryLocation': locationData,
        'updatedAt': FieldValue.serverTimestamp(), // Also update the user doc's last update time
      });
    } catch (e) {
      print("Error updating user delivery location: $e");
      // Optionally rethrow or handle more gracefully
      rethrow;
    }
  }

  // Method to get user's default delivery location
  Future<Map<String, dynamic>?> getUserDefaultDeliveryLocation(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final docSnap = await _db.collection('users').doc(userId).get();
      if (docSnap.exists && docSnap.data() != null) {
        final data = docSnap.data()!;
        return data['defaultDeliveryLocation'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print("Error fetching user delivery location: $e");
      return null;
    }
  }

  Stream<List<ProduceListing>> getFarmerListings(String farmerId) {
    return _db
        .collection('produceListings')
        .where('farmerId', isEqualTo: farmerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ProduceListing.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Method to get orders for a specific buyer
  Stream<List<app_order.Order>> getOrdersForBuyer(String buyerId) {
    return _db
        .collection('orders')
        .where('buyerId', isEqualTo: buyerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return app_order.Order.fromFirestore(doc.data(), doc.id);
      }).toList();
    });
  }

  // Method to get active orders for a specific driver
  Stream<List<app_order.Order>> getDriverActiveOrders(String driverId) {
    return _db
        .collection('orders')
        .where('assignedDriverId', isEqualTo: driverId)
        .where('status', whereIn: [
          app_order.OrderStatus.driver_assigned.name,
          app_order.OrderStatus.driver_en_route_to_pickup.name,
          app_order.OrderStatus.at_pickup_location.name,
          app_order.OrderStatus.picked_up.name,
          app_order.OrderStatus.en_route_to_delivery.name,
          app_order.OrderStatus.at_delivery_location.name,
        ])
        .orderBy('createdAt', descending: true) // Or perhaps by lastUpdated or a specific delivery priority field
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return app_order.Order.fromFirestore(doc.data(), doc.id);
      }).toList();
    });
  }

  // Method for driver to update order status, e.g., to delivered
  Future<void> updateOrderStatusForDriver(String orderId, String driverId, app_order.OrderStatus newStatus) async {
    // Ensure the logged-in user is the one performing this action if critical,
    // though driverId parameter already helps scope this.
    if (currentUserId == null || currentUserId != driverId) {
      throw Exception("User not authorized or not logged in to update this order for driver actions.");
    }

    Map<String, dynamic> updateData = {
      'status': newStatus.name,
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    // If moving to 'delivered', also set actualDeliveryTime
    if (newStatus == app_order.OrderStatus.delivered) {
      updateData['actualDeliveryTime'] = FieldValue.serverTimestamp();
      // Potentially add a new entry to statusHistory here as well
    }
    // If moving to other statuses like 'at_pickup_location', 'picked_up', driver could log those times too.
    // For instance, if newStatus == app_order.OrderStatus.picked_up:
    // updateData['actualPickupTime'] = FieldValue.serverTimestamp();


    await _db.collection('orders').doc(orderId).update(updateData);

    // Optional: Add to status history (if your Order model and Firestore structure supports it clearly)
    // Example: Add a new OrderStatusUpdate object to the statusHistory array.
    // This might require fetching the order first, adding to the list, then updating, or using FieldValue.arrayUnion.
    // For simplicity, direct status update is done. Status history can be a more advanced feature or handled by backend triggers.
  }

  // Method for driver to accept a pickup order
  Future<void> acceptOrderForDriver(String orderId, String driverId) async {
    if (currentUserId == null || currentUserId != driverId) {
      throw Exception("User not authorized or not logged in to accept this order.");
    }

    final orderRef = _db.collection('orders').doc(orderId);

    // Check current status to prevent re-accepting or accepting an invalid order
    final orderSnapshot = await orderRef.get();
    if (!orderSnapshot.exists) {
      throw Exception("Order not found.");
    }
    final currentStatus = app_order.orderStatusFromString(orderSnapshot.data()?['status'] as String?);
    final alreadyAssignedDriver = orderSnapshot.data()?['assignedDriverId'] as String?;

    if (alreadyAssignedDriver != null && alreadyAssignedDriver.isNotEmpty) {
         if (alreadyAssignedDriver == driverId) {
            throw Exception("You have already accepted this order.");
         } else {
            throw Exception("Order has already been taken by another driver.");
         }
    }
    
    // Only allow acceptance if it's in a state ready for pickup by a driver
    if (currentStatus != app_order.OrderStatus.confirmed_by_platform && 
        currentStatus != app_order.OrderStatus.searching_for_driver) {
      throw Exception("Order is not in a state to be accepted (current: ${currentStatus.displayName}).");
    }

    Map<String, dynamic> updateData = {
      'status': app_order.OrderStatus.driver_assigned.name,
      'assignedDriverId': driverId,
      'lastUpdated': FieldValue.serverTimestamp(),
      // 'statusHistory': FieldValue.arrayUnion([ // Example if adding to status history
      //   app_order.OrderStatusUpdate(
      //     status: app_order.OrderStatus.driver_assigned,
      //     updatedAt: Timestamp.now(), // Or server timestamp if possible through a more complex update
      //     updatedBy: driverId,
      //     notes: 'Order accepted by driver.'
      //   ).toMap(),
      // ]),
    };

    await orderRef.update(updateData);
  }

  // New method to get produce listings from match suggestions for the current buyer
  Stream<List<ProduceListing>> getProduceListingsFromMatchSuggestions() {
    debugPrint("FirestoreService: getProduceListingsFromMatchSuggestions called.");
    if (currentUserId == null) {
      debugPrint("FirestoreService: currentUserId is null, returning empty stream.");
      return Stream.value([]);
    }
    
    debugPrint("FirestoreService: Fetching match suggestions for buyerId: $currentUserId");
    
    // First get the match suggestions to extract listingIds
    return _db
        .collection('matchSuggestions')
        .where('buyerId', isEqualTo: currentUserId)
        .snapshots()
        .asyncMap((snapshot) async {
          debugPrint("FirestoreService: Found ${snapshot.docs.length} match suggestions for buyerId: $currentUserId");
          
          // Extract all listingIds from the match suggestions
          final listingIds = snapshot.docs
              .map((doc) => doc.data()['listingId'] as String?)
              .where((id) => id != null && id.isNotEmpty)
              .toList();
          
          debugPrint("FirestoreService: Extracted ${listingIds.length} listingIds from match suggestions");
          
          if (listingIds.isEmpty) {
            return <ProduceListing>[];
          }
          
          // Now fetch all the produceListings with these IDs
          try {
            // Split into chunks of 10 if needed (Firestore limit for 'in' queries)
            final List<ProduceListing> allListings = [];
            
            // Firestore allows up to 10 values in 'whereIn' query
            for (int i = 0; i < listingIds.length; i += 10) {
              final end = (i + 10 < listingIds.length) ? i + 10 : listingIds.length;
              final chunk = listingIds.sublist(i, end);
              
              debugPrint("FirestoreService: Fetching chunk of ${chunk.length} listingIds");
              final snapshot = await _db
                  .collection('produceListings')
                  .where(FieldPath.documentId, whereIn: chunk)
                  .get();
              
              final listings = snapshot.docs
                  .map((doc) => ProduceListing.fromFirestore(doc.data(), doc.id))
                  .toList();
              
              allListings.addAll(listings);
            }
            
            debugPrint("FirestoreService: Successfully fetched ${allListings.length} produce listings from match suggestions");
            return allListings;
          } catch (e, s) {
            debugPrint("FirestoreService: ERROR fetching produce listings from match suggestions: $e\n$s");
            return <ProduceListing>[];
          }
        });
  }
} 