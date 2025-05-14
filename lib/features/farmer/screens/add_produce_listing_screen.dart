import 'package:animo/core/models/location_data.dart';
import 'package:animo/core/models/produce_listing.dart';
import 'package:animo/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart'; // For current user's name (optional)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For FilteringTextInputFormatter
import 'package:intl/intl.dart'; // For date formatting
import 'package:provider/provider.dart';

class AddProduceListingScreen extends StatefulWidget {
  final ProduceListing? existingListing; // To enable editing

  const AddProduceListingScreen({super.key, this.existingListing});

  @override
  State<AddProduceListingScreen> createState() => _AddProduceListingScreenState();
}

class _AddProduceListingScreenState extends State<AddProduceListingScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for text fields
  late TextEditingController _produceNameController;
  ProduceCategory _selectedProduceCategory = ProduceCategory.vegetable;
  late TextEditingController _customCategoryController;
  late TextEditingController _quantityController;
  late TextEditingController _unitController;
  late TextEditingController _estimatedWeightController;
  late TextEditingController _priceController;
  late TextEditingController _currencyController;
  late TextEditingController _descriptionController;
  late TextEditingController _barangayController;
  late TextEditingController _municipalityController;
  late TextEditingController _pickupAddressDetailsController;
  DateTime? _selectedHarvestDate;
  late TextEditingController _shelfLifeDaysController;

  bool _showCustomCategory = false;
  bool _isLoading = false;
  bool get _isEditMode => widget.existingListing != null;

  @override
  void initState() {
    super.initState();

    final listing = widget.existingListing;
    _produceNameController = TextEditingController(text: listing?.produceName);
    _selectedProduceCategory = listing?.produceCategory ?? ProduceCategory.vegetable;
    _customCategoryController = TextEditingController(text: listing?.customProduceCategory);
    _quantityController = TextEditingController(text: listing?.quantity.toString());
    _unitController = TextEditingController(text: listing?.unit);
    _estimatedWeightController = TextEditingController(text: listing?.estimatedWeightKgPerUnit?.toString());
    _priceController = TextEditingController(text: listing?.pricePerUnit.toString());
    _currencyController = TextEditingController(text: listing?.currency ?? 'PHP');
    _descriptionController = TextEditingController(text: listing?.description);
    _barangayController = TextEditingController(text: listing?.pickupLocation.barangay);
    _municipalityController = TextEditingController(text: listing?.pickupLocation.municipality);
    _pickupAddressDetailsController = TextEditingController(text: listing?.pickupLocation.addressHint);
    _selectedHarvestDate = listing?.harvestTimestamp;
    if (listing?.expiryTimestamp != null && listing?.harvestTimestamp != null) {
      final shelfLife = listing!.expiryTimestamp!.difference(listing.harvestTimestamp!).inDays;
      _shelfLifeDaysController = TextEditingController(text: shelfLife.toString());
    } else {
      _shelfLifeDaysController = TextEditingController();
    }

    if (_selectedProduceCategory == ProduceCategory.other) {
      _showCustomCategory = true;
    }
  }

  @override
  void dispose() {
    _produceNameController.dispose();
    _customCategoryController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _estimatedWeightController.dispose();
    _priceController.dispose();
    _currencyController.dispose();
    _descriptionController.dispose();
    _barangayController.dispose();
    _municipalityController.dispose();
    _pickupAddressDetailsController.dispose();
    _shelfLifeDaysController.dispose();
    super.dispose();
  }

  Future<void> _selectHarvestDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedHarvestDate ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 5), // Allow past dates for harvest
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (picked != null && picked != _selectedHarvestDate) {
      setState(() {
        _selectedHarvestDate = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      final farmerId = firestoreService.currentUserId;
      final firebaseUser = FirebaseAuth.instance.currentUser;

      if (farmerId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: User not logged in.')),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      DateTime? expiryTimestamp;
      if (_selectedHarvestDate != null && _shelfLifeDaysController.text.isNotEmpty) {
        final shelfLife = int.tryParse(_shelfLifeDaysController.text);
        if (shelfLife != null && shelfLife > 0) {
          expiryTimestamp = _selectedHarvestDate!.add(Duration(days: shelfLife));
        }
      }

      final produceData = ProduceListing(
        id: widget.existingListing?.id, // Preserve ID for updates
        farmerId: farmerId,
        farmerName: firebaseUser?.displayName ?? firebaseUser?.email,
        produceName: _produceNameController.text,
        produceCategory: _selectedProduceCategory,
        customProduceCategory: _selectedProduceCategory == ProduceCategory.other
            ? _customCategoryController.text
            : null,
        quantity: double.tryParse(_quantityController.text) ?? 0,
        initialQuantity: _isEditMode 
            ? widget.existingListing!.initialQuantity // Keep original initial quantity on edit
            : double.tryParse(_quantityController.text) ?? 0, 
        unit: _unitController.text,
        estimatedWeightKgPerUnit: _estimatedWeightController.text.isNotEmpty
            ? double.tryParse(_estimatedWeightController.text)
            : null,
        pricePerUnit: double.tryParse(_priceController.text) ?? 0,
        currency: _currencyController.text,
        description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
        pickupLocation: LocationData(
            latitude: widget.existingListing?.pickupLocation.latitude ?? 0.0,
            longitude: widget.existingListing?.pickupLocation.longitude ?? 0.0,
            barangay: _barangayController.text,
            municipality: _municipalityController.text,
            addressHint: _pickupAddressDetailsController.text.isNotEmpty 
                ? _pickupAddressDetailsController.text 
                : null,
            ), 
        photoUrls: widget.existingListing?.photoUrls ?? [], // Preserve existing photos
        status: widget.existingListing?.status ?? ProduceListingStatus.available, // Preserve status or default
        harvestTimestamp: _selectedHarvestDate,
        expiryTimestamp: expiryTimestamp,
        createdAt: widget.existingListing?.createdAt ?? DateTime.now(), // Preserve original createdAt
        lastUpdated: DateTime.now(), // Always update lastUpdated
        quantityCommitted: widget.existingListing?.quantityCommitted ?? 0,
        quantitySoldAndDelivered: widget.existingListing?.quantitySoldAndDelivered ?? 0,
      );

      try {
        if (_isEditMode) {
          await firestoreService.updateProduceListing(produceData);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Produce listing updated successfully!')),
            );
          }
        } else {
          await firestoreService.addProduceListing(produceData);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Produce listing added successfully!')),
            );
          }
        }
        if (mounted) {
            Navigator.of(context).pop(); // Go back to dashboard
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving listing: $e')),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Produce Listing' : 'Add New Produce Listing'),
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
                      decoration: const InputDecoration(labelText: 'Produce Name'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the produce name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
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
                            _showCustomCategory = (newValue == ProduceCategory.other);
                          }
                        });
                      },
                      validator: (value) => value == null ? 'Please select a category' : null,
                    ),
                    if (_showCustomCategory)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: TextFormField(
                          controller: _customCategoryController,
                          decoration: const InputDecoration(labelText: 'Custom Category Name'),
                          validator: (value) {
                            if (_showCustomCategory && (value == null || value.isEmpty)) {
                              return 'Please enter the custom category name';
                            }
                            return null;
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _quantityController,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(RegExp(r'^[0-9]+.?[0-9]*')),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the quantity';
                        }
                        final number = double.tryParse(value);
                        if (number == null || number <= 0) {
                          return 'Please enter a valid positive quantity';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _unitController,
                      decoration: const InputDecoration(labelText: 'Unit (e.g., kg, piece, sack)'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the unit';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                        controller: _estimatedWeightController,
                        decoration: const InputDecoration(labelText: 'Estimated Weight per Unit (kg, optional)', hintText: 'e.g. 0.5 for 500g per piece'),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.allow(RegExp(r'^[0-9]+.?[0-9]*')),
                        ],
                        validator: (value) {
                            if (value != null && value.isNotEmpty) {
                                final number = double.tryParse(value);
                                if (number == null || number <= 0) {
                                    return 'Please enter a valid positive weight or leave empty';
                                }
                            }
                            return null;
                        },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(labelText: 'Price per Unit'),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(RegExp(r'^[0-9]+.?[0-9]*')),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the price';
                        }
                        final number = double.tryParse(value);
                        if (number == null || number <= 0) {
                          return 'Please enter a valid positive price';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _currencyController,
                      decoration: const InputDecoration(labelText: 'Currency'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the currency (e.g., PHP)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Description (Optional)', alignLabelWithHint: true),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    Text('Pickup Location', style: Theme.of(context).textTheme.titleMedium),
                    TextFormField(
                      controller: _barangayController,
                      decoration: const InputDecoration(labelText: 'Barangay'),
                       validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the barangay';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _municipalityController,
                      decoration: const InputDecoration(labelText: 'Municipality / City'),
                       validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the municipality/city';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _pickupAddressDetailsController,
                      decoration: const InputDecoration(labelText: 'Address Hint / Landmark (Optional)'),
                    ),
                    const SizedBox(height: 24),
                    Text('Harvest & Expiry', style: Theme.of(context).textTheme.titleMedium),
                    ListTile(
                      title: Text(_selectedHarvestDate == null 
                          ? 'Select Harvest Date' 
                          : 'Harvest Date: ${DateFormat.yMd().format(_selectedHarvestDate!)}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () => _selectHarvestDate(context),
                      subtitle: _selectedHarvestDate == null && !_isEditMode ? const Text('Required for new listing', style: TextStyle(color: Colors.grey)) : null,
                    ),
                     TextFormField(
                      controller: _shelfLifeDaysController,
                      decoration: const InputDecoration(labelText: 'Estimated Shelf Life (days after harvest)'),
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      validator: (value) {
                        if (_selectedHarvestDate == null && (value != null && value.isNotEmpty)) {
                            return 'Please select harvest date first if providing shelf life.';
                        } 
                        if (_selectedHarvestDate != null && (value == null || value.isEmpty)) {
                          return 'Please enter shelf life for the selected harvest date';
                        }
                        if (value != null && value.isNotEmpty) {
                            final days = int.tryParse(value);
                            if (days == null || days <= 0) {
                                return 'Please enter a valid number of days';
                            }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                        icon: const Icon(Icons.image),
                        label: const Text('Add Photos (Coming Soon)'),
                        onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Image picking functionality will be added later.')),
                            );
                        },
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitForm,
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
                        child: _isLoading 
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(_isEditMode ? 'Update Listing' : 'Save Listing'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 