import 'package:animo/core/models/app_user.dart';
import 'package:animo/core/models/produce_listing.dart';
import 'package:animo/services/produce_listing_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// TODO: Import the screen for adding/editing produce listings
import 'add_edit_produce_listing_screen.dart';

class FarmerDashboardScreen extends StatefulWidget {
  static const String routeName = '/farmer-dashboard';
  const FarmerDashboardScreen({super.key});

  @override
  State<FarmerDashboardScreen> createState() => _FarmerDashboardScreenState();
}

class _FarmerDashboardScreenState extends State<FarmerDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final appUser = Provider.of<AppUser?>(context);
    final produceListingService = Provider.of<ProduceListingService>(context);

    if (appUser == null) {
      // This should ideally not happen if AuthWrapper is working correctly
      // and only navigates here for authenticated users.
      return const Scaffold(
        body: Center(
          child: Text('Error: No user logged in. Please restart the app.'),
        ),
      );
    }
    
    // Ensure user is a farmer, though AuthWrapper should handle role-based navigation
    if (appUser.role != UserRole.farmer) {
         return const Scaffold(
           body: Center(
             child: Text('Access Denied: This area is for farmers only.'),
           ),
         );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${appUser.displayName ?? 'Farmer'}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Access FirebaseAuthService to sign out
              // This assumes FirebaseAuthService is provided higher up or we import it
              // For simplicity, let's assume it's accessible or we add that later.
              // Provider.of<FirebaseAuthService>(context, listen: false).signOut();
              // For now, just print, actual sign out to be confirmed for service access path
              print("Logout requested");
               ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logout functionality to be fully implemented.')),
              );
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: StreamBuilder<List<ProduceListing>>(
        stream: produceListingService.getFarmerProduceListings(appUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print(snapshot.error); // Log the error for debugging
            return Center(child: Text('Error loading your listings: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'You have no produce listings yet. Tap the + button to add one!',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            );
          }

          final listings = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: listings.length,
            itemBuilder: (context, index) {
              final listing = listings[index];
              // TODO: Create a proper ProduceListItem widget for better UI
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                child: ListTile(
                  // leading: listing.photoUrls?.isNotEmpty == true 
                  //   ? Image.network(listing.photoUrls!.first, width: 50, height: 50, fit: BoxFit.cover)
                  //   : const Icon(Icons.inventory_2_outlined, size: 40), // Placeholder icon
                  title: Text(listing.produceName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      '${listing.currentAvailableQuantity} ${listing.quantityUnit} available\nExpires: ${listing.expiryTimestamp.toDate().toLocal().toString().substring(0,16)}\nStatus: ${listing.status.name}'),
                  trailing: const Icon(Icons.chevron_right),
                  isThreeLine: true,
                  onTap: () {
                    // TODO: Navigate to an edit/detail screen for this listing
                    print('Tapped on listing: ${listing.id}');
                     ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Navigate to edit/detail for ${listing.produceName}')),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Navigate to AddEditProduceListingScreen
          // print('Add new produce listing pressed');
          //  ScaffoldMessenger.of(context).showSnackBar(
          //   const SnackBar(content: Text('Navigate to Add Produce Screen to be implemented.')),
          // );
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => AddEditProduceListingScreen(
              farmerId: appUser.uid,
              farmerName: appUser.displayName,
              // existingListing will be null for adding a new one
            ),
          ));
        },
        tooltip: 'Add New Listing',
        child: const Icon(Icons.add),
      ),
    );
  }
} 