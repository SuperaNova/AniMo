import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import '../core/models/produce_listing.dart';
// Potentially import AppUser if needed to get farmerId easily or for farmer-specific logic

class ProduceListingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionPath = 'produceListings';

  // Create
  Future<String?> addProduceListing({
    required ProduceListing listing,
    // required String farmerId, // Or get from AppUser
  }) async {
    try {
      // Ensure lastUpdated and listingDateTime are set before saving
      // The model might handle this, or we enforce it here/before calling
      final DocumentReference docRef = await _firestore
          .collection(_collectionPath)
          .add(listing.toFirestore());
      return docRef.id;
    } catch (e) {
      print('Error adding produce listing: $e');
      // Consider re-throwing or returning a more specific error
      return null;
    }
  }

  // Read - Stream of listings for a specific farmer
  Stream<List<ProduceListing>> getFarmerProduceListings(String farmerId) {
    return _firestore
        .collection(_collectionPath)
        .where('farmerId', isEqualTo: farmerId)
        // .orderBy('listingDateTime', descending: true) // Optional: order by date
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ProduceListing.fromFirestore(
              doc.data(), doc.id))
          .toList();
    }).handleError((error) {
      print('Error fetching farmer produce listings: $error');
      // Return an empty list or stream an error
      return <ProduceListing>[];
    });
  }

  Stream<List<ProduceListing>> getActiveListings(String farmerId) {
    if (farmerId.isEmpty) {
      // Return an empty stream or throw an error if farmerId is not available
      debugPrint("Farmer ID is empty. Returning empty stream for active listings.");
      return Stream.value([]);
    }

    try {
      return _firestore
          .collection('produceListings')
          .where('farmerId', isEqualTo: farmerId)
          .where('status', isEqualTo: ProduceListingStatus.available)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        // Map each document snapshot to a ProduceListing object
        return snapshot.docs
            .map((doc) => ProduceListing.fromFirestore(doc.data as Map<String, dynamic>, doc.id))
            .toList();
      }).handleError((error) {
        // Handle any errors during the stream processing
        debugPrint("Error fetching active listings: $error");
        return <ProduceListing>[]; // Return empty list on error
      });
    } catch (e) {
      debugPrint("Exception in getActiveListings: $e");
      return Stream.value([]); // Return an empty stream on exception
    }
  }

  Stream<List<ProduceListing>> getFarmerProduceListingsLimited(String farmerId, int limit) {
    if (limit <= 0) {
      debugPrint("FirestoreService: Limit must be greater than 0. Returning empty stream.");
      return Stream.value([]);
    }

    try {
      return _firestore
          .collection('produceListings')
          .where('farmerId', isEqualTo: farmerId)
          .orderBy('createdAt', descending: true)
          .limit(limit) // Apply the limit directly to the Firestore query
          .snapshots()
          .map((snapshot) {
        debugPrint("FirestoreService (Limited): Received ${snapshot.docs.length} listings for $farmerId (limit: $limit)");
        return snapshot.docs.map((doc) {
          return ProduceListing.fromFirestore(doc.data(), doc.id);
        }).toList();
      }).handleError((error, stackTrace) {
        debugPrint("Error in getFarmerProduceListingsLimited stream: $error");
        debugPrint("Stack trace: $stackTrace");
        return <ProduceListing>[]; // Return empty list on error
      });
    } catch (e, stackTrace) {
      debugPrint("Exception caught in getFarmerProduceListingsLimited: $e");
      debugPrint("Stack trace: $stackTrace");
      return Stream.value([]);
    }
  }


  // Read - Get a single listing by ID (might be useful)
  Future<ProduceListing?> getProduceListingById(String listingId) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc =
          await _firestore.collection(_collectionPath).doc(listingId).get();
      if (doc.exists && doc.data() != null) {
        return ProduceListing.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error fetching produce listing by ID: $e');
      return null;
    }
  }
  
  // Update
  Future<bool> updateProduceListing({
    required String listingId,
    required Map<String, dynamic> updates, // Or pass a full ProduceListing object
  }) async {
    try {
      // Ensure 'lastUpdated' is part of the updates map
      // updates['lastUpdated'] = Timestamp.now();
      await _firestore
          .collection(_collectionPath)
          .doc(listingId)
          .update(updates);
      return true;
    } catch (e) {
      print('Error updating produce listing: $e');
      return false;
    }
  }

  // Update specific fields, e.g., status or quantity
  Future<bool> updateListingStatus(String listingId, ProduceListingStatus status) async {
    return await updateProduceListing(
      listingId: listingId,
      updates: {
        'status': produceListingStatusToString(status),
        'lastUpdated': Timestamp.now(),
      },
    );
  }

  Future<bool> updateListingQuantities(String listingId, {double? quantityCommitted, double? quantitySoldAndDelivered}) async {
    Map<String, dynamic> updates = {'lastUpdated': Timestamp.now()};
    if (quantityCommitted != null) {
      updates['quantityCommitted'] = quantityCommitted;
    }
    if (quantitySoldAndDelivered != null) {
      updates['quantitySoldAndDelivered'] = quantitySoldAndDelivered;
    }
    if (updates.length == 1) return true; // Only lastUpdated, nothing to change

    return await updateProduceListing(listingId: listingId, updates: updates);
  }


  // Delete (Soft delete by updating status)
  Future<bool> deleteProduceListing(String listingId) async {
     return await updateListingStatus(listingId, ProduceListingStatus.delisted);
  }

  // TODO: Consider adding methods for:
  // - Fetching available listings for buyers (with filters)
  // - Complex queries as needed for matching
} 