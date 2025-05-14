import 'package:flutter/material.dart';
import 'package:animo/services/firebase_auth_service.dart'; // Will use for logout
import 'package:provider/provider.dart'; // Example if using Provider
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:animo/core/models/order.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;

class DriverDashboardScreen extends StatelessWidget {
  const DriverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Available Orders"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Provider.of<FirebaseAuthService>(context, listen: false).signOut();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Map Placeholder Section
          Container(
            height: MediaQuery.of(context).size.height * 0.4,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.map,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Map View',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                // Fake location button
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.white,
                    onPressed: () {},
                    child: const Icon(
                      Icons.my_location,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Orders List Section
          Expanded(
            child: StreamBuilder<firestore.QuerySnapshot>(
              stream: firestore.FirebaseFirestore.instance
                  .collection('orders')
                  .where('status', whereIn: [
                    OrderStatus.searching_for_driver.name,
                    OrderStatus.confirmed_by_platform.name,
                  ])
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Something went wrong'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final orders = snapshot.data?.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Order.fromFirestore(data, doc.id);
                }).toList() ?? [];

                return ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.local_shipping,
                                color: Colors.green[700],
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
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Quantity: ${order.orderedQuantity} ${order.unit}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Icon(Icons.location_on, color: Colors.green[700], size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Pickup: ${order.pickupLocation.addressHint ?? 'No address'}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.flag, color: Colors.red[400], size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Delivery: ${order.deliveryLocation.addressHint ?? 'No address'}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${order.currency} ${order.totalOrderAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    // TODO: Implement accept order functionality
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green[700],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                  ),
                                  child: const Text('Accept Order'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 