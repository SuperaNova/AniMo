import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/models/activity_item.dart';
import '../core/models/app_user.dart';
import '../core/models/farmer_stats.dart';
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
    if (currentUserId == null) {
      throw Exception("User not logged in. Cannot fetch farmer stats.");
    }

    String farmerName = "Unknown Farmer";

    // fetch Farmer's Name using the existing getAppUser method
    try {
      final appUser = await getAppUser(currentUserId!);
      if (appUser != null && appUser.displayName != null && appUser.displayName!.isNotEmpty) {
        farmerName = appUser.displayName!;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error fetching app user for farmer stats ($currentUserId): $e");
      }
      // Farmer name will remain "Unknown Farmer" or could be fetched from listings later
    }

    // Fetch Active ProduceListings for the farmer
    // This is a one-time fetch, not a stream, for calculating current stats.
    final activeListingsQuery = _db
        .collection('produceListings')
        .where('farmerId', isEqualTo: currentUserId)
        .where('status', isEqualTo: ProduceListingStatus.available.name); // Using .name for enum

    final activeListingsSnapshot = await activeListingsQuery.get();

    List<ProduceListing> activeListings = activeListingsSnapshot.docs
        .map((doc) => ProduceListing.fromFirestore(doc.data(), doc.id))
        .toList();

    // Fallback for farmer name if not found via AppUser and listings are available
    if (farmerName == "Unknown Farmer" && activeListings.isNotEmpty) {
      farmerName = activeListings.first.farmerName ?? "Unknown Farmer";
    }

    // Calculate totalActiveListings and totalListingsValue
    int totalActiveListingsCount = activeListings.length;
    double totalListingsValue = 0;
    for (var listing in activeListings) {
      // Ensure quantity is not null, default to 0 if it is (though schema implies it's required)
      totalListingsValue += (listing.quantity) * (listing.pricePerUnit);
    }

    // Create recentActivity from active listings (sorted by creation date, newest first)
    activeListings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    List<ActivityItem> recentActivity = activeListings.map((listing) {
      return ActivityItem(
        icon: listing.produceCategory.icon,
        iconBgColor: listing.produceCategory.color.withOpacity(0.15),
        iconColor: listing.produceCategory.color,
        title: listing.produceName,
        subtitle: "${listing.quantity.toStringAsFixed(1)} ${listing.unit} - ${listing.produceCategory.displayName}",
        trailingText: "${listing.pricePerUnit.toStringAsFixed(2)} ${listing.currency}",
      );
    }).toList();

    // Fetch Pending MatchSuggestions for the farmer
    // These are suggestions made *to* this farmer that they need to approve.
    final pendingSuggestionsQuery = _db
        .collection('matchSuggestions')
        .where('farmerId', isEqualTo: currentUserId)
        .where('status', isEqualTo: MatchStatus.pending_farmer_approval.name); // Using .name for enum

    final pendingSuggestionsSnapshot = await pendingSuggestionsQuery.get();
    int pendingMatchSuggestionsCount = pendingSuggestionsSnapshot.docs.length;

    // Construct and return FarmerStats
    return FarmerStats(
      totalActiveListings: totalActiveListingsCount,
      totalListingsValue: totalListingsValue,
      pendingMatchSuggestions: pendingMatchSuggestionsCount,
      recentActivity: recentActivity,
      farmerName: farmerName,
    );
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
} 