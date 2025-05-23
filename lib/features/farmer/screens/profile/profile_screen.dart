import 'package:animo/features/auth/screens/landing_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../services/firebase_auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<FirebaseAuthService>(context, listen: false);
    final currentUser = authService.currentFirebaseUser;

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: colorScheme.surfaceContainerHighest, // Or another theme color
        elevation: 0,
      ),
      backgroundColor: colorScheme.surface, // Background for the profile content area
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Profile Header Section
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Text(
                      currentUser?.displayName?.isNotEmpty == true
                          ? currentUser!.displayName![0].toUpperCase()
                          : (currentUser?.email?.isNotEmpty == true ? currentUser!.email![0].toUpperCase() : 'U'),
                      style: textTheme.headlineLarge?.copyWith(color: colorScheme.onPrimaryContainer),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    currentUser?.displayName ?? 'Farmer Name',
                    style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentUser?.email ?? 'farmer@example.com',
                    style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),

            // Profile Options (Example)
            _buildProfileOption(
              context,
              icon: Icons.edit_outlined,
              title: 'Edit Profile',
              onTap: () {
                // TODO: Navigate to an Edit Profile Screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Edit Profile tapped (Not implemented yet).')),
                );
              },
            ),
            _buildProfileOption(
              context,
              icon: Icons.settings_outlined,
              title: 'Account Settings',
              onTap: () {
                // TODO: Navigate to Account Settings Screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Account Settings tapped (Not implemented yet).')),
                );
              },
            ),
            _buildProfileOption(
              context,
              icon: Icons.help_outline,
              title: 'Help & Support',
              onTap: () {
                // TODO: Navigate to Help Screen or show help dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Help & Support tapped (Not implemented yet).')),
                );
              },
            ),

            const SizedBox(height: 32),
            // Sign Out Button
            ListTile(
              leading: Icon(Icons.logout, color: colorScheme.error),
              title: Text('Sign Out', style: textTheme.titleMedium?.copyWith(color: colorScheme.error, fontWeight: FontWeight.bold)),
              onTap: () {
                _showLogoutBottomSheet(context, authService);
              },
              tileColor: colorScheme.errorContainer.withOpacity(0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'App Version 1.0.0', // Example version
                style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showLogoutBottomSheet(BuildContext context, FirebaseAuthService authService) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (BuildContext bc) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16.0), // Consistent padding
            child: Wrap(
              children: <Widget>[
                ListTile(
                  title: Text(
                    'Confirm Logout',
                    style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold), // Adjusted style
                  ),
                  subtitle: const Text('Are you sure you want to sign out from your account?'),
                ),
                const Divider(),
                ListTile(
                  leading: Icon(Icons.exit_to_app, color: colorScheme.error),
                  title: Text('Sign Out', style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.bold)),
                  onTap: () async {
                    Navigator.of(context).pop(); // Close the bottom sheet first
                    try {
                      await authService.signOut();
                      if (context.mounted) {
                        // Navigate to LandingScreen (assuming its route is '/')
                        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Error signing out: ${e.toString()}")),
                        );
                      }
                      debugPrint("Error during sign out: $e");
                    }
                  },
                ),
                ListTile(
                  leading: Icon(Icons.cancel_outlined, color: colorScheme.onSurfaceVariant),
                  title: Text('Cancel', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                  onTap: () {
                    Navigator.of(bc).pop(); // Close the bottom sheet (use bc context)
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileOption(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5))
      ),
      child: ListTile(
        leading: Icon(icon, color: colorScheme.primary),
        title: Text(title, style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurface)),
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 18, color: colorScheme.onSurfaceVariant),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      ),
    );
  }
}
