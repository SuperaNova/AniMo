import 'package:animo/core/models/app_user.dart';
import 'package:animo/core/models/location_data.dart';
import 'package:animo/core/models/order.dart' as app_order;
import 'package:animo/core/models/produce_listing.dart';
import 'package:animo/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ProduceListingDetailScreen extends StatefulWidget {
  static const String routeName = '/produce-listing-detail';
  final ProduceListing listing;

  const ProduceListingDetailScreen({super.key, required this.listing});

  @override
  State<ProduceListingDetailScreen> createState() =>
      _ProduceListingDetailScreenState();
}

class _ProduceListingDetailScreenState
    extends State<ProduceListingDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  double _quantityToOrder = 1.0;
  bool _isLoadingOrderPlacement = false;
  AppUser? _currentUser;
  Map<String, dynamic>? _defaultDeliveryLocationMap;
  LocationData? _defaultDeliveryLocation;
  bool _isLoadingUserDetails = true;

  late FirestoreService _firestoreService;

  @override
  void initState() {
    super.initState();
    _firestoreService = Provider.of<FirestoreService>(context, listen: false);
    _quantityToOrder = widget.listing.unit.toLowerCase() == 'kg' || widget.listing.unit.toLowerCase() == 'gram' ? 0.5 : 1.0;
    _loadUserDetails();
  }

  Future<void> _loadUserDetails() async {
    setState(() {
      _isLoadingUserDetails = true;
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.uid.isNotEmpty) {
      try {
        _currentUser = await _firestoreService.getAppUser(user.uid);
        if (_currentUser?.defaultDeliveryLocation != null) {
          _defaultDeliveryLocationMap = _currentUser!.defaultDeliveryLocation;
          // Map to LocationData, prioritizing specific fields if available
          _defaultDeliveryLocation = LocationData(
            latitude: _defaultDeliveryLocationMap!['latitude'] as double? ?? 0.0,
            longitude: _defaultDeliveryLocationMap!['longitude'] as double? ?? 0.0,
            addressHint: _defaultDeliveryLocationMap!['formattedAddress'] as String?,
            // Assuming barangay/municipality might not be in the saved map
            // and LocationData.fromMap would handle this, but here we construct directly
            barangay: _defaultDeliveryLocationMap!['barangay'] as String?,
            municipality: _defaultDeliveryLocationMap!['municipality'] as String?,
          );
        }
      } catch (e) {
        debugPrint("Error loading user details: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading your details: ${e.toString()}')),
          );
        }
      }
    }
    if (mounted) {
      setState(() {
        _isLoadingUserDetails = false;
      });
    }
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save();

    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User details not loaded. Please try again.')),
      );
      return;
    }

    if (_defaultDeliveryLocation == null || 
        (_defaultDeliveryLocation!.latitude == 0.0 && _defaultDeliveryLocation!.longitude == 0.0) ||
         _defaultDeliveryLocation!.addressHint == null || _defaultDeliveryLocation!.addressHint!.isEmpty) {
      // Show a dialog prompting to set address
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delivery Address Missing'),
          content: const Text(
              'Please set your default delivery address in the "Available Produce" tab before placing an order.'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      );
      return;
    }
    
    if (_quantityToOrder <= 0){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantity must be greater than 0.')),
      );
      return;
    }

    if (_quantityToOrder > widget.listing.quantity) {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Requested quantity exceeds available stock (${widget.listing.quantity} ${widget.listing.unit}).')),
      );
      return;
    }


    setState(() {
      _isLoadingOrderPlacement = true;
    });

    try {
      final totalGoodsPrice = _quantityToOrder * widget.listing.pricePerUnit;
      // For now, totalOrderAmount is same as totalGoodsPrice. Delivery fee logic TBD.
      final totalOrderAmount = totalGoodsPrice; 

      final order = app_order.Order(
        // id will be generated by Firestore
        produceListingId: widget.listing.id!,
        farmerId: widget.listing.farmerId,
        buyerId: _currentUser!.uid,
        produceName: widget.listing.produceName,
        produceCategory: widget.listing.produceCategory,
        customProduceCategory: widget.listing.customProduceCategory,
        orderedQuantity: _quantityToOrder,
        unit: widget.listing.unit,
        pricePerUnit: widget.listing.pricePerUnit,
        currency: widget.listing.currency,
        totalGoodsPrice: totalGoodsPrice,
        pickupLocation: widget.listing.pickupLocation, // Already LocationData
        deliveryLocation: _defaultDeliveryLocation!,
        status: app_order.OrderStatus.pending_confirmation,
        // statusHistory: [], // Will be initialized by model if needed
        // deliveryFeeDetails: null, // For future implementation
        totalOrderAmount: totalOrderAmount, 
        codAmountToCollectFromBuyer: totalOrderAmount, // Assuming COD for now
        paymentType: app_order.PaymentType.cod,
        paymentStatusGoods: app_order.PaymentStatus.pending,
        paymentStatusDelivery: app_order.PaymentStatus.pending, // Assuming delivery fee also pending
        createdAt: DateTime.now(), // FirestoreService will use serverTimestamp
        lastUpdated: DateTime.now(), // FirestoreService will use serverTimestamp
        buyerNotes: '', // Placeholder for potential buyer notes input
        // Optional fields like farmerName, buyerName, listingPhotoUrl can be added to Order model or fetched
      );

      final orderId = await _firestoreService.placeOrder(order);

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Order Confirmed!'),
            content: Text('Your order for ${widget.listing.produceName} has been placed successfully.\\nOrder ID: $orderId'),
            actions: <Widget>[
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop(); // Optionally pop detail screen
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint("Error placing order: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to place order: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingOrderPlacement = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget buildDetailRow(String label, String? value, {TextStyle? valueStyle}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
            Expanded(child: Text(value ?? 'N/A', style: valueStyle)),
          ],
        ),
      );
    }

    String category = widget.listing.produceCategory.displayName;
    if (widget.listing.produceCategory == ProduceCategory.other &&
        widget.listing.customProduceCategory != null &&
        widget.listing.customProduceCategory!.isNotEmpty) {
      category += " (${widget.listing.customProduceCategory})";
    }

    String harvestInfo = widget.listing.harvestTimestamp != null
        ? DateFormat.yMMMd().add_jm().format(widget.listing.harvestTimestamp!)
        : 'N/A';
    String expiryInfo = widget.listing.expiryTimestamp != null
        ? DateFormat.yMMMd().add_jm().format(widget.listing.expiryTimestamp!)
        : 'N/A';
    String availabilityStatus = widget.listing.status.displayName;
     if (widget.listing.quantity <= 0 && widget.listing.status == ProduceListingStatus.available) {
        availabilityStatus = "Sold Out (Pending Update)";
    }

    // Construct pickup address string safely
    String pickupAddressString = widget.listing.pickupLocation.addressHint ?? 'Details not specified';
    String barangay = widget.listing.pickupLocation.barangay ?? '';
    String municipality = widget.listing.pickupLocation.municipality ?? '';
    if (barangay.isNotEmpty || municipality.isNotEmpty) {
      pickupAddressString += '\\n'; // Add newline only if barangay or municipality is present
      if (barangay.isNotEmpty && municipality.isNotEmpty) {
        pickupAddressString += '$barangay, $municipality';
      } else if (barangay.isNotEmpty) {
        pickupAddressString += barangay;
      } else {
        pickupAddressString += municipality;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.listing.produceName),
      ),
      body: _isLoadingUserDetails
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (widget.listing.photoUrls.isNotEmpty)
                      Container(
                        height: 250,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: NetworkImage(widget.listing.photoUrls.first),
                            fit: BoxFit.cover,
                          ),
                        ),
                        margin: const EdgeInsets.only(bottom: 16.0),
                      )
                    else
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                           color: Colors.grey[300],
                           borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        margin: const EdgeInsets.only(bottom: 16.0),
                        child: const Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey),
                      ),
                    Text(widget.listing.produceName, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (widget.listing.description != null && widget.listing.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Text(widget.listing.description!, style: Theme.of(context).textTheme.bodyLarge),
                      ),
                    buildDetailRow('Category', category),
                    buildDetailRow('Price', '${widget.listing.pricePerUnit.toStringAsFixed(2)} ${widget.listing.currency} per ${widget.listing.unit}'),
                    buildDetailRow('Available Quantity', '${widget.listing.quantity.toStringAsFixed(1)} ${widget.listing.unit}'),
                    buildDetailRow('Status', availabilityStatus, valueStyle: TextStyle(color: widget.listing.status == ProduceListingStatus.available && widget.listing.quantity > 0 ? Colors.green.shade700 : Colors.orange.shade700)),
                    if (widget.listing.estimatedWeightKgPerUnit != null)
                      buildDetailRow('Est. Weight/Unit', '${widget.listing.estimatedWeightKgPerUnit} kg'),
                    
                    const SizedBox(height: 16),
                    Text('Farmer & Pickup Information', style: Theme.of(context).textTheme.titleLarge),
                    const Divider(),
                    buildDetailRow('Farmer', widget.listing.farmerName ?? 'N/A'),
                    buildDetailRow('Pickup Address', pickupAddressString),
                    
                    const SizedBox(height: 16),
                    Text('Freshness Information', style: Theme.of(context).textTheme.titleLarge),
                    const Divider(),
                    buildDetailRow('Harvest Date', harvestInfo),
                    buildDetailRow('Expiry Date', expiryInfo),
                    
                    const SizedBox(height: 24),
                    // Quantity Input
                    TextFormField(
                      initialValue: _quantityToOrder.toString(),
                      decoration: InputDecoration(
                        labelText: 'Quantity to Order (${widget.listing.unit})',
                        border: const OutlineInputBorder(),
                        suffixText: widget.listing.unit,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter quantity';
                        }
                        final q = double.tryParse(value);
                        if (q == null) {
                          return 'Invalid number';
                        }
                        if (q <= 0) {
                          return 'Quantity must be positive';
                        }
                        if (q > widget.listing.quantity) {
                          return 'Max available: ${widget.listing.quantity}';
                        }
                        return null;
                      },
                      onSaved: (value) {
                        _quantityToOrder = double.tryParse(value!) ?? _quantityToOrder;
                      },
                    ),
                    const SizedBox(height: 8),
                    if (_defaultDeliveryLocation != null && _defaultDeliveryLocation!.addressHint != null)
                       Padding(
                         padding: const EdgeInsets.symmetric(vertical: 8.0),
                         child: Text("Deliver to: ${_defaultDeliveryLocation!.addressHint}", style: Theme.of(context).textTheme.bodySmall),
                       )
                    else if (!_isLoadingUserDetails) // Only show if not loading and still no address
                        Padding(
                         padding: const EdgeInsets.symmetric(vertical: 8.0),
                         child: Text("Default delivery address not set.", style: TextStyle(color: Theme.of(context).colorScheme.error)),
                       ),


                    const SizedBox(height: 20),
                    Center(
                      child: _isLoadingOrderPlacement
                          ? const CircularProgressIndicator()
                          : ElevatedButton.icon(
                              icon: const Icon(Icons.shopping_cart_checkout),
                              label: const Text('Confirm & Request Order'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                                textStyle: Theme.of(context).textTheme.labelLarge,
                              ),
                              onPressed: _placeOrder,
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