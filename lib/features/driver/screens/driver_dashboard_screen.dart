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

  StreamSubscription<List<app_order.Order>>? _pickupOrdersSubscription;
  List<app_order.Order> _pickupOrders = []; // For map markers of generally available pickups
  
  StreamSubscription<List<app_order.Order>>? _driverActiveOrdersSubscription;
  List<app_order.Order> _driverActiveOrders = []; // For the bottom sheet

  late FirestoreService _firestoreService;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _firestoreService = Provider.of<FirestoreService>(context, listen: false);
    _currentUser = FirebaseAuth.instance.currentUser;
    _fetchAndSetCurrentLocation(animate: false);
    _subscribeToPickupOrders(); // Keeps showing general pickup locations on map
    if (_currentUser != null) {
      _subscribeToDriverActiveOrders(_currentUser!.uid);
    }
  }

  @override
  void dispose() {
    _pickupOrdersSubscription?.cancel();
    _driverActiveOrdersSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _subscribeToPickupOrders() {
    _pickupOrdersSubscription = _firestoreService.getPickupOrdersForDriver().listen((orders) {
      if (mounted) {
        setState(() {
          _pickupOrders = orders;
          _updateMarkers(); // Update all markers whenever orders change
        });
      }
    }, onError: (error) {
      debugPrint("Error fetching pickup orders: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching pickup orders: $error")),
        );
      }
    });
  }

  void _subscribeToDriverActiveOrders(String driverId) {
    _driverActiveOrdersSubscription = _firestoreService.getDriverActiveOrders(driverId).listen((orders) {
      if (mounted) {
        setState(() {
          _driverActiveOrders = orders;
          // Note: We might want to update map markers too if active orders should have a distinct appearance
          // or if general pickup markers should be filtered if one is taken by this driver.
          // For now, _updateMarkers() primarily uses _pickupOrders.
        });
      }
    }, onError: (error) {
      debugPrint("Error fetching driver's active orders: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching your active orders: $error")),
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
        _updateCurrentLocationMarker(_defaultInitialPosition); // Update this specific marker
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

    // 1. Add/Update current location marker
    final existingCurrentLocationMarker = _markers.firstWhere((m) => m.markerId == _currentLocationMarkerId, orElse: () => const Marker(markerId: MarkerId('none'))); 
    if (existingCurrentLocationMarker.markerId != const MarkerId('none')){
        newMarkers.add(existingCurrentLocationMarker); // Keep the existing one if it has valid position
    } // _updateCurrentLocationMarker handles adding/updating this marker separately and calls setState.
      // So, we rely on _markers already containing the latest current location marker.

    // 2. Add markers for general pickup orders (Azure)
    for (final order in _pickupOrders) {
      // Ensure this order is NOT in the driver's active orders list to avoid duplicate markers
      // if there's any overlap or delay in stream updates.
      bool isAlreadyActiveForThisDriver = _driverActiveOrders.any((activeOrder) => activeOrder.id == order.id);
      if (isAlreadyActiveForThisDriver) continue; 

      if (order.id != null && order.pickupLocation.latitude != 0.0 && order.pickupLocation.longitude != 0.0) {
        newMarkers.add(
          Marker(
            markerId: MarkerId('pickup_${order.id}'), // Prefix to differentiate
            position: LatLng(order.pickupLocation.latitude, order.pickupLocation.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            infoWindow: InfoWindow(
              title: 'Available Pickup: ${order.produceName}',
              snippet: 'Tap for details',
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

    // 3. Add markers for the current driver's active orders (Green) - at their PICKUP location
    for (final order in _driverActiveOrders) {
      if (order.id != null && order.pickupLocation.latitude != 0.0 && order.pickupLocation.longitude != 0.0) {
        newMarkers.add(
          Marker(
            markerId: MarkerId('active_${order.id}'), // Prefix to differentiate
            position: LatLng(order.pickupLocation.latitude, order.pickupLocation.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(
              title: 'Your Active Order: ${order.produceName}',
              snippet: 'Status: ${order.status.displayName}. Tap for details.',
            ),
            onTap: () {
              // Navigate to the active order detail screen which has "Confirm Delivered"
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => DriverActiveOrderDetailScreen(order: order)),
              );
            },
          ),
        );
      }
    }

    setState(() {
      // _markers.clear(); // Clearing and adding all can cause flicker if not careful with current location
      // _markers.addAll(newMarkers); 
      // More controlled update: Replace all non-current-location markers
      _markers.removeWhere((m) => m.markerId != _currentLocationMarkerId);
      _markers.addAll(newMarkers.where((m) => m.markerId != _currentLocationMarkerId));
    });
  }

  // Specific method to update only the current location marker
  void _updateCurrentLocationMarker(LatLng coordinates) {
      if(!mounted) return;
      final newMarker = Marker(
            markerId: _currentLocationMarkerId, 
            position: coordinates,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: const InfoWindow(title: "Your Location"),
          );
      setState(() {
          _markers.removeWhere((m) => m.markerId == _currentLocationMarkerId); // Remove old one if exists
          _markers.add(newMarker); // Add new/updated one
          // No need to call _updateMarkers() here as it might cause loop if called from _fetchAndSetCurrentLocation
      });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const appBarBackgroundColor = Color(0xFF4A2E2B);
    const appBarForegroundColor = Colors.white;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarBackgroundColor,
        foregroundColor: appBarForegroundColor,
        elevation: 0, // For a flatter look, merging with potential top elements
        automaticallyImplyLeading: false,
        title: const Text(
          "Driver Dashboard", 
          style: TextStyle(fontWeight:  FontWeight.bold, fontSize: 18.0, color: appBarForegroundColor), // Ensure title color is set
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location, color: appBarForegroundColor), // Ensure icon color is set
            tooltip: 'Center on my location',
            onPressed: () => _fetchAndSetCurrentLocation(animate: true),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, color: appBarForegroundColor), // Ensure icon color is set
            tooltip: 'Profile',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const DriverProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: Stack( // Changed from Column to Stack for DraggableScrollableSheet
        children: [
          GoogleMap(
            initialCameraPosition: _currentCameraPosition,
            onMapCreated: (GoogleMapController controller) {
              if (!mounted) return;
              _mapController = controller;
               if (_currentCameraPosition.target != _defaultInitialPosition || !_isLoadingLocation) {
                 _mapController!.moveCamera(CameraUpdate.newCameraPosition(_currentCameraPosition));
              }
            },
            markers: _markers,
            myLocationEnabled: false, 
            myLocationButtonEnabled: false, 
            // Padding to ensure FAB or bottom sheet controls don't obscure Google logo/attribution
            // The DraggableScrollableSheet will manage its own space.
            // padding: const EdgeInsets.only(bottom: 10), // Adjusted padding, or let sheet handle it
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
          
          DraggableScrollableSheet(
            initialChildSize: 0.3, // Start at 30% of screen height
            minChildSize: 0.15, // Min at 15%
            maxChildSize: 0.6, // Max at 60%
            builder: (BuildContext context, ScrollController scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF4A2E2B), // Dark brown
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(25.0),
                    topRight: Radius.circular(25.0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 10.0,
                      color: Colors.black26,
                    )
                  ]
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Container( // Optional: Drag handle
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 32.0, bottom: 8.0, top: 0.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Active Orders:",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _driverActiveOrders.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  _currentUser == null ? "Log in to see active orders." : "No active orders assigned to you currently.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController, // Important for DraggableScrollableSheet
                              itemCount: _driverActiveOrders.length,
                              itemBuilder: (context, index) {
                                final order = _driverActiveOrders[index];
                                return ListTile(
                                  leading: Icon(Icons.local_shipping_outlined, color: Colors.white70),
                                  title: Text(order.produceName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  subtitle: Text(
                                    'To: ${order.deliveryLocation.addressHint ?? order.deliveryLocation.barangay ?? 'N/A'}\nStatus: ${order.status.displayName}',
                                    style: TextStyle(color: Colors.white.withOpacity(0.8)),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  isThreeLine: true,
                                  trailing: Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                                  onTap: () {
                                    Navigator.of(context).push(MaterialPageRoute(
                                      builder: (context) => DriverActiveOrderDetailScreen(order: order),
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