import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animo/core/models/app_user.dart';
import 'package:animo/features/auth/screens/login_screen.dart';
import 'package:animo/features/auth/screens/landing_screen.dart'; // Make sure LandingScreen is imported
import 'package:animo/features/farmer/screens/farmer_dashboard_screen.dart';
import 'package:animo/features/buyer/screens/buyer_dashboard_screen.dart';
import 'package:animo/features/driver/screens/driver_dashboard_screen.dart';
import 'package:animo/services/firebase_auth_service.dart'; // Added for logout in error case

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to the AppUser stream provided by StreamProvider
    final appUser = Provider.of<AppUser?>(context);

    if (appUser == null) {
      // If user is not logged in, show LandingScreen first
      return const LandingScreen(); // Changed from LoginScreen
    } else {
      // If user is logged in, determine their role and show the appropriate dashboard
      switch (appUser.role) {
        case UserRole.farmer:
          return const FarmerDashboardScreen();
        case UserRole.buyer:
          return const BuyerDashboardScreen();
        case UserRole.driver:
          return const DriverDashboardScreen();
        case UserRole.unknown:
        default:
          // Handle unknown role: show an error, a role selection screen, or default to login
          print("Unknown user role: ${appUser.role}, uid: ${appUser.uid}");
          // For MVP, might be best to log them out or show a generic error/profile completion page
          return Scaffold(
            appBar: AppBar(title: const Text("Role Error")),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Could not determine user role or role is unknown."),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      // Attempt to log out the user
                      Provider.of<FirebaseAuthService>(context, listen: false).signOut();
                    },
                    child: const Text("Logout"),
                  )
                ],
              ),
            ),
          );
      }
    }
  }
} 