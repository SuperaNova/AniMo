import 'package:flutter/material.dart';
import 'package:animo/services/firebase_auth_service.dart'; // Will use for logout
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart'; // Example if using Provider
import 'package:animo/core/models/order.dart'; // Assuming your Order model is here
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:geolocator/geolocator.dart'; // For location services

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
  Set<Marker> _markers = {};
  bool _isLoadingLocation = true;
  String? _locationError;

  final MarkerId _selectedLocationMarkerId = const MarkerId('selectedLocation');

  @override
  void initState() {
    super.initState();
    // Fetch current location without animation for initial setup
    _fetchAndSetCurrentLocation(animate: false);
  }

  // --- Location Fetching ---
  Future<void> _fetchAndSetCurrentLocation({bool animate = true}) async {
    if (!mounted) return;
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _handleLocationError('Location services are disabled. Please enable them in your device settings.');
        _updateMapMarker(_defaultInitialPosition);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _handleLocationError('Location permissions are denied. Please grant permission in app settings.');
          _updateMapMarker(_defaultInitialPosition);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _handleLocationError('Location permissions are permanently denied. Please enable them in app settings.');
        _updateMapMarker(_defaultInitialPosition);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      if (!mounted) return;

      final currentLatLng = LatLng(position.latitude, position.longitude);
      _currentCameraPosition = CameraPosition(target: currentLatLng, zoom: 15.0);

      if (_mapController != null) {
        if (animate) {
          _mapController!
              .animateCamera(CameraUpdate.newCameraPosition(_currentCameraPosition));
        } else {
          _mapController!
              .moveCamera(CameraUpdate.newCameraPosition(_currentCameraPosition));
        }
      }
      // If _mapController is null, GoogleMap will use the updated _currentCameraPosition
      // for its initialCameraPosition or onMapCreated will handle it.

      _updateMapMarker(currentLatLng);
      if(mounted){
        setState(() {
          _isLoadingLocation = false;
          _locationError = null;
        });
      }

    } catch (e) {
      if (!mounted) return;
      _handleLocationError("Cannot fetch current location: ${e.toString()}. Showing default location.");
      _updateMapMarker(_defaultInitialPosition); // Ensure marker is at default on error
    }
  }

  void _handleLocationError(String errorMessage) {
    if (!mounted) return;
    final defaultCameraPosition = const CameraPosition(target: _defaultInitialPosition, zoom: 7.0);
    setState(() {
      _locationError = errorMessage;
      _isLoadingLocation = false;
      _currentCameraPosition = defaultCameraPosition;
    });

    // If the map is already created, move it to the default error position
    if (_mapController != null) {
      _mapController!.moveCamera(CameraUpdate.newCameraPosition(defaultCameraPosition));
    }
    // The marker is typically updated by the caller (_fetchAndSetCurrentLocation's catch block)
    // by calling _updateMapMarker(_defaultInitialPosition).
  }

  void _updateMapMarker(LatLng coordinates) {
    if (!mounted) return;
    setState(() {
      _markers = {
        Marker(
          markerId: _selectedLocationMarkerId,
          position: coordinates,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: "Selected Location"), // Or "Current Location" / "Map Center"
        )
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          "All orders near you",
          style: TextStyle(fontSize: 18.0),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                await Provider.of<FirebaseAuthService>(context, listen: false)
                    .signOut();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error signing out: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                SizedBox(
                  height: double.infinity,
                  width: double.infinity,
                  child: _isLoadingLocation && _markers.isEmpty // Show loading only if truly initial and no marker yet
                      ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 10),
                        Text("Fetching your location..."),
                      ],
                    ),
                  )
                      : _locationError != null
                      ? Center( // Error display
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
                          const SizedBox(height: 10),
                          Text(
                            _locationError!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.orange[800], fontSize: 16),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text("Retry Location"),
                            onPressed: () => _fetchAndSetCurrentLocation(animate:false),
                          )
                        ],
                      ),
                    ),
                  )
                      : GoogleMap( // Display map
                    initialCameraPosition: _currentCameraPosition, // Uses latest known position
                    onMapCreated: (GoogleMapController controller) {
                      _mapController = controller;
                      // If location was fetched before map created and is valid, ensure camera is there.
                      if (!_isLoadingLocation && _locationError == null) {
                        _mapController?.moveCamera(
                            CameraUpdate.newCameraPosition(_currentCameraPosition));
                      } else if (_locationError != null) {
                        // If an error occurred before map creation, _currentCameraPosition is default.
                        // Ensure map reflects this.
                        _mapController?.moveCamera(
                            CameraUpdate.newCameraPosition(_currentCameraPosition));
                      }
                      // Ensure marker is updated to reflect the map's current state.
                      _updateMapMarker(_currentCameraPosition.target);
                    },
                    onCameraMove: (CameraPosition position) {
                      // _currentCameraPosition = position; // Only update if you want the marker to follow pan
                    },
                    onCameraIdle: () async {
                      // This logic moves the single marker to the center of the map
                      // when the user stops panning. You might want to reconsider
                      // this if the marker should *only* represent the fetched GPS location.
                      if (_mapController != null) {
                        LatLng newCenter;
                        double currentZoom;
                        try {
                          final LatLngBounds visibleRegion = await _mapController!.getVisibleRegion();
                          newCenter = LatLng(
                            (visibleRegion.northeast.latitude + visibleRegion.southwest.latitude) / 2,
                            (visibleRegion.northeast.longitude + visibleRegion.southwest.longitude) / 2,
                          );
                          currentZoom = await _mapController!.getZoomLevel();
                        } catch (e) {
                          // Fallback to the last known camera position's target if getVisibleRegion fails
                          newCenter = _currentCameraPosition.target;
                          currentZoom = _currentCameraPosition.zoom;
                        }
                        // Update _currentCameraPosition to reflect the new map center
                        _currentCameraPosition = CameraPosition(target: newCenter, zoom: currentZoom);
                        _updateMapMarker(newCenter); // Update marker based on new center
                      }
                    },
                    myLocationEnabled: true, // Shows the blue dot for user's location
                    myLocationButtonEnabled: false, // Hides the default "my location" button
                    markers: _markers,
                    zoomControlsEnabled: false,
                  ),
                ),
                Positioned(
                  bottom: 20,
                  right: 16,
                  child: Material(
                    color: const Color(0xFF8D6E63),
                    borderRadius: BorderRadius.circular(8),
                    elevation: 4.0,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        // Fetch current location and animate map to it
                        _fetchAndSetCurrentLocation(animate: true);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        child: const Icon(
                          Icons.gps_fixed,
                          color: Color(0xFFFFF3E0),
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: StreamBuilder<firestore.QuerySnapshot>(
              stream: firestore.FirebaseFirestore.instance
                  .collection('orders')
                  .where('status', whereIn: [
                'searching_for_driver',
                'confirmed_by_platform',
              ]).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error fetching orders: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final orders = snapshot.data?.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Order.fromFirestore(data, doc.id);
                }).toList();

                if (orders == null || orders.isEmpty) {
                  return const Center(child: Text('No available orders.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return _buildOrderCard(order);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.local_shipping,
                    color: Colors.green[700],
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.produceName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Quantity: ${order.orderedQuantity} ${order.unit}',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildLocationRow(
              icon: Icons.location_on,
              iconColor: Colors.blueAccent,
              label: 'Pickup',
              address: order.pickupLocation.addressHint ?? 'Not specified',
            ),
            const SizedBox(height: 8),
            _buildLocationRow(
              icon: Icons.flag,
              iconColor: Colors.redAccent,
              label: 'Delivery',
              address: order.deliveryLocation.addressHint ?? 'Not specified',
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${order.currency} ${order.totalOrderAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black87,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Accepting Order ID: ${order.id}')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 3,
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Accept Order', style: TextStyle(fontSize: 15)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String address,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}