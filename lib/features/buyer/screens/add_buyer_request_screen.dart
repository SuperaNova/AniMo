import 'package:animo/core/models/location_data.dart';
import 'package:animo/core/models/produce_listing.dart'; // For ProduceCategory enum
import 'package:animo/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:animo/core/models/buyer_request.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class AddBuyerRequestScreen extends StatefulWidget {
  static const String routeName = '/add-buyer-request';
  final BuyerRequest? existingRequest;

  const AddBuyerRequestScreen({super.key, this.existingRequest});

  @override
  State<AddBuyerRequestScreen> createState() => _AddBuyerRequestScreenState();
}

class _AddBuyerRequestScreenState extends State<AddBuyerRequestScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form field controllers
  late TextEditingController _produceNameController;
  ProduceCategory _selectedProduceCategory = ProduceCategory.vegetable;
  late TextEditingController _customCategoryController;
  late TextEditingController _quantityController;
  late TextEditingController _unitController;
  late TextEditingController _targetPriceController; // Optional
  late TextEditingController _currencyController;
  late TextEditingController _barangayController;
  late TextEditingController _municipalityController;
  late TextEditingController _deliveryAddressDetailsController; // Optional
  DateTime? _requestExpiryDate; // Optional
  late TextEditingController _notesController; // Optional

  bool _showCustomCategory = false;
  bool _isLoading = false;
  bool get _isEditMode => widget.existingRequest != null; // Added getter for edit mode

  @override
  void initState() {
    super.initState();

    final request = widget.existingRequest;
    if (request != null) {
      // Pre-fill fields for editing
      _produceNameController = TextEditingController(text: request.produceNeededName);
      // Need to determine ProduceCategory enum from request.produceNeededCategory (String)
      // This might require a helper function or careful parsing if custom category was part of produceNeededName
      // For now, let's assume produceNeededCategory directly maps to an enum or is "Other"
      try {
        _selectedProduceCategory = ProduceCategory.values.firstWhere(
          (e) => e.displayName == request.produceNeededCategory || e.name == request.produceNeededCategory
        );
        if (_selectedProduceCategory == ProduceCategory.other) {
          _customCategoryController = TextEditingController(text: request.produceNeededName); // If it was other, the name was in produceNeededName
           _produceNameController.text = ""; // Clear produce name if custom category was used this way
        } else {
           _customCategoryController = TextEditingController();
        }
      } catch (e) {
        // Default if category string doesn't match
        _selectedProduceCategory = ProduceCategory.other; 
        _customCategoryController = TextEditingController(text: request.produceNeededName);
         _produceNameController.text = "";
        print("Error parsing category from existing request: $e");
      }

      _quantityController = TextEditingController(text: request.quantityNeeded.toString());
      _unitController = TextEditingController(text: request.quantityUnit);
      _targetPriceController = TextEditingController(text: request.priceRangeMaxPerUnit?.toString() ?? '');
      _currencyController = TextEditingController(text: request.currency ?? 'PHP');
      _barangayController = TextEditingController(text: request.deliveryLocation.barangay);
      _municipalityController = TextEditingController(text: request.deliveryLocation.municipality);
      _deliveryAddressDetailsController = TextEditingController(text: request.deliveryLocation.addressHint ?? '');
      _requestExpiryDate = request.deliveryDeadline.toDate();
      _notesController = TextEditingController(text: request.notesForFarmer ?? '');

      if (_selectedProduceCategory == ProduceCategory.other) {
        _showCustomCategory = true;
      }

    } else {
      // Initialize for new request
      _produceNameController = TextEditingController();
      _selectedProduceCategory = ProduceCategory.vegetable;
      _customCategoryController = TextEditingController();
      _quantityController = TextEditingController();
      _unitController = TextEditingController();
      _targetPriceController = TextEditingController();
      _currencyController = TextEditingController(text: 'PHP');
      _barangayController = TextEditingController();
      _municipalityController = TextEditingController();
      _deliveryAddressDetailsController = TextEditingController();
      _notesController = TextEditingController();
      // _requestExpiryDate remains null initially
    }
  }

  @override
  void dispose() {
    _produceNameController.dispose();
    _customCategoryController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _targetPriceController.dispose();
    _currencyController.dispose();
    _barangayController.dispose();
    _municipalityController.dispose();
    _deliveryAddressDetailsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectExpiryDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _requestExpiryDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _requestExpiryDate) {
      setState(() {
        _requestExpiryDate = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });

      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: User not logged in.')),
          );
        }
        setState(() { _isLoading = false; });
        return;
      }

      String effectiveProduceNeededName = _produceNameController.text;
      String effectiveProduceNeededCategory = _selectedProduceCategory.displayName;

      if (_selectedProduceCategory == ProduceCategory.other) {
        effectiveProduceNeededName = _customCategoryController.text;
      }

      final requestData = BuyerRequest(
        id: _isEditMode ? widget.existingRequest!.id : null, // Preserve ID for updates
        buyerId: currentUser.uid,
        buyerName: currentUser.displayName ?? currentUser.email ?? 'Unknown Buyer',
        requestDateTime: _isEditMode 
            ? widget.existingRequest!.requestDateTime 
            : Timestamp.now(), // Preserve original creation time on edit
        produceNeededName: effectiveProduceNeededName, 
        produceNeededCategory: effectiveProduceNeededCategory, 
        quantityNeeded: double.tryParse(_quantityController.text) ?? 0, 
        quantityUnit: _unitController.text, 
        deliveryLocation: LocationData( 
          barangay: _barangayController.text,
          municipality: _municipalityController.text,
          addressHint: _deliveryAddressDetailsController.text.isNotEmpty 
              ? _deliveryAddressDetailsController.text 
              : null,
          latitude: _isEditMode ? widget.existingRequest!.deliveryLocation.latitude : 0.0, 
          longitude: _isEditMode ? widget.existingRequest!.deliveryLocation.longitude : 0.0, 
        ),
        deliveryDeadline: _requestExpiryDate != null 
            ? Timestamp.fromDate(_requestExpiryDate!) 
            : Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
        priceRangeMaxPerUnit: _targetPriceController.text.isNotEmpty 
            ? double.tryParse(_targetPriceController.text) 
            : null, 
        currency: _currencyController.text,
        notesForFarmer: _notesController.text.isNotEmpty ? _notesController.text : null, 
        status: _isEditMode 
            ? widget.existingRequest!.status // Preserve status on edit, or decide if it should reset
            : BuyerRequestStatus.pending_match, 
        lastUpdated: Timestamp.now(), // Always update lastUpdated
        // isAiMatchPreferred will use existing value or default from constructor
        isAiMatchPreferred: _isEditMode 
            ? widget.existingRequest!.isAiMatchPreferred 
            : true, // Default for new, or carry over existing
        // fulfilledByOrderIds and totalQuantityFulfilled should be preserved if editing
        fulfilledByOrderIds: _isEditMode ? widget.existingRequest!.fulfilledByOrderIds : [],
        totalQuantityFulfilled: _isEditMode ? widget.existingRequest!.totalQuantityFulfilled : 0.0,
      );

      try {
        if (_isEditMode) {
          await firestoreService.updateBuyerRequest(requestData);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Buyer request updated successfully!')),
            );
            Navigator.of(context).pop();
          }
        } else {
          await firestoreService.addBuyerRequest(requestData);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Buyer request submitted successfully!')),
            );
            Navigator.of(context).pop();
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error submitting request: \$e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() { _isLoading = false; });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Produce Request'),
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
                      decoration: const InputDecoration(labelText: 'Desired Quantity'),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^[0-9]+.?[0-9]*'))],
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter quantity';
                        if (double.tryParse(value) == null || double.parse(value) <= 0) return 'Enter a valid quantity';
                        return null;
                      },
                    ),
                     const SizedBox(height: 16),
                    TextFormField(
                      controller: _unitController,
                      decoration: const InputDecoration(labelText: 'Unit (e.g., kg, piece, sack)'),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter unit';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _targetPriceController,
                      decoration: const InputDecoration(labelText: 'Target Price per Unit (Optional)'),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^[0-9]+.?[0-9]*'))],
                       validator: (value) {
                        if (value != null && value.isNotEmpty) {
                           if (double.tryParse(value) == null || double.parse(value) <= 0) return 'Enter a valid price or leave empty';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                     TextFormField(
                      controller: _currencyController,
                      decoration: const InputDecoration(labelText: 'Currency'),
                       validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter currency';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    Text('Preferred Delivery Location', style: Theme.of(context).textTheme.titleMedium),
                    TextFormField(
                      controller: _barangayController,
                      decoration: const InputDecoration(labelText: 'Barangay'),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter barangay';
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _municipalityController,
                      decoration: const InputDecoration(labelText: 'Municipality / City'),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter municipality/city';
                        return null;
                      },
                    ),
                     TextFormField(
                      controller: _deliveryAddressDetailsController,
                      decoration: const InputDecoration(labelText: 'Address Hint / Landmark (Optional)'),
                    ),
                    const SizedBox(height: 24),
                    Text('Request Options', style: Theme.of(context).textTheme.titleMedium),
                     ListTile(
                      title: Text(_requestExpiryDate == null
                          ? 'Set Request Expiry Date (Optional)'
                          : 'Request Valid Until: ${DateFormat.yMd().format(_requestExpiryDate!)}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () => _selectExpiryDate(context),
                    ),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(labelText: 'Additional Notes (Optional)', alignLabelWithHint: true),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitForm,
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
                        child: _isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Submit Request'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 