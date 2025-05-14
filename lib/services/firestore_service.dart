import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/models/app_user.dart';
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
            .map((doc) => ProduceListing.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
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
            .map((doc) => ProduceListing.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
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
            .map((doc) => MatchSuggestion.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
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
            .map((doc) => MatchSuggestion.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
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
            .map((doc) => app_order.Order.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
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