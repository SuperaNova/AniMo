import 'package:flutter/material.dart';

class AllListingsTabContent extends StatelessWidget {
  const AllListingsTabContent({super.key});

  @override
  Widget build(BuildContext context) {
    // Replace with your actual screen content for "All Listings"
    // This might involve fetching and displaying a full list of ProduceListings
    // using a StreamBuilder and your FirestoreService.
    return const Center(
      child: Text(
        'All My Listings Screen',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }
}
