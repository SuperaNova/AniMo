import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../services/firebase_auth_service.dart';

class ProfileTabContent extends StatelessWidget {
  const ProfileTabContent({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<FirebaseAuthService>(context, listen: false);
    // Replace with your actual screen content for "Profile"
    // This might display user information, settings, logout button, etc.
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Profile Screen for ${authService.currentFirebaseUser?.displayName ?? "Farmer"}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              await authService.signOut();
              // Navigate to login screen, typically handled by a top-level auth state listener
            },
            child: const Text('Sign Out'),
          )
        ],
      ),
    );
  }
}
