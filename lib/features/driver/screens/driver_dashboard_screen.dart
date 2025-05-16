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
import 'dart:convert'; // For json.decode
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import '../../../env_config.dart';

// It's assumed that your Order, LocationInfo, and OrderStatus (if used as an enum)
// are defined in 'package:animo/core/models/order.dart' or other relevant files.

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  // --- Google Maps API Key --- 
  // IMPORTANT: Replace with your actual Google Maps API Key enabled for Directions API
  final String _googleApiKey = EnvConfig.googleMapsDirectionsApiKey;
  // --- 

  static const LatLng _defaultInitialPosition = LatLng(11.2433, 125.0000); // Tacloban as fallback
  CameraPosition _currentCameraPosition = const CameraPosition(
    target: _defaultInitialPosition,
    zoom: 14.0,
  );

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {}; // Combined set for current location and orders
  bool _isLoadingLocation = true;
  String? _locationError;
  LatLng? _currentDriverLocation;

  // Marker ID for current location
  final MarkerId _currentLocationMarkerId = const MarkerId('currentLocation');

  StreamSubscription<List<app_order.Order>>? _nearbyOrdersSubscription;
  List<app_order.Order> _nearbyOrders = [];
  
  StreamSubscription<List<app_order.Order>>? _driverActiveOrdersSubscription; // Re-added
  List<app_order.Order> _driverActiveOrders = []; // Re-added
  final Set<Polyline> _routePolylines = {}; // For storing route polylines
  final PolylinePoints _polylinePoints = PolylinePoints(); // Uncommented

  late FirestoreService _firestoreService;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _firestoreService = Provider.of<FirestoreService>(context, listen: false);
    _currentUser = FirebaseAuth.instance.currentUser;
    _fetchAndSetCurrentLocation(animate: false);
    _subscribeToNearbyOrders();
    if (_currentUser != null) {
      _subscribeToDriverActiveOrders(_currentUser!.uid); // Re-added
    }
  }

  @override
  void dispose() {
    _nearbyOrdersSubscription?.cancel();
    _driverActiveOrdersSubscription?.cancel(); // Re-added
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

  // Re-added method to subscribe to driver's active orders
  void _subscribeToDriverActiveOrders(String driverId) {
    _driverActiveOrdersSubscription = _firestoreService.getDriverActiveOrders(driverId).listen((orders) {
      if (mounted) {
        setState(() {
          _driverActiveOrders = orders;
          _updateMarkers(); // Update markers (will also handle active order markers)
          _updateAllRoutes(); // Calculate and draw routes for these active orders
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

      _currentDriverLocation = LatLng(position.latitude, position.longitude); // Store current location
      _currentCameraPosition = CameraPosition(target: _currentDriverLocation!, zoom: 15.0);

      if (_mapController != null) {
        final cameraUpdate = CameraUpdate.newCameraPosition(_currentCameraPosition);
        animate ? _mapController!.animateCamera(cameraUpdate) : _mapController!.moveCamera(cameraUpdate);
      }
      
      _updateCurrentLocationMarker(_currentDriverLocation!); 
      _updateAllRoutes(); // Re-calculate routes when current location changes
      
      if(mounted){
        setState(() {
          _isLoadingLocation = false;
          _locationError = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      _currentDriverLocation = null;
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
      _routePolylines.clear(); // Clear routes if location fails
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
    if (existingCurrentLocationMarker.markerId != const MarkerId('none') && existingCurrentLocationMarker.position != const LatLng(0,0)) { // Ensure it has a valid position
        newMarkers.add(existingCurrentLocationMarker);
    }

    // 2. Add markers for nearby available orders (Azure)
    for (final order in _nearbyOrders) {
      // Optional: Don't show a nearby order marker if it's already one of the driver's active orders
      bool isAlreadyActiveForThisDriver = _driverActiveOrders.any((activeOrder) => activeOrder.id == order.id);
      if (isAlreadyActiveForThisDriver) continue;

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

    // 3. Add markers for the current driver's ACTIVE orders (Green) - at their PICKUP location
    for (final order in _driverActiveOrders) {
      if (order.id != null && order.pickupLocation.latitude != 0.0 && order.pickupLocation.longitude != 0.0) {
        newMarkers.add(
          Marker(
            markerId: MarkerId('active_pickup_${order.id}'), // Differentiate active order markers
            position: LatLng(order.pickupLocation.latitude, order.pickupLocation.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen), // Green for active
            infoWindow: InfoWindow(
              title: 'Your Active Order (Pickup): ${order.produceName}',
              snippet: 'Status: ${order.status.displayName}. Tap for details.',
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => DriverActiveOrderDetailScreen(order: order)),
              );
            },
          ),
        );
        // Optionally, add a marker for the delivery location of active orders too
        // if (order.deliveryLocation.latitude != 0.0 && order.deliveryLocation.longitude != 0.0) {
        //   newMarkers.add(Marker( ...for delivery location... ));
        // }
      }
    }

    if (mounted) {
      setState(() {
        _markers.clear(); // Clear all
        _markers.addAll(newMarkers); // Add the new set
      });
    }
  }
  
  void _updateCurrentLocationMarker(LatLng coordinates) {
      if(!mounted) return;
      final newMarker = Marker(
            markerId: _currentLocationMarkerId, 
            position: coordinates,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed), // Driver's location
            infoWindow: const InfoWindow(title: "Your Location"),
          );
      if (mounted) {
        setState(() {
            // More controlled update for current location marker specifically
            _markers.removeWhere((m) => m.markerId == _currentLocationMarkerId);
            _markers.add(newMarker);
        });
      }
  }

  Future<void> _updateAllRoutes() async {
    if (!mounted) return;
    _routePolylines.clear();
    if (_currentDriverLocation == null || _driverActiveOrders.isEmpty) {
      if (mounted) setState(() {}); // Clear polylines if no location or no active orders
      return;
    }

    for (final order in _driverActiveOrders) {
      // For simplicity, routing to pickup location. Can be extended to delivery.
      final destination = LatLng(order.pickupLocation.latitude, order.pickupLocation.longitude);
      if (destination.latitude != 0.0 && destination.longitude != 0.0) {
         // Create a unique ID for each polyline based on the order ID
        String polylineIdVal = "route_${order.id}_pickup"; 
        await _getRouteAndDrawPolyline(_currentDriverLocation!, destination, polylineIdVal);
      }
    }
    if (mounted) setState(() {}); // Refresh map with new polylines
  }

  // Route fetching using Google Routes API (v2:computeRoutes)
  Future<void> _getRouteAndDrawPolyline(LatLng origin, LatLng destination, String polylineIdVal) async {
    if (!mounted) return;
    debugPrint("Attempting to get route from $origin to $destination for polyline ID: $polylineIdVal using Routes API (v2:computeRoutes)");

    List<LatLng> polylineCoordinates = [];

    String url = "https://routes.googleapis.com/directions/v2:computeRoutes";

    Map<String, dynamic> requestBody = {
      "origin": {
        "location": {
          "latLng": {
            "latitude": origin.latitude,
            "longitude": origin.longitude
          }
        }
      },
      "destination": {
        "location": {
          "latLng": {
            "latitude": destination.latitude,
            "longitude": destination.longitude
          }
        }
      },
      "travelMode": "DRIVE",
      "routingPreference": "TRAFFIC_AWARE", // Optional
      "computeAlternativeRoutes": false,
      "polylineEncoding": "ENCODED_POLYLINE"
    };

    Map<String, String> headers = {
      "Content-Type": "application/json",
      "X-Goog-Api-Key": _googleApiKey, 
      "X-Goog-FieldMask": "routes.polyline.encodedPolyline,routes.duration,routes.distanceMeters"
    };

    debugPrint("Routes API (v2:computeRoutes) URL for $polylineIdVal: $url");
    debugPrint("Routes API (v2:computeRoutes) Request Body for $polylineIdVal: ${json.encode(requestBody)}");

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && 
            data['routes'].isNotEmpty && 
            data['routes'][0]['polyline'] != null && 
            data['routes'][0]['polyline']['encodedPolyline'] != null) {
          
          String encodedPolyline = data['routes'][0]['polyline']['encodedPolyline'];
          List<PointLatLng> decodedPolylinePoints = _polylinePoints.decodePolyline(encodedPolyline);
          polylineCoordinates = decodedPolylinePoints.map((point) => LatLng(point.latitude, point.longitude)).toList();
          debugPrint("Successfully fetched and decoded route for $polylineIdVal using Routes API (v2:computeRoutes). Points: ${polylineCoordinates.length}");
        } else {
          debugPrint("Routes API (v2:computeRoutes): No route found or polyline missing for $polylineIdVal. Response: ${response.body}");
        }
      } else {
        debugPrint("Failed to fetch directions for $polylineIdVal using Routes API (v2:computeRoutes): HTTP ${response.statusCode}. Response: ${response.body}");
      }
    } catch (e, s) {
      debugPrint("Exception during Routes API (v2:computeRoutes) call for $polylineIdVal: $e\n$s");
    }
    
    // --- Fallback to Mocked polyline points ---
    if (polylineCoordinates.isEmpty) { 
        debugPrint("Using mocked polyline for $polylineIdVal as Routes API (v2:computeRoutes) call failed or returned no coordinates.");
        polylineCoordinates = [
         origin,
         LatLng((origin.latitude + destination.latitude) / 2, (origin.longitude + destination.longitude) / 2 + 0.005),
         destination,
       ];
    }
    // --- End Fallback/Mock ---

    if (polylineCoordinates.isNotEmpty) {
      Polyline polyline = Polyline(
        polylineId: PolylineId(polylineIdVal),
        color: Colors.green.shade600,
        points: polylineCoordinates,
        width: 5,
        consumeTapEvents: true,
        onTap: () {
          debugPrint("Tapped on polyline: $polylineIdVal");
        }
      );
      if (mounted) {
        _routePolylines.removeWhere((p) => p.polylineId.value == polylineIdVal);
        _routePolylines.add(polyline);
        setState(() {}); 
      } else {
         debugPrint("Not mounted, skipping setState for polyline $polylineIdVal");
      }
    } else {
      debugPrint("No polyline coordinates found for $polylineIdVal (real or mock), not drawing route.");
    }
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
            polylines: _routePolylines, // Add polylines to the map
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