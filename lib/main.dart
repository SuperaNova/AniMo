import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animo/services/firebase_auth_service.dart';
import 'package:animo/services/produce_listing_service.dart'; // Added import
// import 'package:animo/core/models/app_user.dart'; // AppUser is used by AuthWrapper, not directly by StreamProvider here anymore
import 'package:animo/core/widgets/auth_wrapper.dart'; // Ensure AuthWrapper is imported
import 'firebase_options.dart'; // Ensure this is uncommented and present
import 'package:animo/features/auth/screens/login_screen.dart';
import 'package:animo/features/auth/screens/landing_screen.dart'; // Import the new LandingScreen
import 'package:animo/features/auth/screens/registration_screen.dart'; // Ensure RegistrationScreen is available for routes if needed
import 'package:animo/services/firestore_service.dart'; // Assuming you have this service
import 'package:animo/theme/theme.dart'; // Your custom theme
import 'package:flutter/foundation.dart' show kIsWeb;

Future<void> main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // Uses firebase_options.dart
  );

  runApp(const MyApp());
}

// Helper function to wrap any route with the ResponsiveWrapper
Widget wrapRoute(Widget screen) {
  return ResponsiveWrapper(child: screen);
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
        Provider<ProduceListingService>( // Added ProduceListingService
          create: (_) => ProduceListingService(),
        ),
      ],
      child: MaterialApp(
        title: 'AniMo',
        theme: customTheme.light(), // Light theme
        darkTheme: customTheme.dark(), // Dark theme
        themeMode: ThemeMode.system, // Use system theme setting
        
        // Apply the phone frame to the home route
        home: wrapRoute(const AuthWrapper()),
        
        // Use a builder to wrap all routes in the ResponsiveWrapper
        builder: (context, child) {
          // If child is null, just return an empty container
          if (child == null) return Container();
          
          // Skip wrapping if this is a dialog, bottomsheet, or popup
          final modalRoute = ModalRoute.of(context);
          if (modalRoute != null && 
              (modalRoute is PopupRoute || 
              modalRoute.settings.name?.startsWith('_') == true)) {
            return child;
          }
          
          // For normal routes, wrap with responsive container
          return wrapRoute(child);
        },
        
        // Define named routes for navigation without needing to wrap each one
        routes: {
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegistrationScreen(),
          '/landing': (context) => const LandingScreen(),
          // You can add other routes for dashboards or specific screens if needed
        },
      ),
    );
  }
}

/// A wrapper widget that provides fixed dimensions for web platform
/// but allows normal responsiveness on mobile platforms
class ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  final double webWidth;
  final double webHeight;

  const ResponsiveWrapper({
    Key? key,
    required this.child,
    this.webWidth = 390, // iPhone 13 Pro width
    this.webHeight = 844, // iPhone 13 Pro height
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // If running on web, use fixed dimensions with a device frame
    if (kIsWeb) {
      return Align(
        alignment: Alignment(0, -0.35), // More upward alignment
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          physics: const ClampingScrollPhysics(),
          child: Container(
            width: webWidth,
            height: webHeight,
            margin: const EdgeInsets.only(top: 0, bottom: 50), // No top margin, more bottom margin
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(25), // Less rounded, more square corners
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24), // Match outer container
              child: MediaQuery(
                // Override MediaQuery to make the app think it's always running on a fixed size device
                data: MediaQuery.of(context).copyWith(
                  size: Size(webWidth, webHeight),
                  padding: EdgeInsets.zero,
                  viewPadding: EdgeInsets.zero,
                  viewInsets: EdgeInsets.zero,
                  devicePixelRatio: 1.0,
                  textScaleFactor: 1.0, // Ensure text size is consistent
                ),
                child: Center( // Add additional centering
                  child: Stack(
                    children: [
                      // Main app content
                      Positioned.fill(
                        child: child,
                      ),
                      // Home indicator
                      Positioned(
                        bottom: 8,
                        left: (webWidth / 2) - 70, // Precise center calculation
                        child: Container(
                          width: 140,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    
    // For mobile platforms, just return the child directly
    return child;
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
