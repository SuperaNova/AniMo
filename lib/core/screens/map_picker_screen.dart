import 'dart:async';
import 'dart:convert';
import 'dart:io' if (dart.library.html) 'dart:html' as platform;
import 'dart:js' as js;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../env_config.dart';


class MapPickerScreen extends StatefulWidget {
  final LatLng? initialPosition;
  static const LatLng defaultInitialPosition = LatLng(10.3157, 123.8854); 
  static const String apiKey = EnvConfig.googleMapsWebApiKey;

  const MapPickerScreen({super.key, this.initialPosition});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedPosition;
  String _selectedAddress = 'Move the map to select a location';
  String? _selectedMunicipality;
  String? _selectedBarangay;
  String? _selectedPlaceName;
  bool _isLoadingAddress = false;
  bool _isGettingCurrentLocation = true;
  CameraPosition? _currentCameraPosition;
  Timer? _debounceTimer;
  String? _selectedStreet;
  bool _mapsInitialized = true; // Optimistically assume maps will load

  @override
  void initState() {
    super.initState();
    
    // Check if Google Maps is available (for web)
    if (kIsWeb) {
      _checkGoogleMapsAvailability();
    }
    
    if (widget.initialPosition != null) {
      _moveCameraTo(widget.initialPosition!, zoom: 16.0);
      _isGettingCurrentLocation = false;
    } else {
      _getCurrentLocation();
    }
  }

  // Check if Google Maps API is loaded
  void _checkGoogleMapsAvailability() {
    if (kIsWeb) {
      try {
        // Try to access google maps in JS
        var maps = js.context['google']?['maps'];
        if (maps == null) {
          print('WARNING: Google Maps not available at initialization');
          setState(() {
            _mapsInitialized = false;
          });
          
          // Setup a listener to check when maps becomes available
          js.context['checkGoogleMapsLoaded'] = js.allowInterop(() {
            if (js.context['google']?['maps'] != null) {
              print('Maps became available!');
              if (mounted) {
                setState(() {
                  _mapsInitialized = true;
                });
              }
              return true;
            }
            return false;
          });
          
          // Poll for Maps availability
          final checkInterval = 1000; // ms
          js.context.callMethod('setInterval', [
            js.allowInterop(() {
              final available = js.context.callMethod('checkGoogleMapsLoaded', []);
              if (available == true) {
                js.context.callMethod('clearInterval', [js.context['mapsCheckInterval']]);
              }
            }),
            checkInterval
          ]);
        }
      } catch (e) {
        print('Error checking for Google Maps: $e');
        setState(() {
          _mapsInitialized = false;
        });
      }
    }
  }
  
  @override
  void dispose() {
    _debounceTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingCurrentLocation = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showMessage('Location services are disabled.');
        _setDefaultPosition();
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) {
          _showMessage('Location permissions are denied.');
          _setDefaultPosition();
          return;
        }
      }
      if (perm == LocationPermission.deniedForever) {
        _showMessage('Location permissions are permanently denied.');
        _setDefaultPosition();
        return;
      }
      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _moveCameraTo(LatLng(pos.latitude, pos.longitude), zoom: 16.0);
    } catch (e) {
      _showMessage('Error getting location: $e');
      _setDefaultPosition();
    } finally {
      if (mounted) setState(() => _isGettingCurrentLocation = false);
    }
  }

  void _setDefaultPosition() {
    _moveCameraTo(MapPickerScreen.defaultInitialPosition, zoom: 14.0);
  }

  void _moveCameraTo(LatLng target, {double zoom = 14.0}) {
    setState(() {
      _selectedPosition = target;
      _currentCameraPosition = CameraPosition(target: target, zoom: zoom);
    });
    if (_mapController != null) {
      _mapController!.animateCamera(CameraUpdate.newCameraPosition(_currentCameraPosition!));
    }
  }

  void _showMessage(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_currentCameraPosition != null) {
      controller.moveCamera(CameraUpdate.newCameraPosition(_currentCameraPosition!));
      _updateAddressHttp(_currentCameraPosition!.target);
    }
  }

  void _onCameraMove(CameraPosition position) {
    if (!mounted) return;
    setState(() => _selectedPosition = position.target);
  }

  void _onCameraIdle() {
    if (!mounted || _selectedPosition == null) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 1), () {
      if (mounted && _selectedPosition != null) {
        print("Debounced geocoding for: $_selectedPosition");
        _updateAddressHttp(_selectedPosition!);
      }
    });
  }

  Future<void> _updateAddressHttp(LatLng coord) async {
    setState(() {
       _isLoadingAddress = true;
       _selectedPlaceName = null;
    });
    _selectedMunicipality = null;
    _selectedBarangay = null;

    // Check for connectivity first
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      if (mounted) {
        final msg = "No internet connection. Please check your network settings.";
        print(msg);
        _showMessage(msg);
        setState(() => _isLoadingAddress = false);
      }
      return;
    }

    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      {
        'latlng': '${coord.latitude},${coord.longitude}',
        'key': MapPickerScreen.apiKey,
      },
    );

    print("Calling Geocoding API");

    try {
      // Use standard HTTP for geocoding (it was working before)
      final client = http.Client();
      final res = await client.get(url).timeout(const Duration(seconds: 10));
      client.close();

      if (!mounted) return;

      print("Geocoding API response status: ${res.statusCode}");

      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        if (j['status'] == 'OK' && (j['results'] as List).isNotEmpty) {
          final result = j['results'][0];
          final String formattedAddress = result['formatted_address'];
          final String? potentialPlaceNameFromResult = result['name'] as String?;
          final List<dynamic> addressComponents = result['address_components'];

          String? municipality;
          String? barangay;
          String? extractedPlaceName;
          String? street;

          for (var component in addressComponents) {
            List types = component['types'];
            if (types.contains('locality')) {
              municipality = component['long_name'];
            }
            if (municipality == null && types.contains('administrative_area_level_2') && types.contains('political')) {
               municipality = component['long_name'];
            }
            if (types.contains('sublocality') || types.contains('sublocality_level_1')) {
              barangay = component['long_name'];
            }
            if (barangay == null && types.contains('neighborhood')) {
                barangay = component['long_name'];
            }
            if (types.contains('route')) {
              street = component['long_name'];
            }
            if (types.contains('point_of_interest') || types.contains('establishment') || types.contains('premise')) {
              if (extractedPlaceName == null || (component['long_name'] as String).length < extractedPlaceName.length) {
                 extractedPlaceName = component['long_name'];
              }
            }
          }

          setState(() {
            _selectedAddress = formattedAddress;
            _selectedMunicipality = municipality;
            _selectedBarangay = barangay;
            if (extractedPlaceName != null && extractedPlaceName.isNotEmpty) {
              _selectedPlaceName = extractedPlaceName;
            } else if (potentialPlaceNameFromResult != null && potentialPlaceNameFromResult.isNotEmpty && !formattedAddress.startsWith(potentialPlaceNameFromResult)) {
              _selectedPlaceName = potentialPlaceNameFromResult;
            } else {
              _selectedPlaceName = null;
            }
          });

          // Save street for later use
          if (street != null && street.isNotEmpty) {
            setState(() {
              _selectedStreet = street;
            });
          }

        } else {
          final errorMsg = "No address found. Status: ${j['status']}";
          print(errorMsg);
          setState(() => _selectedAddress = errorMsg);
        }
      } else {
        final errorMsg = "Error fetching address: ${res.statusCode}";
        print(errorMsg);
        setState(() => _selectedAddress = errorMsg);
      }
    } catch (e) {
      final errorMsg = "Failed to fetch address: $e";
      print(errorMsg);
      setState(() => _selectedAddress = errorMsg);
    } finally {
      if (mounted) setState(() => _isLoadingAddress = false);
    }
  }

  void _confirmSelection() {
    if (_selectedPosition != null) {
      Navigator.of(context).pop({
        'latlng': _selectedPosition!,
        'address': _selectedAddress,
        'municipality': _selectedMunicipality,
        'barangay': _selectedBarangay,
        'placeName': _selectedPlaceName,
        'street': _selectedStreet,
      });
    } else {
      _showMessage('Please select a location.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        actions: [
          if (_isLoadingAddress)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0)),
            ),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Confirm Location',
            onPressed: (_selectedPosition == null || _isLoadingAddress) ? null : _confirmSelection,
          )
        ],
      ),
      body: !_mapsInitialized 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.map_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Google Maps is not available', 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Please check your internet connection or try again later.',
                    textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      _checkGoogleMapsAvailability();
                      if (_mapsInitialized) {
                        setState(() {});
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Maps still not available. Please try again later.'))
                        );
                      }
                    },
                    child: const Text('Try Again'),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () {
                      // Just return without coordinates
                      Navigator.of(context).pop(null);
                    },
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      GoogleMap(
                        onMapCreated: _onMapCreated,
                        initialCameraPosition: _currentCameraPosition ?? CameraPosition(
                            target: widget.initialPosition ?? MapPickerScreen.defaultInitialPosition,
                            zoom: 14.0),
                        onCameraMove: _onCameraMove,
                        onCameraIdle: _onCameraIdle,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        markers: {},
                        padding: EdgeInsets.only(bottom: _isLoadingAddress ? 80 : 10),
                      ),
                      const Align(
                        alignment: Alignment.center,
                        child: Icon(Icons.location_pin, size: 50),
                      ),
                      if (_isGettingCurrentLocation)
                        const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [CircularProgressIndicator(), SizedBox(height: 8), Text('Getting current location...')],
                          ),
                        ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          color: Colors.black.withOpacity(0.7),
                          child: Text(
                            _isLoadingAddress ? 'Fetching address...' : _selectedAddress,
                            style: const TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: _mapsInitialized ? FloatingActionButton(
        onPressed: _getCurrentLocation,
        child: const Icon(Icons.my_location),
      ) : null,
    );
  }
}
