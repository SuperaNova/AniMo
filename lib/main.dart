import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animo/services/firebase_auth_service.dart';
import 'package:animo/core/models/app_user.dart';
// import 'package:animo/core/widgets/auth_wrapper.dart'; // AuthWrapper will be used after landing/login
import 'firebase_options.dart'; // Ensure this is uncommented and present
import 'package:animo/features/auth/screens/login_screen.dart';
import 'package:animo/features/auth/screens/landing_screen.dart'; // Import the new LandingScreen
import 'package:animo/features/auth/screens/registration_screen.dart'; // Ensure RegistrationScreen is available for routes if needed
import 'package:animo/services/firestore_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  // Make sure you have configured Firebase for your project.
  // If using FlutterFire CLI, you might have a firebase_options.dart file.
  // Otherwise, ensure google-services.json (Android) and GoogleService-Info.plist (iOS) are set up.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // Ensure this line is correct
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<FirebaseAuthService>(
          create: (_) => FirebaseAuthService(),
        ),
        StreamProvider<AppUser?>.value(
          value: FirebaseAuthService().authStateChanges,
          initialData: null,
        ),
        Provider<FirestoreService>(
          create: (_) => FirestoreService(),
        ),
      ],
      child: MaterialApp(
        title: 'AniMo',
        theme: ThemeData(
          primarySwatch: Colors.green,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          // Consider adding a more complete theme later
        ),
        home: const LandingScreen(), // Set LandingScreen as the initial screen
        routes: {
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegistrationScreen(), // Add route for registration
          // '/': (context) => const LandingScreen(), // Optionally, define root route
          // Define other routes as needed
        },
      ),
    );
  }
}

// Screen to show when user role is unknown or not yet determined
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
                'Your user role is unknown. Please contact support.'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await context.read<FirebaseAuthService>().signOut();
                // Optionally navigate to login screen if not handled by AuthWrapper
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/login', (route) => false);
              },
              child: const Text('Logout and Contact Support'),
            ),
          ],
        ),
      ),
    );
  }
}

// The InitialSplashScreen and PlaceholderLoginScreen are no longer needed here
// as AuthWrapper and the actual LoginScreen will handle this logic.
