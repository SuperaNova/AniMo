import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialPosition;
  // Default to somewhere in Cebu if no initial position and current location fails
  static const LatLng defaultInitialPosition = LatLng(10.3157, 123.8854); 

  const MapPickerScreen({super.key, this.initialPosition});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedPosition; // This will now be the center of the map
  // Marker? _selectedMarker; // No longer needed for tap-based selection
  String _selectedAddress = 'Move the map to select a location';
  bool _isLoadingAddress = false; // Renamed for clarity
  bool _isGettingCurrentLocation = true;
  CameraPosition? _currentCameraPosition; // To store camera position

  @override
  void initState() {
    super.initState();
    if (widget.initialPosition != null) {
      _selectedPosition = widget.initialPosition;
      // Initialize camera position as well
      _currentCameraPosition = CameraPosition(target: _selectedPosition!, zoom: 16.0);
      // We'll fetch address once the map is idle and controller is available
      _isGettingCurrentLocation = false;
    } else {
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingCurrentLocation = true;
    });
    try {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location services are disabled.')));
        _setDefaultPosition();
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are denied.')));
          _setDefaultPosition();
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are permanently denied, we cannot request permissions.')));
        _setDefaultPosition();
        return;
      } 

      Position currentPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final newPos = LatLng(currentPosition.latitude, currentPosition.longitude);
      
      setState(() {
        _selectedPosition = newPos;
        _currentCameraPosition = CameraPosition(target: newPos, zoom: 16.0);
        _mapController?.animateCamera(CameraUpdate.newCameraPosition(_currentCameraPosition!));
        // Address will be fetched on camera idle
      });

    } catch (e) {
      print('Error getting current location: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error getting current location: $e. Defaulting location.')));
      _setDefaultPosition();
    } finally {
      if (mounted) {
        setState(() {
          _isGettingCurrentLocation = false;
        });
      }
    }
  }

  void _setDefaultPosition() {
    final defaultPos = MapPickerScreen.defaultInitialPosition;
    if (mounted) {
      setState(() {
        _selectedPosition = defaultPos;
        _currentCameraPosition = CameraPosition(target: defaultPos, zoom: 14.0);
        _mapController?.animateCamera(CameraUpdate.newCameraPosition(_currentCameraPosition!));
        // Address will be fetched on camera idle
      });
    }
  }


  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    // If initial position was set, move camera.
    // If current location was fetched, _currentCameraPosition will be set.
    // If initialPosition is null and _getCurrentLocation failed, _setDefaultPosition would have set _currentCameraPosition.
    if (_currentCameraPosition != null) {
      _mapController?.moveCamera(CameraUpdate.newCameraPosition(_currentCameraPosition!));
    }
    // Fetch address for the initial center after map is created and moved.
    if (_selectedPosition != null) {
      _updateAddressAtMapCenter(_selectedPosition!);
    }
  }

  // Future<void> _onMapTap(LatLng position) async { // No longer needed
  // _updateMarkerAndAddress(position);
  // }

  Future<void> _updateAddressAtMapCenter(LatLng position) async {
    if (!mounted) return;
    setState(() {
      _isLoadingAddress = true;
      _selectedPosition = position; // Ensure _selectedPosition is up-to-date
    });

    try {
      List<geo.Placemark> placemarks = await geo.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        _selectedAddress = 
            "${p.name}, ${p.street}, ${p.subLocality}, ${p.locality}, ${p.subAdministrativeArea}, ${p.administrativeArea} ${p.postalCode}"
            .replaceAll(RegExp(r', , '), ', ') 
            .replaceAll(RegExp(r'^, |,|$'), '');
        if (_selectedAddress.trim() == ',' || _selectedAddress.trim().isEmpty) {
            _selectedAddress = 'Address details not available for this area.';
        }
      } else {
        _selectedAddress = 'No address details found for this location.';
      }
    } catch (e) {
      print('Error during reverse geocoding: $e');
      _selectedAddress = 'Could not fetch address details.';
    } finally {
      if(mounted){
        setState(() {
          _isLoadingAddress = false;
        });
      }
    }
  }
  
  void _onCameraMove(CameraPosition position) {
    // Continuously update the selected position as the map moves.
    // This is for immediate feedback if needed, but geocoding only happens on idle.
    if (!mounted) return;
    setState(() {
      _currentCameraPosition = position;
      _selectedPosition = position.target;
      // Optionally, you can put a temporary "Loading address..." or similar here
      // if you want to give feedback during drag, but it might be too noisy.
      // For now, we only update address text on camera idle.
      // _selectedAddress = "Moving..."; // Example of immediate feedback
    });
  }

  void _onCameraIdle() {
    // Called when the map stops moving.
    if (_mapController == null || !mounted) return;
    
    // It seems _currentCameraPosition might not be immediately updated by onCameraMove in some scenarios
    // before onCameraIdle is called. To be safe, get the current map center again.
    // However, _selectedPosition should be correctly set by _onCameraMove's setState.
    // If _selectedPosition is null, it means something went wrong or map just initialized without interaction.
    if (_selectedPosition != null) {
       _updateAddressAtMapCenter(_selectedPosition!);
    } else if (_currentCameraPosition != null) {
      // Fallback if _selectedPosition somehow wasn't set
      _updateAddressAtMapCenter(_currentCameraPosition!.target);
    }
    print("Camera Idle at: ${_selectedPosition}");
  }

  void _confirmSelection() {
    if (_selectedPosition != null) {
      Map<String, dynamic> result = {
        'latlng': _selectedPosition!,
        'address': _selectedAddress,
      };
      Navigator.of(context).pop(result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location by moving the map.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        actions: [
          if (_isLoadingAddress) // Updated variable name
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)))),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Confirm Location',
            onPressed: _selectedPosition == null ? null : _confirmSelection,
          )
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: _currentCameraPosition ?? CameraPosition( // Use _currentCameraPosition
              target: widget.initialPosition ?? MapPickerScreen.defaultInitialPosition,
              zoom: 14.0,
            ),
            // onTap: _onMapTap, // Removed onTap
            // markers: _selectedMarker != null ? {_selectedMarker!} : {}, // Markers no longer managed this way for selection
            markers: {}, // Clear markers, or add other markers if needed later
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            myLocationEnabled: true, 
            myLocationButtonEnabled: true,
            padding: EdgeInsets.only(bottom: _isLoadingAddress || _selectedAddress.isNotEmpty ? 80 : 10),
          ),
          // Center Marker Icon
          Align(
            alignment: Alignment.center,
            child: Padding(
              // Adjust padding if the icon's "tip" is not exactly at its center
              padding: const EdgeInsets.only(bottom: 0), // Example: if pin tip is at bottom center of icon
              child: Icon(
                Icons.location_pin,
                size: 50, // Adjust size as needed
                color: Theme.of(context).colorScheme.primary, // Use theme color
              ),
            ),
          ),
          if (_isGettingCurrentLocation)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text("Getting current location...")
                ],
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(12.0),
              color: Colors.black.withOpacity(0.7),
              child: Text(
                _isLoadingAddress ? 'Fetching address...' : _selectedAddress, // Updated variable name
                style: const TextStyle(color: Colors.white, fontSize: 14.0),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 