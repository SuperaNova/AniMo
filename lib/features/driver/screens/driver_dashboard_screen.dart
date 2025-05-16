import 'package:flutter/material.dart';
import 'package:animo/services/firebase_auth_service.dart'; // Will use for logout
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart'; // Example if using Provider
import 'package:animo/core/models/order.dart' as app_order; // Assuming your Order model is here
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:geolocator/geolocator.dart'; // For location services
import 'package:animo/features/driver/screens/profile/driver_profile_screen.dart';
import 'package:animo/features/driver/screens/driver_order_detail_screen.dart';
import 'package:animo/services/firestore_service.dart'; // Added for FirestoreService
import 'dart:async'; // For StreamSubscription
import 'package:firebase_auth/firebase_auth.dart'; // For current user ID
import 'package:animo/features/driver/screens/driver_active_order_detail_screen.dart';
import 'package:animo/features/driver/screens/driver_active_orders_screen.dart';

// It's assumed that your Order, LocationInfo, and OrderStatus (if used as an enum)
// are defined in 'package:animo/core/models/order.dart' or other relevant files.

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  static const LatLng _defaultInitialPosition = LatLng(11.2433, 125.0000); // Tacloban as fallback
  CameraPosition _currentCameraPosition = const CameraPosition(
    target: _defaultInitialPosition,
    zoom: 14.0,
  );

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {}; // Combined set for current location and orders
  bool _isLoadingLocation = true;
  String? _locationError;

  // Marker ID for current location
  final MarkerId _currentLocationMarkerId = const MarkerId('currentLocation');

  StreamSubscription<List<app_order.Order>>? _nearbyOrdersSubscription;
  List<app_order.Order> _nearbyOrders = [];
  
  late FirestoreService _firestoreService;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _firestoreService = Provider.of<FirestoreService>(context, listen: false);
    _currentUser = FirebaseAuth.instance.currentUser;
    _fetchAndSetCurrentLocation(animate: false);
    _subscribeToNearbyOrders();
  }

  @override
  void dispose() {
    _nearbyOrdersSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _subscribeToNearbyOrders() {
    _nearbyOrdersSubscription = _firestoreService.getPickupOrdersForDriver().listen((orders) {
      if (mounted) {
        setState(() {
          _nearbyOrders = orders;
          _updateMarkers();
        });
      }
    }, onError: (error) {
      debugPrint("Error fetching nearby available orders: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching nearby orders: $error")),
        );
      }
    });
  }

  Future<void> _fetchAndSetCurrentLocation({bool animate = true}) async {
    if (!mounted) return;
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _handleLocationError('Location services are disabled. Please enable them.');
        _updateCurrentLocationMarker(_defaultInitialPosition);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _handleLocationError('Location permissions are denied.');
          _updateCurrentLocationMarker(_defaultInitialPosition);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _handleLocationError('Location permissions permanently denied. Enable in settings.');
        _updateCurrentLocationMarker(_defaultInitialPosition);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;

      final currentLatLng = LatLng(position.latitude, position.longitude);
      _currentCameraPosition = CameraPosition(target: currentLatLng, zoom: 15.0);

      if (_mapController != null) {
        final cameraUpdate = CameraUpdate.newCameraPosition(_currentCameraPosition);
        animate ? _mapController!.animateCamera(cameraUpdate) : _mapController!.moveCamera(cameraUpdate);
      }
      
      _updateCurrentLocationMarker(currentLatLng);
      if(mounted){
        setState(() {
          _isLoadingLocation = false;
          _locationError = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      _handleLocationError("Cannot fetch current location: ${e.toString()}.");
      _updateCurrentLocationMarker(_defaultInitialPosition);
    } finally {
        if(mounted) setState(() => _isLoadingLocation = false );
    }
  }

  void _handleLocationError(String errorMessage) {
    if (!mounted) return;
    final defaultCameraPosition = const CameraPosition(target: _defaultInitialPosition, zoom: 7.0);
    setState(() {
      _locationError = errorMessage;
      _currentCameraPosition = defaultCameraPosition;
    });
    if (_mapController != null) {
      _mapController!.moveCamera(CameraUpdate.newCameraPosition(defaultCameraPosition));
    }
  }
  
  void _updateMarkers() {
    if (!mounted) return;
    final Set<Marker> newMarkers = {};

    final existingCurrentLocationMarker = _markers.firstWhere((m) => m.markerId == _currentLocationMarkerId, orElse: () => const Marker(markerId: MarkerId('none'))); 
    if (existingCurrentLocationMarker.markerId != const MarkerId('none')){
        newMarkers.add(existingCurrentLocationMarker);
    }

    for (final order in _nearbyOrders) {
      if (order.id != null && order.pickupLocation.latitude != 0.0 && order.pickupLocation.longitude != 0.0) {
        newMarkers.add(
          Marker(
            markerId: MarkerId('nearby_${order.id}'),
            position: LatLng(order.pickupLocation.latitude, order.pickupLocation.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            infoWindow: InfoWindow(
              title: 'Available Order: ${order.produceName}',
              snippet: 'Tap for details to accept',
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => DriverOrderDetailScreen(order: order)),
              );
            },
          ),
        );
      }
    }

    setState(() {
      _markers.removeWhere((m) => m.markerId != _currentLocationMarkerId);
      _markers.addAll(newMarkers.where((m) => m.markerId != _currentLocationMarkerId));
    });
  }

  void _updateCurrentLocationMarker(LatLng coordinates) {
      if(!mounted) return;
      final newMarker = Marker(
            markerId: _currentLocationMarkerId, 
            position: coordinates,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: const InfoWindow(title: "Your Location"),
          );
      setState(() {
          _markers.removeWhere((m) => m.markerId == _currentLocationMarkerId);
          _markers.add(newMarker);
      });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme; // Added for text styling in bottom sheet
    const appBarBackgroundColor = Color(0xFF4A2E2B);
    const appBarForegroundColor = Colors.white;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarBackgroundColor,
        foregroundColor: appBarForegroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          "Driver Dashboard", 
          style: TextStyle(fontWeight:  FontWeight.bold, fontSize: 18.0, color: appBarForegroundColor),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location, color: appBarForegroundColor),
            tooltip: 'Center on my location',
            onPressed: () => _fetchAndSetCurrentLocation(animate: true),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, color: appBarForegroundColor),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const DriverProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _currentCameraPosition,
            onMapCreated: (GoogleMapController controller) {
              if (!mounted) return;
              _mapController = controller;
              _mapController!.setMapStyle(null); 
              if (_currentCameraPosition.target != _defaultInitialPosition || !_isLoadingLocation) {
                _mapController!.moveCamera(CameraUpdate.newCameraPosition(_currentCameraPosition));
              }
            },
            markers: _markers,
            myLocationEnabled: false, 
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            padding: const EdgeInsets.only(bottom: 280.0), 
          ),
          if (_isLoadingLocation) 
             const Center(child: CircularProgressIndicator()),
          if (_locationError != null && !_isLoadingLocation)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8.0),
                color: Colors.red.withOpacity(0.8),
                child: Text(_locationError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
              ),
            ),
          // Nearby Available Orders Bottom Sheet
          DraggableScrollableSheet(
            initialChildSize: 0.30, // Initial peek height (30% from bottom)
            minChildSize: 0.25,   // Min height (25% from bottom)
            maxChildSize: 0.65,   // Max height (65% from bottom)
            builder: (BuildContext context, ScrollController scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF4A2E2B), // Dark brown, same as previous
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(25.0),
                    topRight: Radius.circular(25.0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 10.0,
                      color: Colors.black.withOpacity(0.2),
                    )
                  ]
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Container( // Drag handle
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 24.0, bottom: 12.0, top: 0.0, right: 16.0), // Adjusted padding
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center, // Align items vertically
                        children: [
                          Text(
                            "Nearby Available Orders",
                            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 17),
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.list_alt_outlined, size: 18),
                            label: const Text("Active Orders"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.15), // Subtle background
                              foregroundColor: Colors.white, // Text and icon color
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20.0),
                              ),
                            ),
                            onPressed: () {
                               Navigator.of(context).push(MaterialPageRoute(
                                builder: (context) => const DriverActiveOrdersScreen(),
                              ));
                            },
                          )
                        ],
                      ),
                    ),
                    Expanded(
                      child: _nearbyOrders.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  _isLoadingLocation ? "Fetching location..." : (_currentUser == null ? "Log in to see orders." : "No nearby orders available right now."),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController, // Important for DraggableScrollableSheet
                              itemCount: _nearbyOrders.length,
                              padding: const EdgeInsets.only(bottom: 16.0), // Padding at the bottom of the list
                              itemBuilder: (context, index) {
                                final order = _nearbyOrders[index];
                                // Example: Extracting a simple part of the address for display
                                String shortAddress = order.pickupLocation.barangay ?? order.pickupLocation.municipality ?? 'Details inside';
                                if (order.pickupLocation.addressHint != null && order.pickupLocation.addressHint!.isNotEmpty){
                                  shortAddress = order.pickupLocation.addressHint!;
                                }

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.white24,
                                    child: Icon(Icons.local_offer_outlined, color: Colors.white70, size: 22),
                                  ),
                                  title: Text(order.produceName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  subtitle: Text(
                                    'Qty: ${order.orderedQuantity.toStringAsFixed(order.orderedQuantity.truncateToDouble() == order.orderedQuantity ? 0 : 1)} ${order.unit} - Pickup: $shortAddress',
                                    style: TextStyle(color: Colors.white.withOpacity(0.8)),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                                  onTap: () {
                                    Navigator.of(context).push(MaterialPageRoute(
                                      builder: (context) => DriverOrderDetailScreen(order: order),
                                    ));
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}