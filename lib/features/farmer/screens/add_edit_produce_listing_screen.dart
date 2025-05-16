import 'dart:io'; // For File type

import 'package:animo/core/models/app_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for FilteringTextInputFormatter
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart'; // Import image_picker
import 'package:firebase_storage/firebase_storage.dart'; // Import firebase_storage
import '../../../core/screens/map_picker_screen.dart';

import '../../../core/models/location_data.dart';
import '../../../core/models/produce_listing.dart';
import '../../../services/produce_listing_service.dart';
import '../../../services/firebase_auth_service.dart'; // For farmerId

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
  List<String> _photoUrls = []; // Stores uploaded image URLs
  XFile? _pickedImageFile; // Stores the currently picked image file

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
      _photoUrls = List<String>.from(listing.photoUrls); // Initialize with existing photo URLs
    } else {
      _selectedProduceCategory = ProduceCategory.vegetable; // Default for new listing
      _customProduceCategoryController = TextEditingController();
      _photoUrls = []; // Empty for new listing
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
        listing.pickupLocation.latitude != null && 
        listing.pickupLocation.longitude != null) {
      if (listing.pickupLocation.latitude != 0 || listing.pickupLocation.longitude != 0) {
        _selectedPickupLatLng = LatLng(listing.pickupLocation.latitude!, listing.pickupLocation.longitude!);
        // Note: _selectedPickupAddressString might need to be re-fetched or stored if you want to display it here
      }
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
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _harvestDateTime ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 5), // Allow past dates
      lastDate: DateTime.now().add(const Duration(days: 365)), // Allow up to one year in future
    );
    if (picked != null && picked != _harvestDateTime) {
      setState(() {
        _harvestDateTime = picked;
      });
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery); // Or ImageSource.camera
      if (image != null) {
        setState(() {
          _pickedImageFile = image;
        });
      }
    } catch (e) {
      print("Error picking image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: ${e.toString()}')),
        );
      }
    }
  }

  Future<String?> _uploadImage(XFile imageFile, String farmerId) async {
    setState(() => _isLoading = true);
    try {
      String fileName = 'produce_listings/${farmerId}_${DateTime.now().millisecondsSinceEpoch}_${imageFile.name}';
      Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
      UploadTask uploadTask = storageRef.putFile(File(imageFile.path));
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      setState(() => _isLoading = false);
      return downloadUrl;
    } catch (e) {
      print("Error uploading image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: ${e.toString()}')),
        );
      }
      setState(() => _isLoading = false);
      return null;
    }
  }

  Future<void> _saveListing() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    // Upload picked image if it exists and no URL is present yet (for simplicity, one image)
    if (_pickedImageFile != null) {
        final farmerId = Provider.of<FirebaseAuthService>(context, listen: false).currentFirebaseUser?.uid;
        if (farmerId != null) {
            String? uploadedImageUrl = await _uploadImage(_pickedImageFile!, farmerId);
            if (uploadedImageUrl != null) {
            // For simplicity, this example replaces existing URLs with the new one.
            // You might want to append or manage multiple images.
            _photoUrls = [uploadedImageUrl]; 
            } else {
            // Handle upload failure - maybe don't proceed or show error
            if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Image upload failed. Please try again.')),
                );
            }
            setState(() => _isLoading = false);
            return; // Stop saving if image upload fails
            }
        } else {
             if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User not logged in. Cannot upload image.')),
                );
            }
            setState(() => _isLoading = false);
            return;
        }
    }

    // ... (rest of the _saveListing method, ensuring _photoUrls is used)
    // Ensure AppUser is fetched or farmerName is available
    final appUser = Provider.of<AppUser?>(context, listen: false);
    final produceListingService = Provider.of<ProduceListingService>(context, listen: false);
    final now = Timestamp.now();
    final harvestTimestampAsDateTime = _harvestDateTime;
    DateTime? expiryTimestampDateTime;

    if (harvestTimestampAsDateTime != null && _shelfLifeDaysController.text.isNotEmpty) {
      final days = int.tryParse(_shelfLifeDaysController.text);
      if (days != null && days > 0) {
        expiryTimestampDateTime = harvestTimestampAsDateTime.add(Duration(days: days));
      }
    }

    double? initialQuantity = double.tryParse(_initialQuantityController.text);
    if (initialQuantity == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Initial Quantity.')));
        setState(() => _isLoading = false);
        return;
    }
    double? pricePerUnit = double.tryParse(_pricePerUnitController.text);
     if (pricePerUnit == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Price Per Unit.')));
        setState(() => _isLoading = false);
        return;
    }
    double? estimatedWeightKg = _estimatedWeightKgController.text.isNotEmpty
        ? double.tryParse(_estimatedWeightKgController.text)
        : null;
    if (_estimatedWeightKgController.text.isNotEmpty && estimatedWeightKg == null) {
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Estimated Weight.')));
        setState(() => _isLoading = false);
        return;
    }


    LocationData pickupLocation = LocationData(
      latitude: _selectedPickupLatLng?.latitude ?? 0.0,
      longitude: _selectedPickupLatLng?.longitude ?? 0.0,
      addressHint: _addressHintController.text.trim().isNotEmpty ? _addressHintController.text.trim() : null,
      barangay: _barangayController.text.trim(),
      municipality: _municipalityController.text.trim(),
    );


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
      pricePerUnit: pricePerUnit,
      currency: _currencyController.text.trim(),
      harvestTimestamp: harvestTimestampAsDateTime,
      expiryTimestamp: expiryTimestampDateTime,
      createdAt: widget.existingListing?.createdAt ?? now.toDate(),
      pickupLocation: pickupLocation,
      photoUrls: _photoUrls, // Ensure this uses the potentially updated _photoUrls
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
    } catch (e, s) {
      if (mounted) {
        print("Error in _saveListing: ${e.toString()}");
        print("Stack trace: ${s.toString()}");
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
    final colorScheme = Theme.of(context).colorScheme; // Get colorScheme

    return Scaffold(
      // backgroundColor: colorScheme.surface, // Or a light beige color if defined in theme
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Produce Listing' : 'Add New Produce Listing'),
        elevation: 1, // Subtle elevation
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
                    _buildSectionHeader(context, 'Produce Details'),
                    Card(
                      elevation: 0,
                      color: colorScheme.surfaceContainerLow, // Light beige card
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _produceNameController,
                              decoration: const InputDecoration(labelText: 'Produce Name', border: OutlineInputBorder()),
                              validator: (value) => value == null || value.isEmpty ? 'Enter produce name' : null,
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<ProduceCategory>(
                              value: _selectedProduceCategory,
                              decoration: const InputDecoration(labelText: 'Produce Category', border: OutlineInputBorder()),
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
                            const SizedBox(height: 16),
                            if (_selectedProduceCategory == ProduceCategory.other)
                              TextFormField(
                                controller: _customProduceCategoryController,
                                decoration: const InputDecoration(labelText: 'Custom Category Name', border: OutlineInputBorder()),
                                validator: (value) {
                                  if (_selectedProduceCategory == ProduceCategory.other && (value == null || value.isEmpty)) {
                                    return 'Please enter the custom category name';
                                  }
                                  return null;
                                },
                              ),
                          ],
                        ),
                      ),
                    ),

                    _buildSectionHeader(context, 'Quantity & Pricing'),
                     Card(
                      elevation: 0,
                      color: colorScheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _initialQuantityController,
                                    decoration: const InputDecoration(labelText: 'Initial Quantity', border: OutlineInputBorder()),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                                    validator: (value) {
                                      if (value == null || value.isEmpty) return 'Enter quantity';
                                      if (double.tryParse(value) == null || double.parse(value) <= 0) return 'Must be > 0';
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _quantityUnitController,
                                    decoration: const InputDecoration(labelText: 'Unit (e.g., kg, piece)', border: OutlineInputBorder()),
                                    validator: (value) => value == null || value.isEmpty ? 'Enter unit' : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                                controller: _estimatedWeightKgController,
                                decoration: const InputDecoration(labelText: 'Est. Weight per Unit (kg, Optional)', border: OutlineInputBorder()),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                                validator: (value) {
                                  if (value != null && value.isNotEmpty && (double.tryParse(value) == null || double.parse(value) <= 0)) {
                                    return 'Must be a valid number > 0 or empty';
                                  }
                                  return null;
                                },
                              ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _pricePerUnitController,
                                    decoration: const InputDecoration(labelText: 'Price per Unit', border: OutlineInputBorder()),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                                     validator: (value) {
                                      if (value == null || value.isEmpty) return 'Enter price';
                                      if (double.tryParse(value) == null || double.parse(value) <= 0) return 'Must be > 0';
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _currencyController,
                                    decoration: const InputDecoration(labelText: 'Currency', border: OutlineInputBorder()),
                                     validator: (value) => value == null || value.isEmpty ? 'Enter currency (e.g. PHP)' : null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    _buildSectionHeader(context, 'Freshness & Shelf Life'),
                    Card(
                      elevation: 0,
                      color: colorScheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Harvest Date (Optional)'),
                              subtitle: Text(_harvestDateTime == null ? 'Not set' : DateFormat.yMMMd().format(_harvestDateTime!)),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: () => _selectHarvestDateTime(context),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _shelfLifeDaysController,
                              decoration: const InputDecoration(labelText: 'Shelf Life (days from harvest, Optional)', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              validator: (value) {
                                if (value != null && value.isNotEmpty) {
                                  final days = int.tryParse(value);
                                  if (days == null || days <= 0) return 'Must be > 0 days or empty';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    _buildSectionHeader(context, 'Pickup Location'),
                    Card(
                      elevation: 0,
                      color: colorScheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _addressHintController,
                              decoration: const InputDecoration(labelText: 'Street Address / Landmark (Optional)', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 16),
                             Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _barangayController,
                                    decoration: const InputDecoration(labelText: 'Barangay', border: OutlineInputBorder()),
                                     validator: (value) => value == null || value.isEmpty ? 'Enter barangay' : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _municipalityController,
                                    decoration: const InputDecoration(labelText: 'Municipality/City', border: OutlineInputBorder()),
                                     validator: (value) => value == null || value.isEmpty ? 'Enter municipality/city' : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.map_outlined),
                              label: Text(_selectedPickupLatLng == null ? 'Select on Map' : 'Change Map Location'),
                              onPressed: _selectLocationOnMap,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.secondaryContainer,
                                foregroundColor: colorScheme.onSecondaryContainer,
                              ),
                            ),
                             if (_selectedPickupAddressString != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text('Selected: $_selectedPickupAddressString', style: Theme.of(context).textTheme.bodySmall),
                              ),
                          ],
                        ),
                      ),
                    ),
                    
                    _buildSectionHeader(context, 'Product Image'),
                    Card(
                      elevation: 0,
                      color: colorScheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch, // Make children take full width
                          children: [
                            if (_pickedImageFile != null)
                              Column(
                                children: [
                                  Container(
                                    height: 150,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      image: DecorationImage(
                                        image: FileImage(File(_pickedImageFile!.path)),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(Icons.clear, color: Colors.redAccent),
                                    label: const Text('Remove Image', style: TextStyle(color: Colors.redAccent)),
                                    onPressed: () {
                                      setState(() {
                                        _pickedImageFile = null;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              )
                            else if (_photoUrls.isNotEmpty && _photoUrls.first.isNotEmpty) // Display existing uploaded image
                              Column(
                                children: [
                                   Container(
                                    height: 150,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      image: DecorationImage(
                                        image: NetworkImage(_photoUrls.first),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(Icons.clear, color: Colors.redAccent),
                                    label: const Text('Remove Image', style: TextStyle(color: Colors.redAccent)),
                                    onPressed: () { // This would ideally also delete from Firebase Storage
                                      setState(() {
                                        _photoUrls = []; 
                                        // Consider adding logic to delete from storage if user confirms
                                      });
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Image removed. Save listing to confirm permanent removal.')),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ),
                              
                            // Show "Add Image" button if no image is picked or uploaded
                            if (_pickedImageFile == null && (_photoUrls.isEmpty || _photoUrls.first.isEmpty))
                              Center(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.add_a_photo_outlined),
                                  label: const Text('Add Image'),
                                  onPressed: _pickImage,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    textStyle: Theme.of(context).textTheme.labelLarge,
                                    side: BorderSide(color: colorScheme.outline), // Consistent border
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    _buildSectionHeader(context, 'Additional Notes (Optional)'),
                    Card(
                      elevation: 0,
                      color: colorScheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: TextFormField(
                          controller: _notesController,
                          decoration: const InputDecoration(labelText: 'Notes for buyer (e.g., organic, special handling)', border: OutlineInputBorder()),
                          maxLines: 3,
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),
                    Center( // Center the button
                      child: ElevatedButton.icon(
                        icon: Icon(_isEditing ? Icons.save_alt_outlined : Icons.add_circle_outline_rounded),
                        label: Text(_isEditing ? 'Update Listing' : 'Submit Listing'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A2E2B), // Dark brown button
                          foregroundColor: Colors.white, // White text
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), // More rounded
                        ),
                        onPressed: _isLoading ? null : _saveListing,
                      ),
                    ),
                    const SizedBox(height: 20), // Bottom padding
                  ],
                ),
              ),
            ),
    );
  }

  // Helper for section headers, similar to buyer's screen
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 12.0), // Adjusted bottom padding
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: const Color(0xFF4A2E2B), // Dark brown color for headers, as seen in screenshot
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Future<void> _selectLocationOnMap() async {
    final currentContext = context; // Capture context
    final result = await Navigator.of(currentContext).push(
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
        
        final String? municipality = result['municipality'] as String?;
        final String? barangay = result['barangay'] as String?;
        final String? street = result['street'] as String?;
        final String? placeName = result['placeName'] as String?;
        final String? fullAddress = result['address'] as String?;

        if (municipality != null) _municipalityController.text = municipality;
        if (barangay != null) _barangayController.text = barangay;
        
        if (fullAddress != null && fullAddress.isNotEmpty) {
          String detailedAddress = fullAddress;
          if (municipality != null && detailedAddress.contains(municipality)) {
            detailedAddress = detailedAddress.substring(0, detailedAddress.indexOf(municipality)).trim();
          }
          if (barangay != null && detailedAddress.contains(barangay)) {
            detailedAddress = detailedAddress.substring(0, detailedAddress.indexOf(barangay)).trim();
          }
          detailedAddress = detailedAddress.replaceAll(RegExp(r',\s*$'), '').trim();
          if (detailedAddress.isNotEmpty) _addressHintController.text = detailedAddress;
          else if (street != null && street.isNotEmpty) _addressHintController.text = street;
          else if (placeName != null && placeName.isNotEmpty) _addressHintController.text = placeName;
        } else if (street != null && street.isNotEmpty) {
          _addressHintController.text = street;
        } else if (placeName != null && placeName.isNotEmpty) {
          _addressHintController.text = placeName;
        }
      });
    }
  }
} 