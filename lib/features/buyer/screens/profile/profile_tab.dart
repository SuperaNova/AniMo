import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:animo/services/firebase_auth_service.dart'; // For logout

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    // final authService = Provider.of<FirebaseAuthService>(context, listen: false); // If logout is moved here

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const CircleAvatar(
            radius: 50,
            child: Icon(Icons.person, size: 50),
          ),
          const SizedBox(height: 20),
          Text(
            firebaseUser?.displayName?.isNotEmpty == true
                ? firebaseUser!.displayName!
                : 'Buyer',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            firebaseUser?.email ?? 'No email associated',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 30),
          // Add more profile options here like:
          // ListTile(
          //   leading: Icon(Icons.edit),
          //   title: Text('Edit Profile'),
          //   onTap: () { /* Navigate to edit profile screen */ },
          // ),
          // ListTile(
          //   leading: Icon(Icons.settings),
          //   title: Text('Settings'),
          //   onTap: () { /* Navigate to settings screen */ },
          // ),
          // ListTile(
          //   leading: Icon(Icons.history),
          //   title: Text('Order History'),
          //   onTap: () { /* Navigate to order history */ },
          // ),
          // const Divider(),
          // ListTile(
          //   leading: Icon(Icons.logout, color: Colors.red),
          //   title: Text('Logout', style: TextStyle(color: Colors.red)),
          //   onTap: () async {
          //     await authService.signOut();
          //     // Navigator.of(context).pushNamedAndRemoveUntil(LoginScreen.routeName, (Route<dynamic> route) => false);
          //   },
          // ),
          const SizedBox(height: 40),
          const Text(
            'Profile section is under development.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}