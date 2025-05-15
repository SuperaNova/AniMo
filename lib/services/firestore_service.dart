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

} 