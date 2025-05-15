import 'package:animo/features/farmer/screens/farmer_dashboard_overhaul.dart';
import 'package:animo/features/farmer/screens/farmer_main.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animo/core/models/app_user.dart'; // Your AppUser model
import 'package:animo/services/firebase_auth_service.dart'; // Your AuthService
import 'package:animo/features/auth/screens/landing_screen.dart';
import 'package:animo/features/farmer/screens/farmer_dashboard_screen.dart';
import 'package:animo/features/buyer/screens/buyer_dashboard_screen.dart';
import 'package:animo/features/driver/screens/driver_dashboard_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the FirebaseAuthService instance.
    // This assumes FirebaseAuthService is provided above AuthWrapper in the widget tree.
    final authService = Provider.of<FirebaseAuthService>(context, listen: false);

    return StreamBuilder<AppUser?>(
      // Listen directly to the authStateChanges stream from your service
      stream: authService.authStateChanges,
      builder: (BuildContext context, AsyncSnapshot<AppUser?> snapshot) {
        // Print statements for debugging the stream's state and data
        print("AuthWrapper StreamBuilder: ConnectionState: ${snapshot.connectionState}");
        if (snapshot.hasData) {
          print("AuthWrapper StreamBuilder: HasData: AppUser UID: ${snapshot.data?.uid}, Role: ${snapshot.data?.role}");
        }
        if (snapshot.hasError) {
          print("AuthWrapper StreamBuilder: HasError: ${snapshot.error}");
        }

        // Check the connection state of the stream
        if (snapshot.connectionState == ConnectionState.waiting) {
          // While waiting for the first emission (Firebase + Firestore fetch),
          // show a loading indicator. This prevents the flicker of LandingScreen.
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                // You can style your CircularProgressIndicator or use a custom loading widget
                // key: ValueKey("AuthWrapperLoadingIndicator"), // Optional key for testing
              ),
            ),
          );
        }

        // Once the stream has emitted data or an error
        if (snapshot.hasError) {
          // Handle any errors from the stream (e.g., critical Firestore issues)
          // You might want to show an error screen or default to LandingScreen
          return Scaffold(
            body: Center(
              child: Text("Error loading user data: ${snapshot.error}. Please restart the app."),
            ),
          );
        }

        // snapshot.data will contain the AppUser? object from your stream
        final AppUser? appUser = snapshot.data;

        if (appUser == null) {
          // User is definitively logged out OR an error occurred that resulted in a null AppUser
          // (and wasn't caught by snapshot.hasError, though your stream logic tries to return a fallback AppUser)
          return const LandingScreen();
        } else {
          // User is logged in, determine their role and show the appropriate dashboard
          switch (appUser.role) {
            case UserRole.farmer:
              return const FarmerMainScreen();
            case UserRole.buyer:
              return const BuyerDashboardScreen();
            case UserRole.driver:
              return const DriverDashboardScreen();
            case UserRole.unknown:
            default:
            // This case handles users whose role is 'unknown' or not explicitly matched.
              print("AuthWrapper: Unknown user role encountered: ${appUser.role}, for UID: ${appUser.uid}");
              // It's important that your authStateChanges stream doesn't emit UserRole.unknown
              // for a genuinely logged-in user if it can be avoided (e.g., by ensuring Firestore data is consistent).
              return Scaffold(
                appBar: AppBar(title: const Text("Access Error")),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Your user role could not be determined or is not recognized."),
                      const SizedBox(height: 10),
                      Text("UID: ${appUser.uid}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      Text("Reported Role: ${appUser.role}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          // Attempt to log out the user
                          authService.signOut();
                        },
                        child: const Text("Logout and Try Again"),
                      )
                    ],
                  ),
                ),
              );
          }
        }
      },
    );
  }
}