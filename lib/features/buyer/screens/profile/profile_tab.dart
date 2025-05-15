import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:animo/services/firebase_auth_service.dart';
// import 'package:animo/screens/login_screen.dart'; // Assuming you have a LoginScreen and its routeName

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  void _showLogoutBottomSheet(BuildContext context) {
    final authService = Provider.of<FirebaseAuthService>(context, listen: false);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder( // Optional: for rounded corners
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (BuildContext bc) {
        return SafeArea( // Ensures content is not obscured by system UI
          child: Container(
            padding: const EdgeInsets.all(16.0),
            child: Wrap( // Use Wrap for content that might vary in height
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
                    Navigator.of(context).pop(); // Close the bottom sheet first
                    await authService.signOut();
                    // Ensure you have a LoginScreen and its routeName defined
                    // And that your navigation setup allows pushing to it after clearing stack
                    // For example:
                    // Navigator.of(context).pushNamedAndRemoveUntil(LoginScreen.routeName, (Route<dynamic> route) => false);
                    // Or if LoginScreen is your initial route after auth state changes:
                    // The app should automatically redirect via a StreamBuilder listening to auth state.
                    if (context.mounted) {
                      // Example: Navigate to a placeholder or initial route if LoginScreen isn't set up for auto-redirect
                      // Navigator.of(context).pushNamedAndRemoveUntil('/auth-wrapper', (route) => false);
                      // For now, just show a snackbar as a placeholder for navigation
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Successfully logged out. Please restart or navigate to login.')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cancel_outlined),
                  title: const Text('Cancel'),
                  onTap: () {
                    Navigator.of(context).pop(); // Close the bottom sheet
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
    final firebaseUser = FirebaseAuth.instance.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Center( // Center the content within the tab
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start, // Align content to the start
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20), // Add some space at the top
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey.shade300,
              child: Icon(
                Icons.person_outline,
                size: 50,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              firebaseUser?.displayName?.isNotEmpty == true
                  ? firebaseUser!.displayName!
                  : 'Buyer Name', // Placeholder if no display name
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              firebaseUser?.email ?? 'buyer.email@example.com', // Placeholder if no email
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
                  const SnackBar(content: Text('Edit Profile screen (Not Implemented)')),
                );
                // TODO: Navigate to edit profile screen
              },
            ),
            ListTile(
              leading: Icon(Icons.settings_outlined, color: Theme.of(context).primaryColor),
              title: const Text('Settings'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings screen (Not Implemented)')),
                );
                // TODO: Navigate to settings screen
              },
            ),
            ListTile(
              leading: Icon(Icons.history_outlined, color: Theme.of(context).primaryColor),
              title: const Text('Order History'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Order History screen (Not Implemented)')),
                );
                // TODO: Navigate to order history
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
    );
  }
}