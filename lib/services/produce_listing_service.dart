import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import '../core/models/produce_listing.dart';
// Potentially import AppUser if needed to get farmerId easily or for farmer-specific logic

/// Service for managing produce listings in Firestore.
///
/// Provides methods for creating, reading, updating, and deleting
/// produce listings, as well as specialized queries for different
/// listing states and pagination.
class ProduceListingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionPath = 'produceListings';

  /// Creates a new produce listing in Firestore.
  ///
  /// Takes a [listing] object containing all the produce listing information
  /// and saves it to the database.
  ///
  /// Returns the ID of the newly created listing, or null if the operation failed.
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

  /// Gets a stream of all produce listings for a specific farmer.
  ///
  /// Provides real-time updates when listings are added, modified, or removed.
  /// Filters listings by the provided [farmerId].
  ///
  /// Returns a stream of [ProduceListing] lists for the specified farmer.
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

  /// Gets a stream of active (available) produce listings for a specific farmer.
  ///
  /// Filters listings by [farmerId] and status equal to [ProduceListingStatus.available].
  /// Results are ordered by creation date, with newest listings first.
  ///
  /// Returns an empty stream if [farmerId] is empty or on error.
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

  /// Gets a limited number of produce listings for a specific farmer.
  ///
  /// Filters listings by [farmerId] and limits results to the specified [limit].
  /// Results are ordered by creation date, with newest listings first.
  ///
  /// Returns an empty stream if [limit] is less than or equal to 0 or on error.
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

  /// Fetches a single produce listing by its ID.
  ///
  /// Retrieves the listing document with the specified [listingId].
  ///
  /// Returns the [ProduceListing] if found, or null if not found or on error.
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
  
  /// Updates an existing produce listing.
  ///
  /// Updates the listing with ID [listingId] with the specified [updates].
  /// The [updates] map should contain the fields to update and their new values.
  ///
  /// Returns true if the update was successful, false otherwise.
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

  /// Updates the status of a produce listing.
  ///
  /// Changes the status of the listing with ID [listingId] to the specified [status].
  /// Also updates the lastUpdated timestamp.
  ///
  /// Returns true if the update was successful, false otherwise.
  Future<bool> updateListingStatus(String listingId, ProduceListingStatus status) async {
    return await updateProduceListing(
      listingId: listingId,
      updates: {
        'status': produceListingStatusToString(status),
        'lastUpdated': Timestamp.now(),
      },
    );
  }

  /// Updates the quantity fields of a produce listing.
  ///
  /// Updates one or both quantity fields of the listing with ID [listingId].
  /// The [quantityCommitted] is the amount reserved for orders.
  /// The [quantitySoldAndDelivered] is the amount already delivered to buyers.
  ///
  /// Returns true if the update was successful or if no changes were needed,
  /// false if the update failed.
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


  /// Soft-deletes a produce listing.
  ///
  /// Changes the status of the listing with ID [listingId] to delisted
  /// rather than actually removing it from the database.
  ///
  /// Returns true if the update was successful, false otherwise.
  Future<bool> deleteProduceListing(String listingId) async {
     return await updateListingStatus(listingId, ProduceListingStatus.delisted);
  }

  // TODO: Consider adding methods for:
  // - Fetching available listings for buyers (with filters)
  // - Complex queries as needed for matching
} 