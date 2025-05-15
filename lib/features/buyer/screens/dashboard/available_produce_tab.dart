// available_produce_tab.dart

import 'package:animo/features/buyer/screens/produce_listing_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:animo/core/models/produce_listing.dart';
import 'package:animo/core/models/match_suggestion.dart';
import 'package:animo/services/firestore_service.dart';
// import 'package:animo/theme/theme.dart'; // Assuming this was for testing, not strictly needed for this change
import 'package:animo/core/screens/map_picker_screen.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'package:cloud_firestore/cloud_firestore.dart'; // Added for FieldValue

// ProductCategoryFilter enum and extension (as you provided)
enum ProductCategoryFilter { all, vegetable, fruit, herb, grain, processed }

extension ProductCategoryFilterExtension on ProductCategoryFilter {
  String get displayName {
    switch (this) {
      case ProductCategoryFilter.all:
        return 'All';
      case ProductCategoryFilter.vegetable:
        return 'Vegetable';
      case ProductCategoryFilter.fruit:
        return 'Fruit';
      case ProductCategoryFilter.herb:
        return 'Herb';
      case ProductCategoryFilter.grain:
        return 'Grain';
      case ProductCategoryFilter.processed:
        return 'Processed';
      default:
        return '';
    }
  }

  bool matches(ProduceCategory? listingCategory) {
    if (listingCategory == null) return false;
    switch (this) {
      case ProductCategoryFilter.all:
        return true;
      case ProductCategoryFilter.vegetable:
        return listingCategory == ProduceCategory.vegetable;
      case ProductCategoryFilter.fruit:
        return listingCategory == ProduceCategory.fruit;
      case ProductCategoryFilter.herb:
        return listingCategory == ProduceCategory.herb;
      case ProductCategoryFilter.grain:
        return listingCategory == ProduceCategory.grain;
      case ProductCategoryFilter.processed:
        return listingCategory == ProduceCategory.other ||
            (listingCategory.displayName.toLowerCase().contains('processed') ||
                (listingCategory == ProduceCategory.other && listingCategory.displayName.toLowerCase().contains('farm product')));
      default:
        return false;
    }
  }
}


class AvailableProduceTab extends StatefulWidget {
  const AvailableProduceTab({super.key});

  @override
  State<AvailableProduceTab> createState() => _AvailableProduceTabState();
}

class _AvailableProduceTabState extends State<AvailableProduceTab> {
  String? _selectedLocationText;
  LatLng? _selectedLocationCoordinates;
  ProductCategoryFilter _selectedCategory = ProductCategoryFilter.all;

  bool _isLoadingUserAddress = true;

  @override
  void initState() {
    super.initState();
    _loadUserDefaultAddress();
  }

  Future<void> _loadUserDefaultAddress() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      if (mounted) setState(() => _isLoadingUserAddress = false);
      return;
    }

    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    try {
      final Map<String, dynamic>? locationData = await firestoreService.getUserDefaultDeliveryLocation(userId);
      if (mounted && locationData != null) {
        setState(() {
          _selectedLocationText = locationData['formattedAddress'] as String?;
          final lat = locationData['latitude'] as double?;
          final lng = locationData['longitude'] as double?;
          if (lat != null && lng != null) {
            _selectedLocationCoordinates = LatLng(lat, lng);
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading default address: $e");
    } finally {
      if (mounted) setState(() => _isLoadingUserAddress = false);
    }
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (context) => const MapPickerScreen()),
    );

    if (result != null) {
      final String? addressString = result['address'] as String?;
      final LatLng? coordinates = result['latlng'] as LatLng?;

      if (mounted) {
        setState(() {
          _selectedLocationText = addressString ?? 'No address selected';
          _selectedLocationCoordinates = coordinates;
        });
      }

      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null && userId.isNotEmpty && addressString != null && coordinates != null) {
        final firestoreService = Provider.of<FirestoreService>(context, listen: false);
        Map<String, dynamic> locationToSave = {
          'formattedAddress': addressString,
          'latitude': coordinates.latitude,
          'longitude': coordinates.longitude,
          'timestamp': FieldValue.serverTimestamp(),
        };
        try {
          await firestoreService.updateUserDefaultDeliveryLocation(userId, locationToSave);
        } catch (e) {
          debugPrint("Error saving delivery address: $e");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not save address: $e'))
            );
          }
        }
      }
    }
  }

  final List<ProductCategoryFilter> _categories = ProductCategoryFilter.values;

  // Helper function to create the slide left (from right) route
  Route _createSlideRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0); // Start from the right (off-screen)
        const end = Offset.zero;      // End at the center (on-screen)
        const curve = Curves.ease;     // Animation curve

        var tween = Tween(begin: begin, end: end);
        var curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: curve,
        );

        return SlideTransition(
          position: tween.animate(curvedAnimation),
          child: child,
        );
      },
      // Optionally, set transition duration:
      // transitionDuration: const Duration(milliseconds: 300),
    );
  }


  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final Color topSheetColor = const Color(0xFF4A2E2B);
    final Color matchSuggestionContainerColor = const Color(0xFF8C524C);
    final Color matchSuggestionTextColor = Colors.white;
    const double bottomSheetRadius = 20.0;

    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 70.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Upper Container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 16.0, bottom: 20.0, left: 16.0, right: 16.0),
              decoration: BoxDecoration(
                color: topSheetColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(bottomSheetRadius),
                  bottomRight: Radius.circular(bottomSheetRadius),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Deliver To Section
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'DELIVER TO',
                              style: textTheme.bodySmall?.copyWith( // Changed from labelSmall for slightly better size
                                color: Colors.white.withOpacity(0.7),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (_isLoadingUserAddress)
                              const Padding(
                                padding: EdgeInsets.only(left: 8.0),
                                child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: _pickLocation,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _isLoadingUserAddress
                                      ? 'Loading address...'
                                      : (_selectedLocationText ?? 'Choose delivery address'),
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(Icons.arrow_drop_down, size: 28, color: Colors.white.withOpacity(0.7)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Categories Bar
                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        final isSelected = category == _selectedCategory;
                        return ChoiceChip(
                          label: Text(category.displayName),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedCategory = category);
                            }
                          },
                          backgroundColor: Colors.white.withOpacity(0.1),
                          selectedColor: colorScheme.primaryContainer,
                          labelStyle: TextStyle(
                            color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.primary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          shape: StadiumBorder(
                              side: BorderSide(
                                color: isSelected ? colorScheme.primary : colorScheme.primary.withOpacity(0.7),
                                width: 1.5,
                              )),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        );
                      },
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                    ),
                  ),
                ],
              ),
            ),

            // Match Suggestions Container
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 16.0),
              child: Card(
                elevation: 2,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
                color: matchSuggestionContainerColor,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Match Suggestions for You:',
                        style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: matchSuggestionTextColor
                        ),
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<List<MatchSuggestion>>(
                        stream: firestoreService.getBuyerMatchSuggestions(),
                        builder: (context, snapshot) {
                          // ... (your existing StreamBuilder for match suggestions, no changes needed here for animation)
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Center(child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(color: matchSuggestionTextColor.withOpacity(0.7)),
                            ));
                          }
                          if (snapshot.hasError) {
                            return Center(child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text('Error fetching suggestions: ${snapshot.error}', style: TextStyle(color: colorScheme.error.withOpacity(0.8))),
                            ));
                          }
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10.0),
                                child: Text('No new match suggestions for you at the moment.',
                                    style: TextStyle(color: matchSuggestionTextColor.withOpacity(0.8))),
                              ),
                            );
                          }
                          final suggestions = snapshot.data!;
                          final relevantSuggestions = suggestions.where((s) =>
                          s.status == MatchStatus.pending_buyer_approval ||
                              s.status == MatchStatus.accepted_by_farmer).toList();

                          if (relevantSuggestions.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10.0),
                                child: Text('No suggestions currently requiring your action.',
                                    style: TextStyle(color: matchSuggestionTextColor.withOpacity(0.8))),
                              ),
                            );
                          }
                          return Column(
                            children: relevantSuggestions.map((suggestion) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8.0),
                                padding: const EdgeInsets.all(12.0),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Suggestion for: ${suggestion.produceName}',
                                              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: matchSuggestionTextColor)),
                                          Text(
                                              'Farmer: ${suggestion.farmerName ?? 'Unknown'}\nQuantity: ${suggestion.suggestedQuantity} ${suggestion.unit}\nPrice: ${suggestion.suggestedPricePerUnit} ${suggestion.currency} per ${suggestion.unit}\nStatus: ${suggestion.status.displayName}',
                                              style: textTheme.bodySmall?.copyWith(color: matchSuggestionTextColor.withOpacity(0.9), height: 1.4)),
                                        ],
                                      ),
                                    ),
                                    if (suggestion.status == MatchStatus.pending_buyer_approval || suggestion.status == MatchStatus.accepted_by_farmer)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: <Widget>[
                                          IconButton(
                                            icon: Icon(Icons.check_circle_outline, color: Colors.greenAccent.shade100),
                                            tooltip: 'Accept Suggestion',
                                            onPressed: () async {
                                              // ... your accept logic
                                            },
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.cancel_outlined, color: Colors.redAccent.shade100.withOpacity(0.9)),
                                            tooltip: 'Reject Suggestion',
                                            onPressed: () async {
                                              // ... your reject logic
                                            },
                                          ),
                                        ],
                                      )
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Divider(height: 16.0, thickness: 1.0),
            ),

            // "Available Produce" section
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
              child: Text(
                'Available Produce:',
                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
              ),
            ),
            StreamBuilder<List<ProduceListing>>(
              stream: firestoreService.getAllAvailableProduceListings(),
              builder: (context, snapshot) {
                // ... (your existing StreamBuilder for available produce)
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(color: colorScheme.primary),
                  ));
                }
                if (snapshot.hasError) {
                  return Center(child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text('Error fetching listings: ${snapshot.error}', style: TextStyle(color: colorScheme.error)),
                  ));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                      child: Text('No produce currently available.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant)),
                    ),
                  );
                }
                final allListings = snapshot.data!;
                final filteredListings = _selectedCategory == ProductCategoryFilter.all
                    ? allListings
                    : allListings.where((listing) => _selectedCategory.matches(listing.produceCategory)).toList();

                if (filteredListings.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                      child: Text(
                        'No produce available in the "${_selectedCategory.displayName}" category.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8.0),
                  itemCount: filteredListings.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    final listing = filteredListings[index];
                    String categoryDisplay = listing.produceCategory.displayName;
                    if (listing.produceCategory == ProduceCategory.other &&
                        listing.customProduceCategory != null &&
                        listing.customProduceCategory!.isNotEmpty) {
                      categoryDisplay += " (${listing.customProduceCategory})";
                    }
                    String harvestInfo = 'Not specified';
                    if (listing.harvestTimestamp != null) {
                      harvestInfo = DateFormat.yMMMd().format(listing.harvestTimestamp!);
                    }

                    return Card(
                      color: colorScheme.surfaceContainerLow,
                      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      elevation: 1.5,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.7))
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          // MODIFIED: Use the custom route for navigation
                          Navigator.of(context).push(
                            _createSlideRoute(ProduceListingDetailScreen(listing: listing)),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: listing.photoUrls.isNotEmpty
                                    ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8.0),
                                  child: Image.network(
                                    listing.photoUrls.first,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                              : null,
                                          color: colorScheme.primary,
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) => Icon(Icons.inventory_2_outlined, size: 40, color: colorScheme.outline),
                                  ),
                                )
                                    : Icon(Icons.inventory_2_outlined, size: 40, color: colorScheme.outline),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      listing.produceName,
                                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text('Category: $categoryDisplay', style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
                                    Text('Price: ${listing.pricePerUnit.toStringAsFixed(2)} ${listing.currency} per ${listing.unit}', style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
                                    Text('Available: ${listing.quantity.toStringAsFixed(1)} ${listing.unit}', style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
                                    if (listing.farmerName != null && listing.farmerName!.isNotEmpty)
                                      Text('Farmer: ${listing.farmerName}', style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
                                    Text('Location: ${listing.pickupLocation.barangay}, ${listing.pickupLocation.municipality}', style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
                                    Text('Harvested: $harvestInfo', style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
                                  ],
                                ),
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
          ],
        ),
      ),
    );
  }
}