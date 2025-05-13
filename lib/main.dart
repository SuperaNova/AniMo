import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animo/services/firebase_auth_service.dart';
import 'package:animo/services/produce_listing_service.dart';
import 'package:animo/core/models/app_user.dart';
import 'package:animo/core/widgets/auth_wrapper.dart';
import 'firebase_options.dart'; // Ensure this is uncommented and present

// Placeholder for actual LoginScreen - will be created in features/auth/screens/
// For AuthWrapper to compile, we need a LoginScreen class, even if it's basic.
import 'package:animo/features/auth/screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  // Make sure you have configured Firebase for your project.
  // If using FlutterFire CLI, you might have a firebase_options.dart file.
  // Otherwise, ensure google-services.json (Android) and GoogleService-Info.plist (iOS) are set up.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // Uncomment if using firebase_options.dart
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<FirebaseAuthService>(create: (_) => FirebaseAuthService()),
        StreamProvider<AppUser?>.value(
          value: FirebaseAuthService().authStateChanges,
          initialData: null, // Important to provide initial data
        ),
        Provider<ProduceListingService>(create: (_) => ProduceListingService()),
        // You can add other services here later, e.g., FirestoreService
      ],
      child: MaterialApp(
        title: 'AniMo Prototype',
        theme: ThemeData(
          primarySwatch: Colors.green,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          // Consider adding a more complete theme later
        ),
        home: const AuthWrapper(), // AuthWrapper now decides the first screen
        // TODO: Setup named routes using a router class (e.g., GoRouter or custom)
        // For example:
        // routes: {
        //   LoginScreen.routeName: (context) => const LoginScreen(),
        //   FarmerDashboardScreen.routeName: (context) => const FarmerDashboardScreen(),
        //   // etc.
        // },
      ),
    );
  }
}

// The InitialSplashScreen and PlaceholderLoginScreen are no longer needed here
// as AuthWrapper and the actual LoginScreen will handle this logic.
