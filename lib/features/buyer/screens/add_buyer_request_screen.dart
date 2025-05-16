import 'package:animo/core/models/app_user.dart';
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
  late TextEditingController _targetPriceController;
  late TextEditingController _currencyController;
  late TextEditingController _barangayController;
  late TextEditingController _municipalityController;
  late TextEditingController _deliveryAddressDetailsController;
  DateTime? _requestExpiryDate;
  late TextEditingController _notesController;

  bool _showCustomCategory = false;
  bool _isLoading = false;
  bool _isLoadingUserDetails = false; // For loading default address
  bool get _isEditMode => widget.existingRequest != null;

  double? _loadedDefaultLat;
  double? _loadedDefaultLng;
  // Store AppUser to get buyerName on new request
  AppUser? _currentUser;


  @override
  void initState() {
    super.initState();
    _initializeControllers();

    if (!_isEditMode) {
      _loadUserDetailsAndDefaultAddress();
    }
  }

  void _initializeControllers() {
    final request = widget.existingRequest;
    _produceNameController = TextEditingController(text: request?.produceNeededName ?? '');
    
    if (request != null) {
      try {
        _selectedProduceCategory = ProduceCategory.values.firstWhere(
          (e) => e.displayName.toLowerCase() == request.produceNeededCategory.toLowerCase() || e.name.toLowerCase() == request.produceNeededCategory.toLowerCase()
        );
         _customCategoryController = TextEditingController(text: (_selectedProduceCategory == ProduceCategory.other) ? request.produceNeededName : '');
         if(_selectedProduceCategory == ProduceCategory.other && request.produceNeededName != null){
           // If it was "Other" and the custom name was stored in produceNeededName
           // _produceNameController.text = ""; // No, produceNeededName is the custom category name
         }
      } catch (e) {
        _selectedProduceCategory = ProduceCategory.other;
        _customCategoryController = TextEditingController(text: request.produceNeededName ?? '');
        debugPrint("Error parsing category from existing request: $e, falling back to Other.");
      }
    } else {
      _selectedProduceCategory = ProduceCategory.vegetable; // Default for new
      _customCategoryController = TextEditingController();
    }
     _showCustomCategory = (_selectedProduceCategory == ProduceCategory.other);


    _quantityController = TextEditingController(text: request?.quantityNeeded.toString() ?? '');
    _unitController = TextEditingController(text: request?.quantityUnit ?? '');
    _targetPriceController = TextEditingController(text: request?.priceRangeMaxPerUnit?.toString() ?? '');
    _currencyController = TextEditingController(text: request?.currency ?? 'PHP');
    
    _barangayController = TextEditingController(text: request?.deliveryLocation.barangay ?? '');
    _municipalityController = TextEditingController(text: request?.deliveryLocation.municipality ?? '');
    _deliveryAddressDetailsController = TextEditingController(text: request?.deliveryLocation.addressHint ?? '');
    
    _requestExpiryDate = request?.deliveryDeadline.toDate();
    _notesController = TextEditingController(text: request?.notesForFarmer ?? '');

    // Store lat/lng if editing
    if (_isEditMode && request != null) {
        _loadedDefaultLat = request.deliveryLocation.latitude;
        _loadedDefaultLng = request.deliveryLocation.longitude;
    }
  }

  Future<void> _loadUserDetailsAndDefaultAddress() async {
    setState(() { _isLoadingUserDetails = true; });
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser != null) {
      try {
        _currentUser = await firestoreService.getAppUser(firebaseUser.uid);
        if (_currentUser?.defaultDeliveryLocation != null) {
          final locMap = _currentUser!.defaultDeliveryLocation!;
          final formattedAddressString = locMap['formattedAddress'] as String? ?? '';
          _deliveryAddressDetailsController.text = formattedAddressString;
          _loadedDefaultLat = locMap['latitude'] as double?;
          _loadedDefaultLng = locMap['longitude'] as double?;

          String? barangayFromMap = locMap['barangay'] as String?;
          String? municipalityFromMap = locMap['municipality'] as String?;
          String? parsedBarangay;
          String? parsedMunicipality;

          if (formattedAddressString.isNotEmpty) {
            List<String> parts = formattedAddressString.split(',').map((s) => s.trim()).toList();
            if (parts.isNotEmpty) {
              parsedBarangay = parts[0];
            }
            if (parts.length > 1) {
              parsedMunicipality = parts[1];
            }
          }

          _barangayController.text = (barangayFromMap != null && barangayFromMap.isNotEmpty)
                                      ? barangayFromMap
                                      : (parsedBarangay ?? _barangayController.text);
          _municipalityController.text = (municipalityFromMap != null && municipalityFromMap.isNotEmpty)
                                         ? municipalityFromMap
                                         : (parsedMunicipality ?? _municipalityController.text);
        }
      } catch (e) {
        debugPrint("Error loading user details/default address: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not load default address: ${e.toString()}')),
          );
        }
      }
    }
    if(mounted){
      setState(() { _isLoadingUserDetails = false; });
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
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save(); // Ensure onSaved callbacks are triggered

    setState(() { _isLoading = true; });

    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final firebaseCurrentUser = FirebaseAuth.instance.currentUser;

    if (firebaseCurrentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: User not logged in.')),
        );
      }
      setState(() { _isLoading = false; });
      return;
    }
    
    // Use AppUser from state if available (especially for new requests to get buyerName)
    // Fallback to FirebaseAuth.instance.currentUser for uid/email if AppUser isn't loaded
    final buyerUid = firebaseCurrentUser.uid;
    final buyerDisplayName = _isEditMode 
        ? widget.existingRequest!.buyerName // Preserve original buyerName on edit
        : (_currentUser?.displayName ?? firebaseCurrentUser.displayName ?? firebaseCurrentUser.email ?? 'Unknown Buyer');


    String effectiveProduceNeededName = _produceNameController.text;
    String effectiveProduceNeededCategory = _selectedProduceCategory.displayName;

    if (_selectedProduceCategory == ProduceCategory.other) {
      effectiveProduceNeededName = _customCategoryController.text;
    }
    
    final requestData = BuyerRequest(
      id: _isEditMode ? widget.existingRequest!.id : null,
      buyerId: buyerUid,
      buyerName: buyerDisplayName,
      requestDateTime: _isEditMode 
          ? widget.existingRequest!.requestDateTime 
          : Timestamp.now(),
      produceNeededName: effectiveProduceNeededName, 
      produceNeededCategory: effectiveProduceNeededCategory, 
      quantityNeeded: double.tryParse(_quantityController.text) ?? 0, 
      quantityUnit: _unitController.text, 
      deliveryLocation: LocationData( 
        barangay: _barangayController.text.isNotEmpty ? _barangayController.text : null,
        municipality: _municipalityController.text.isNotEmpty ? _municipalityController.text : null,
        addressHint: _deliveryAddressDetailsController.text.isNotEmpty 
            ? _deliveryAddressDetailsController.text 
            : null,
        latitude: _isEditMode ? (widget.existingRequest!.deliveryLocation.latitude) : (_loadedDefaultLat ?? 0.0), 
        longitude: _isEditMode ? (widget.existingRequest!.deliveryLocation.longitude) : (_loadedDefaultLng ?? 0.0), 
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
          ? widget.existingRequest!.status
          : BuyerRequestStatus.pending_match, 
      lastUpdated: Timestamp.now(),
      isAiMatchPreferred: _isEditMode 
          ? widget.existingRequest!.isAiMatchPreferred 
          : true,
      fulfilledByOrderIds: _isEditMode ? widget.existingRequest!.fulfilledByOrderIds : [],
      totalQuantityFulfilled: _isEditMode ? widget.existingRequest!.totalQuantityFulfilled : 0.0,
    );

    try {
      if (_isEditMode) {
        await firestoreService.updateBuyerRequest(requestData);
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request updated successfully!')));
      } else {
        await firestoreService.addBuyerRequest(requestData);
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request added successfully!')));
      }
      if(mounted) Navigator.of(context).pop();
    } catch (e) {
      debugPrint("Error submitting request: $e");
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit request: ${e.toString()}')),
        );
      }
    } finally {
      if(mounted) setState(() { _isLoading = false; });
    }
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Produce Request' : 'Make a Produce Request'),
        elevation: 1,
      ),
      body: _isLoadingUserDetails && !_isEditMode
        ? const Center(child: CircularProgressIndicator())
        : Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Produce Details Section
                _buildSectionHeader(context, 'Produce Details'),
                Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
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
                              _selectedProduceCategory = newValue!;
                              _showCustomCategory = (_selectedProduceCategory == ProduceCategory.other);
                              if (!_showCustomCategory) _customCategoryController.clear();
                              else _produceNameController.clear(); // Clear produce name if "Other" is selected
                            });
                          },
                           validator: (value) => value == null ? 'Please select a category' : null,
                        ),
                        if (_showCustomCategory) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _customCategoryController,
                            decoration: const InputDecoration(labelText: 'Custom Produce Name/Category', border: OutlineInputBorder()),
                            validator: (value) => _showCustomCategory && (value == null || value.isEmpty) ? 'Please enter custom produce name' : null,
                            onSaved: (value) => _customCategoryController.text = value ?? '',
                          ),
                        ] else ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _produceNameController,
                            decoration: const InputDecoration(labelText: 'Produce Name (e.g., Tomatoes, Apples)', border: OutlineInputBorder()),
                            validator: (value) => !_showCustomCategory && (value == null || value.isEmpty) ? 'Please enter produce name' : null,
                            onSaved: (value) => _produceNameController.text = value ?? '',
                          ),
                        ],
                      ],
                    ),
                  )
                ),

                // Quantity and Unit Section
                _buildSectionHeader(context, 'Quantity & Unit'),
                 Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                         Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _quantityController,
                                decoration: const InputDecoration(labelText: 'Quantity Needed', border: OutlineInputBorder()),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^[0-9]+.?[0-9]*'))],
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Enter quantity';
                                  if (double.tryParse(value) == null || double.parse(value) <= 0) return 'Invalid quantity';
                                  return null;
                                },
                                onSaved: (value) => _quantityController.text = value ?? '',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _unitController,
                                decoration: const InputDecoration(labelText: 'Unit (e.g., kg, piece)', border: OutlineInputBorder()),
                                validator: (value) => (value == null || value.isEmpty) ? 'Enter unit' : null,
                                onSaved: (value) => _unitController.text = value ?? '',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                ),

                // Delivery Location Section
                _buildSectionHeader(context, 'Preferred Delivery Location'),
                 Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _deliveryAddressDetailsController,
                          decoration: const InputDecoration(labelText: 'Street Address / Landmark (Optional)', border: OutlineInputBorder()),
                           onSaved: (value) => _deliveryAddressDetailsController.text = value ?? '',
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _barangayController,
                                decoration: const InputDecoration(labelText: 'Barangay', border: OutlineInputBorder()),
                                validator: (value) => (value == null || value.isEmpty) ? 'Enter barangay' : null,
                                onSaved: (value) => _barangayController.text = value ?? '',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _municipalityController,
                                decoration: const InputDecoration(labelText: 'Municipality/City', border: OutlineInputBorder()),
                                validator: (value) => (value == null || value.isEmpty) ? 'Enter municipality/city' : null,
                                onSaved: (value) => _municipalityController.text = value ?? '',
                              ),
                            ),
                          ],
                        ),
                        if (!_isEditMode && (_loadedDefaultLat == null || _loadedDefaultLng == null) && !_isLoadingUserDetails)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'No default address found. Please enter manually. You can set a default address in the "Available Produce" tab.',
                              style: TextStyle(color: colorScheme.onSurfaceVariant.withOpacity(0.7)),
                            ),
                          ),
                      ],
                    ),
                  )
                ),

                // Optional Details Section
                _buildSectionHeader(context, 'Optional Details'),
                 Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _targetPriceController,
                                decoration: const InputDecoration(labelText: 'Target Price per Unit', border: OutlineInputBorder()),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^[0-9]+.?[0-9]*'))],
                                validator: (value) {
                                  if (value != null && value.isNotEmpty) {
                                    if (double.tryParse(value) == null || double.parse(value) <= 0) return 'Enter a valid price or leave empty';
                                  }
                                  return null;
                                },
                                onSaved: (value) => _targetPriceController.text = value ?? '',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _currencyController,
                                decoration: const InputDecoration(labelText: 'Currency', border: OutlineInputBorder()),
                                validator: (value) => (value == null || value.isEmpty) ? 'Enter currency' : null,
                                onSaved: (value) => _currencyController.text = value ?? '',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _notesController,
                          decoration: const InputDecoration(labelText: 'Notes for Farmer (e.g., specific variety, preferred condition)', border: OutlineInputBorder()),
                          maxLines: 3,
                          onSaved: (value) => _notesController.text = value ?? '',
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          title: const Text('Request Expiry Date (Optional)'),
                          subtitle: Text(_requestExpiryDate == null ? 'No expiry date set (defaults to 7 days)' : DateFormat.yMMMd().format(_requestExpiryDate!)),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () => _selectExpiryDate(context),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  )
                ),
                
                const SizedBox(height: 30),
                Center(
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton.icon(
                          icon: Icon(_isEditMode ? Icons.save_alt_outlined : Icons.add_shopping_cart_outlined),
                          label: Text(_isEditMode ? 'Update Request' : 'Submit Request'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                            textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 16),
                          ),
                          onPressed: _submitForm,
                        ),
                ),
                 const SizedBox(height: 20), // Bottom padding
              ],
            ),
          ),
        ),
    );
  }
} 