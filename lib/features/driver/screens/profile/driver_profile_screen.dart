import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:animo/services/firebase_auth_service.dart';
import 'package:animo/core/models/app_user.dart'; // For AppUser model, if needed for more details
import 'package:animo/services/firestore_service.dart'; // To fetch AppUser

class DriverProfileScreen extends StatefulWidget {
  static const String routeName = '/driver-profile';
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  AppUser? _driverUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDriverDetails();
  }

  Future<void> _loadDriverDetails() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      try {
        _driverUser = await firestoreService.getAppUser(firebaseUser.uid);
      } catch (e) {
        debugPrint("Error loading driver details: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error loading profile: $e")),
          );
        }
      }
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showLogoutBottomSheet(BuildContext context) {
    final authService = Provider.of<FirebaseAuthService>(context, listen: false);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (BuildContext bc) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
              children: <Widget>[
                const ListTile(
                  title: Text(
                    'Confirm Logout',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  subtitle: Text('Are you sure you want to sign out?'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.exit_to_app, color: Colors.red),
                  title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    Navigator.of(context).pop(); // Close bottom sheet
                    await authService.signOut();
                    // Navigation after logout will likely be handled by an auth wrapper/listener
                    // For now, can pop or navigate to a root/login screen if needed directly
                    // Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cancel_outlined),
                  title: const Text('Cancel'),
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _driverUser?.displayName ?? FirebaseAuth.instance.currentUser?.displayName;
    final email = _driverUser?.email ?? FirebaseAuth.instance.currentUser?.email;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: _driverUser?.photoURL != null && _driverUser!.photoURL!.isNotEmpty
                          ? NetworkImage(_driverUser!.photoURL!)
                          : null,
                      child: _driverUser?.photoURL == null || _driverUser!.photoURL!.isEmpty
                          ? Icon(
                              Icons.drive_eta_outlined, // Driver specific icon
                              size: 50,
                              color: Colors.grey.shade700,
                            )
                          : null,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      displayName?.isNotEmpty == true ? displayName! : 'Driver Name',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      email ?? 'driver.email@example.com',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 30),
                    const Divider(),
                    ListTile(
                      leading: Icon(Icons.edit_outlined, color: Theme.of(context).primaryColor),
                      title: const Text('Edit Profile'),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Edit Driver Profile (Not Implemented)')),
                        );
                        // TODO: Navigate to edit driver profile screen
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.history_outlined, color: Theme.of(context).primaryColor),
                      title: const Text('Delivery History'),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Delivery History (Not Implemented)')),
                        );
                        // TODO: Navigate to delivery history screen
                      },
                    ),
                     ListTile(
                      leading: Icon(Icons.settings_outlined, color: Theme.of(context).primaryColor),
                      title: const Text('Settings'),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Driver Settings (Not Implemented)')),
                        );
                        // TODO: Navigate to driver settings screen
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.red),
                      title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
                      onTap: () {
                        _showLogoutBottomSheet(context);
                      },
                    ),
                    const SizedBox(height: 40),
                    Text(
                      'App Version 1.0.0', // Example app version
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 