import 'package:animo/core/models/app_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/screens/map_picker_screen.dart';

import '../../../core/models/location_data.dart';
import '../../../core/models/produce_listing.dart';
import '../../../services/produce_listing_service.dart';

class AddEditProduceListingScreen extends StatefulWidget {
  static const String routeName = '/add-edit-produce-listing';

  final String farmerId;
  final String? farmerName; // Optional: pass from dashboard if readily available
  final ProduceListing? existingListing;

  const AddEditProduceListingScreen({
    super.key,
    required this.farmerId,
    this.farmerName,
    this.existingListing,
  });

  @override
  State<AddEditProduceListingScreen> createState() =>
      _AddEditProduceListingScreenState();
}

class _AddEditProduceListingScreenState
    extends State<AddEditProduceListingScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Text Editing Controllers
  late TextEditingController _produceNameController;
  ProduceCategory _selectedProduceCategory = ProduceCategory.vegetable; // Default
  late TextEditingController _customProduceCategoryController;
  late TextEditingController _initialQuantityController;
  late TextEditingController _quantityUnitController;
  late TextEditingController _estimatedWeightKgController;
  late TextEditingController _pricePerUnitController;
  late TextEditingController _currencyController;
  late TextEditingController _shelfLifeDaysController;
  late TextEditingController _notesController;

  // LocationData Controllers
  late TextEditingController _addressHintController;
  late TextEditingController _barangayController;
  late TextEditingController _municipalityController;

  // ADDED: State for selected map location
  LatLng? _selectedPickupLatLng;
  String? _selectedPickupAddressString;

  DateTime? _harvestDateTime;

  // TODO: Add controllers/state for photoUrls

  bool get _isEditing => widget.existingListing != null;

  @override
  void initState() {
    super.initState();
    final listing = widget.existingListing;

    _produceNameController = TextEditingController(text: listing?.produceName ?? '');
    if (listing != null) {
      try {
        _selectedProduceCategory = listing.produceCategory;
      } catch (e) {
        print("Error parsing ProduceCategory from existing listing: ${listing.produceCategory}. Defaulting. Error: $e");
        _selectedProduceCategory = ProduceCategory.vegetable; // Default on error
      }
      _customProduceCategoryController = TextEditingController(text: listing.customProduceCategory ?? '');
    } else {
      _selectedProduceCategory = ProduceCategory.vegetable; // Default for new listing
      _customProduceCategoryController = TextEditingController();
    }
    
    _initialQuantityController = TextEditingController(text: listing?.initialQuantity.toString() ?? '');
    _quantityUnitController = TextEditingController(text: listing?.unit ?? '');
    _estimatedWeightKgController = TextEditingController(text: listing?.estimatedWeightKgPerUnit?.toString() ?? '');
    _pricePerUnitController = TextEditingController(text: listing?.pricePerUnit.toString() ?? '');
    _currencyController = TextEditingController(text: listing?.currency ?? 'PHP');
    _shelfLifeDaysController = TextEditingController();
    if (listing?.expiryTimestamp != null && listing?.harvestTimestamp != null) {
        final duration = listing!.expiryTimestamp!.difference(listing.harvestTimestamp!);
        _shelfLifeDaysController.text = duration.inDays.toString();
    }
    _notesController = TextEditingController(text: listing?.description ?? '');

    _harvestDateTime = listing?.harvestTimestamp;

    _addressHintController = TextEditingController(text: listing?.pickupLocation.addressHint ?? '');
    _barangayController = TextEditingController(text: listing?.pickupLocation.barangay ?? '');
    _municipalityController = TextEditingController(text: listing?.pickupLocation.municipality ?? '');
    
    // ADDED: Initialize _selectedPickupLatLng if editing and valid coordinates exist
    if (listing != null && 
        listing.pickupLocation.latitude != 0.0 && 
        listing.pickupLocation.longitude != 0.0) {
      _selectedPickupLatLng = LatLng(listing.pickupLocation.latitude, listing.pickupLocation.longitude);
      // Optionally, you could try to pre-fill _selectedPickupAddressString here if you store it
      // or perform a reverse geocode, but that might be slow for initState.
      // For now, we'll let the map picker handle showing the address when opened.
    }

    // For lat/lng, if editing, they would come from listing.pickupLocation.latitude/longitude
  }

  @override
  void dispose() {
    _produceNameController.dispose();
    _customProduceCategoryController.dispose();
    _initialQuantityController.dispose();
    _quantityUnitController.dispose();
    _estimatedWeightKgController.dispose();
    _pricePerUnitController.dispose();
    _currencyController.dispose();
    _shelfLifeDaysController.dispose();
    _notesController.dispose();
    _addressHintController.dispose();
    _barangayController.dispose();
    _municipalityController.dispose();
    super.dispose();
  }

  Future<void> _selectHarvestDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _harvestDateTime ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)), // Allow past dates for harvest
      lastDate: DateTime.now().add(const Duration(days: 30)), // Allow future dates too
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_harvestDateTime ?? DateTime.now()),
      );
      if (pickedTime != null) {
        setState(() {
          _harvestDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _saveListing() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_harvestDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a harvest date and time.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final produceListingService = Provider.of<ProduceListingService>(context, listen: false);
    final appUser = Provider.of<AppUser?>(context, listen: false);

    final initialQuantity = double.tryParse(_initialQuantityController.text);
    final shelfLifeDays = int.tryParse(_shelfLifeDaysController.text);
    final pricePerUnit = _pricePerUnitController.text.isNotEmpty ? double.tryParse(_pricePerUnitController.text) : null;
    final estimatedWeightKg = _estimatedWeightKgController.text.isNotEmpty ? double.tryParse(_estimatedWeightKgController.text) : null;

    if (initialQuantity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Initial quantity must be a valid number.')),
      );
       if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }
    if (shelfLifeDays == null || shelfLifeDays <=0) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shelf life must be a positive valid number of days.')),
      );
       if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }
    
    final pickupLocation = LocationData(
        // MODIFIED: Use _selectedPickupLatLng if available
        latitude: _selectedPickupLatLng?.latitude ?? widget.existingListing?.pickupLocation.latitude ?? 0.0, 
        longitude: _selectedPickupLatLng?.longitude ?? widget.existingListing?.pickupLocation.longitude ?? 0.0, 
        addressHint: _addressHintController.text.trim(),
        barangay: _barangayController.text.trim(),
        municipality: _municipalityController.text.trim(),
    );

    final now = Timestamp.now();
    final harvestTimestampAsDateTime = _harvestDateTime!;
    final expiryTimestampDateTime = harvestTimestampAsDateTime.add(Duration(days: shelfLifeDays));

    ProduceListing listing = ProduceListing(
      id: widget.existingListing?.id,
      farmerId: widget.farmerId,
      farmerName: widget.farmerName ?? appUser?.displayName,
      produceName: _produceNameController.text.trim(),
      produceCategory: _selectedProduceCategory,
      customProduceCategory: _selectedProduceCategory == ProduceCategory.other && _customProduceCategoryController.text.trim().isNotEmpty
          ? _customProduceCategoryController.text.trim()
          : null,
      quantity: initialQuantity,
      initialQuantity: initialQuantity,
      unit: _quantityUnitController.text.trim(),
      estimatedWeightKgPerUnit: estimatedWeightKg,
      pricePerUnit: pricePerUnit ?? 0.0,
      currency: _currencyController.text.trim(),
      harvestTimestamp: harvestTimestampAsDateTime,
      expiryTimestamp: expiryTimestampDateTime,
      createdAt: widget.existingListing?.createdAt ?? now.toDate(),
      pickupLocation: pickupLocation,
      photoUrls: widget.existingListing?.photoUrls ?? [],
      status: widget.existingListing?.status ?? ProduceListingStatus.available,
      description: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      lastUpdated: now.toDate(),
      quantityCommitted: widget.existingListing?.quantityCommitted ?? 0.0,
      quantitySoldAndDelivered: widget.existingListing?.quantitySoldAndDelivered ?? 0.0,
    );

    try {
      String? resultMessage;
      if (_isEditing) {
        Map<String, dynamic> updates = listing.toFirestore();
        updates.remove('farmerId'); 
        updates.remove('createdAt'); 
        
        bool success = await produceListingService.updateProduceListing(
          listingId: widget.existingListing!.id!,
          updates: updates,
        );
        resultMessage = success ? 'Listing updated successfully!' : 'Failed to update listing.';
      } else {
        String? newListingId = await produceListingService.addProduceListing(listing: listing);
        resultMessage = newListingId != null
            ? 'Listing added successfully!'
            : 'Failed to add listing.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resultMessage)));
        if (resultMessage.contains('successfully')) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Produce Listing' : 'Add New Produce Listing'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TextFormField(
                      controller: _produceNameController,
                      decoration: const InputDecoration(labelText: 'Produce Name', border: OutlineInputBorder()),
                      validator: (value) => value == null || value.isEmpty ? 'Enter produce name' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ProduceCategory>(
                      value: _selectedProduceCategory,
                      decoration: const InputDecoration(labelText: 'Produce Category'),
                      items: ProduceCategory.values.map((ProduceCategory category) {
                        return DropdownMenuItem<ProduceCategory>(
                          value: category,
                          child: Text(category.displayName),
                        );
                      }).toList(),
                      onChanged: (ProduceCategory? newValue) {
                        setState(() {
                          if (newValue != null) {
                            _selectedProduceCategory = newValue;
                          }
                        });
                      },
                      validator: (value) => value == null ? 'Please select a category' : null,
                    ),
                    const SizedBox(height: 12),
                    if (_selectedProduceCategory == ProduceCategory.other)
                      TextFormField(
                        controller: _customProduceCategoryController,
                        decoration: const InputDecoration(labelText: 'Custom Category Name'),
                        validator: (value) {
                          if (_selectedProduceCategory == ProduceCategory.other && (value == null || value.isEmpty)) {
                            return 'Please enter the custom category name';
                          }
                          return null;
                        },
                      ),
                    if (_selectedProduceCategory == ProduceCategory.other)
                      const SizedBox(height: 16.0),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _initialQuantityController,
                            decoration: const InputDecoration(labelText: 'Initial Quantity', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Enter quantity';
                              if (double.tryParse(value) == null) return 'Invalid number';
                              if (double.parse(value) <= 0) return 'Must be > 0';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _quantityUnitController,
                            decoration: const InputDecoration(labelText: 'Unit', hintText: 'e.g., kg, pcs, bundle', border: OutlineInputBorder()),
                            validator: (value) => value == null || value.isEmpty ? 'Enter unit' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                     TextFormField(
                      controller: _pricePerUnitController,
                      decoration: InputDecoration(labelText: 'Price per Unit (${_currencyController.text})', border: OutlineInputBorder()),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                           if (double.tryParse(value) == null) return 'Invalid price';
                           if (double.parse(value) < 0) return 'Price cannot be negative';
                        }
                        return null; 
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _shelfLifeDaysController,
                      decoration: const InputDecoration(labelText: 'Shelf Life (days from harvest)', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Enter shelf life';
                        if (int.tryParse(value) == null) return 'Invalid number';
                        if (int.parse(value) <= 0) return 'Must be > 0 days';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_harvestDateTime == null
                          ? 'Select Harvest Date & Time'
                          : 'Harvested: ${DateFormat('yyyy-MM-dd HH:mm').format(_harvestDateTime!)}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () => _selectHarvestDateTime(context),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0), side: BorderSide(color: Colors.grey.shade400)),
                    ),
                    const SizedBox(height: 16),
                    const Text('Pickup Location Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    // ADDED: Button to open Map Picker and display selected address
                    TextButton.icon(
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Select Pickup Location on Map'),
                      onPressed: () async {
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => MapPickerScreen(
                              initialPosition: _selectedPickupLatLng, 
                            ),
                          ),
                        );

                        if (result != null && result is Map<String, dynamic>) {
                          setState(() {
                            _selectedPickupLatLng = result['latlng'] as LatLng?;
                            _selectedPickupAddressString = result['address'] as String?;
                            // Optional: Try to parse and fill barangay/municipality from address string
                            // This is complex and error-prone. For now, user manually confirms/edits fields.
                            // Example of a simple attempt (might not be robust):
                            // if (_selectedPickupAddressString != null) {
                            //   var parts = _selectedPickupAddressString!.split(',');
                            //   // This logic highly depends on the format of _selectedAddressString
                            //   // and might need significant refinement.
                            //   if (parts.length > 2) { 
                            //      _barangayController.text = parts[parts.length - 3].trim(); // Example
                            //      _municipalityController.text = parts[parts.length - 2].trim(); // Example
                            //   }
                            // }
                          });
                        }
                      },
                    ),
                    if (_selectedPickupAddressString != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'Map Selection: $_selectedPickupAddressString',
                          style: TextStyle(color: Theme.of(context).primaryColor, fontStyle: FontStyle.italic),
                        ),
                      )
                    else if (_selectedPickupLatLng != null)
                       Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'Map Selection: Lat: ${_selectedPickupLatLng!.latitude.toStringAsFixed(5)}, Lng: ${_selectedPickupLatLng!.longitude.toStringAsFixed(5)}',
                          style: TextStyle(color: Theme.of(context).primaryColor, fontStyle: FontStyle.italic),
                        ),
                      ),
                    const SizedBox(height: 8),
                    TextFormField(
                        controller: _municipalityController,
                        decoration: const InputDecoration(labelText: 'Municipality', border: OutlineInputBorder()),
                        validator: (v) => v == null || v.isEmpty ? 'Municipality is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                        controller: _barangayController,
                        decoration: const InputDecoration(labelText: 'Barangay', border: OutlineInputBorder()),
                        validator: (v) => v == null || v.isEmpty ? 'Barangay is required' : null,
                    ),
                    const SizedBox(height: 12),
                     TextFormField(
                        controller: _addressHintController,
                        decoration: const InputDecoration(labelText: 'Address Hint / Street (Optional)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(labelText: 'Additional Notes (Optional)', border: OutlineInputBorder()),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                      onPressed: _isLoading ? null : _saveListing,
                      child: Text(_isEditing ? 'Update Listing' : 'Add Listing'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 