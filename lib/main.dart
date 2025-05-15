import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animo/services/firebase_auth_service.dart';
// import 'package:animo/core/models/app_user.dart'; // AppUser is used by AuthWrapper, not directly by StreamProvider here anymore
import 'package:animo/core/widgets/auth_wrapper.dart'; // Ensure AuthWrapper is imported
import 'firebase_options.dart'; // Ensure this is uncommented and present
import 'package:animo/features/auth/screens/login_screen.dart';
import 'package:animo/features/auth/screens/landing_screen.dart'; // Import the new LandingScreen
import 'package:animo/features/auth/screens/registration_screen.dart'; // Ensure RegistrationScreen is available for routes if needed
import 'package:animo/services/firestore_service.dart'; // Assuming you have this service
import 'package:animo/theme/theme.dart'; // Your custom theme

Future<void> main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // Uses firebase_options.dart
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize your custom theme
    final customTheme = MaterialTheme(ThemeData.light().textTheme); // Or your custom text theme

    return MultiProvider(
      providers: [
        // Provide FirebaseAuthService so it can be accessed by AuthWrapper
        Provider<FirebaseAuthService>(
          create: (_) => FirebaseAuthService(),
        ),
        // REMOVED: StreamProvider<AppUser?>.value(...)
        // The AuthWrapper now uses StreamBuilder internally to listen to authStateChanges.

        // Provide FirestoreService if it's used elsewhere in the app via Provider
        Provider<FirestoreService>(
          create: (_) => FirestoreService(),
        ),
      ],
      child: MaterialApp(
        title: 'AniMo',
        theme: customTheme.light(), // Light theme
        darkTheme: customTheme.dark(), // Dark theme
        themeMode: ThemeMode.system, // Use system theme setting
        home: const AuthWrapper(), // AuthWrapper handles initial screen logic
        routes: {
          // Define named routes for navigation
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegistrationScreen(),
          '/landing': (context) => const LandingScreen(),
          // You can add other routes for dashboards or specific screens if needed
          // For example:
          // '/farmer_dashboard': (context) => const FarmerDashboardScreen(),
        },
      ),
    );
  }
}

// Screen to show when user role is unknown or not yet determined
// This screen is referenced/used within the AuthWrapper logic if a user has an unknown role.
class UnknownRoleScreen extends StatelessWidget {
  const UnknownRoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account Issue')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
                'Your user role is unknown. Please contact support or try logging in again.'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                // Sign out the user
                await context.read<FirebaseAuthService>().signOut();
                // After signing out, AuthWrapper will rebuild and show the LandingScreen.
                // Explicit navigation might not be needed if AuthWrapper handles it,
                // but can be used as a fallback.
                // Navigator.of(context).pushNamedAndRemoveUntil('/landing', (route) => false);
              },
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
