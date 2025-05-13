import 'package:animo/core/models/app_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // For date formatting

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
  late TextEditingController _produceCategoryController;
  late TextEditingController _customProduceCategoryController;
  late TextEditingController _initialQuantityController;
  late TextEditingController _quantityUnitController;
  late TextEditingController _estimatedWeightKgController;
  late TextEditingController _estimatedPieceCountController;
  late TextEditingController _pricePerUnitController;
  late TextEditingController _currencyController;
  late TextEditingController _shelfLifeDaysController;
  late TextEditingController _notesController;

  // LocationData Controllers
  late TextEditingController _addressHintController;
  late TextEditingController _barangayController;
  late TextEditingController _municipalityController;

  DateTime? _harvestDateTime;

  // TODO: Add controllers/state for photoUrls

  bool get _isEditing => widget.existingListing != null;

  @override
  void initState() {
    super.initState();
    final listing = widget.existingListing;

    _produceNameController = TextEditingController(text: listing?.produceName ?? '');
    _produceCategoryController = TextEditingController(text: listing?.produceCategory ?? '');
    _customProduceCategoryController = TextEditingController(text: listing?.customProduceCategory ?? '');
    _initialQuantityController = TextEditingController(text: listing?.initialQuantity.toString() ?? '');
    _quantityUnitController = TextEditingController(text: listing?.quantityUnit ?? '');
    _estimatedWeightKgController = TextEditingController(text: listing?.estimatedWeightKg?.toString() ?? '');
    _estimatedPieceCountController = TextEditingController(text: listing?.estimatedPieceCount?.toString() ?? '');
    _pricePerUnitController = TextEditingController(text: listing?.pricePerUnit?.toString() ?? '');
    _currencyController = TextEditingController(text: listing?.currency ?? 'PHP');
    _shelfLifeDaysController = TextEditingController(text: listing?.shelfLifeDays.toString() ?? '');
    _notesController = TextEditingController(text: listing?.notes ?? '');

    _harvestDateTime = listing?.harvestDateTime.toDate();

    _addressHintController = TextEditingController(text: listing?.pickupLocation.addressHint ?? '');
    _barangayController = TextEditingController(text: listing?.pickupLocation.barangay ?? '');
    _municipalityController = TextEditingController(text: listing?.pickupLocation.municipality ?? '');
    // For lat/lng, if editing, they would come from listing.pickupLocation.latitude/longitude
    // For a new entry, these might be set via a map picker or geocoding later.
  }

  @override
  void dispose() {
    _produceNameController.dispose();
    _produceCategoryController.dispose();
    _customProduceCategoryController.dispose();
    _initialQuantityController.dispose();
    _quantityUnitController.dispose();
    _estimatedWeightKgController.dispose();
    _estimatedPieceCountController.dispose();
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
    final estimatedPieceCount = _estimatedPieceCountController.text.isNotEmpty ? int.tryParse(_estimatedPieceCountController.text) : null;

    if (initialQuantity == null || shelfLifeDays == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Initial quantity and shelf life must be valid numbers.')),
      );
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }
    
    final pickupLocation = LocationData(
        latitude: widget.existingListing?.pickupLocation.latitude ?? 0.0, 
        longitude: widget.existingListing?.pickupLocation.longitude ?? 0.0, 
        addressHint: _addressHintController.text.trim(),
        barangay: _barangayController.text.trim(),
        municipality: _municipalityController.text.trim(),
    );

    final now = Timestamp.now();
    final harvestTimestamp = Timestamp.fromDate(_harvestDateTime!);
    final expiryTimestamp = Timestamp.fromDate(
      _harvestDateTime!.add(Duration(days: shelfLifeDays)),
    );

    ProduceListing listing = ProduceListing(
      id: widget.existingListing?.id ?? '',
      farmerId: widget.farmerId,
      farmerName: widget.farmerName ?? appUser?.displayName,
      produceName: _produceNameController.text.trim(),
      produceCategory: _produceCategoryController.text.trim(),
      customProduceCategory: _customProduceCategoryController.text.trim().isNotEmpty 
          ? _customProduceCategoryController.text.trim() 
          : null,
      initialQuantity: initialQuantity,
      quantityUnit: _quantityUnitController.text.trim(),
      estimatedWeightKg: estimatedWeightKg,
      estimatedPieceCount: estimatedPieceCount,
      pricePerUnit: pricePerUnit,
      currency: _currencyController.text.trim(),
      harvestDateTime: harvestTimestamp,
      shelfLifeDays: shelfLifeDays,
      expiryTimestamp: expiryTimestamp,
      listingDateTime: widget.existingListing?.listingDateTime ?? now,
      pickupLocation: pickupLocation,
      photoUrls: widget.existingListing?.photoUrls ?? [],
      status: widget.existingListing?.status ?? ProduceListingStatus.available,
      notes: _notesController.text.trim(),
      lastUpdated: now,
      quantityCommitted: widget.existingListing?.quantityCommitted ?? 0.0,
      quantitySoldAndDelivered: widget.existingListing?.quantitySoldAndDelivered ?? 0.0,
    );

    try {
      String? resultMessage;
      if (_isEditing) {
        Map<String, dynamic> updates = listing.toFirestore();
        updates.remove('farmerId'); 
        updates.remove('listingDateTime'); 
        
        bool success = await produceListingService.updateProduceListing(
          listingId: widget.existingListing!.id,
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
                    TextFormField(
                      controller: _produceCategoryController,
                      decoration: const InputDecoration(labelText: 'Produce Category', hintText: 'e.g., Fruit, Vegetable, Herb', border: OutlineInputBorder()),
                      validator: (value) => value == null || value.isEmpty ? 'Enter category' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _customProduceCategoryController,
                      decoration: const InputDecoration(labelText: 'Custom Category (if other)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
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