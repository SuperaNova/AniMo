import 'package:firebase_auth/firebase_auth.dart' as fb_auth; // Aliased to avoid conflict if we have our own User model
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animo/core/models/app_user.dart'; // Assuming this path from our previous structure

class FirebaseAuthService {
  final fb_auth.FirebaseAuth _firebaseAuth = fb_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream to listen to authentication state changes
  Stream<AppUser?> get authStateChanges {
    return _firebaseAuth.authStateChanges().asyncMap((fb_auth.User? firebaseUser) async {
      if (firebaseUser == null) {
        return null;
      }
      // Fetch AppUser data from Firestore
      DocumentSnapshot<Map<String, dynamic>> userDoc = await _firestore.collection('users').doc(firebaseUser.uid).get();
      
      // If user document doesn't exist on first try, wait a bit and try again.
      // This can help with Firestore propagation delays immediately after sign-up.
      if (!userDoc.exists) {
        await Future.delayed(const Duration(milliseconds: 500)); // Small delay
        userDoc = await _firestore.collection('users').doc(firebaseUser.uid).get(); // Retry fetch
      }

      if (userDoc.exists && userDoc.data() != null) {
        return AppUser.fromFirestore(userDoc.data()!, userDoc.id);
      } else {
        // This case might happen if user data wasn't created in Firestore,
        // or if it's a new sign-up that hasn't completed profile creation.
        // For now, return a minimal AppUser or handle as an error/incomplete profile.
        print("Warning: User document not found in Firestore for UID: ${firebaseUser.uid}");
        // Fallback to creating a temporary AppUser object from Firebase Auth data only
        // This is NOT ideal for role-based access but prevents a null return for an authenticated user.
        // The proper flow should ensure the 'users' document is created upon registration.
        return AppUser(
          uid: firebaseUser.uid,
          email: firebaseUser.email,
          displayName: firebaseUser.displayName,
          photoURL: firebaseUser.photoURL,
          role: UserRole.unknown, // Role should be set during registration and stored in Firestore
          registrationDate: firebaseUser.metadata.creationTime,
        );
      }
    });
  }

  // Get current Firebase User (lightweight, from Auth SDK directly)
  fb_auth.User? get currentFirebaseUser => _firebaseAuth.currentUser;

  // Get current AppUser (with data from Firestore)
  Future<AppUser?> getCurrentAppUser() async {
    final fbUser = _firebaseAuth.currentUser;
    if (fbUser == null) return null;
    try {
      final userDoc = await _firestore.collection('users').doc(fbUser.uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        return AppUser.fromFirestore(userDoc.data()!, userDoc.id);
      }
    } catch (e) {
      print("Error fetching AppUser: $e");
    }
    return null; // Or handle error as appropriate
  }


  // Sign up with email and password
  Future<AppUser?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    String? phoneNumber, // Optional
  }) async {
    try {
      final fb_auth.UserCredential userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final fb_auth.User? firebaseUser = userCredential.user;
      if (firebaseUser != null) {
        // Update display name in Firebase Auth
        await firebaseUser.updateDisplayName(displayName);
        // Consider sending a verification email
        // await firebaseUser.sendEmailVerification();

        // Create our AppUser model
        final newAppUser = AppUser(
          uid: firebaseUser.uid,
          email: firebaseUser.email,
          displayName: displayName,
          phoneNumber: phoneNumber,
          photoURL: firebaseUser.photoURL, // Initially null or from provider data
          role: role,
          registrationDate: DateTime.now(),
        );

        // Store user data in Firestore in the 'users' collection
        await _firestore.collection('users').doc(newAppUser.uid).set(newAppUser.toFirestore());
        
        return newAppUser;
      }
      return null;
    } on fb_auth.FirebaseAuthException catch (e) {
      // Handle specific Firebase Auth exceptions (e.g., email-already-in-use)
      print("FirebaseAuthException on Sign Up: ${e.message} (Code: ${e.code})");
      throw Exception("Sign up failed: ${e.message}"); // Rethrow or return custom error
    } catch (e) {
      print("Error on Sign Up: $e");
      throw Exception("An unexpected error occurred during sign up.");
    }
  }

  // Sign in with email and password
  Future<AppUser?> signInWithEmailAndPassword({
    required String email,
    required String password,
    bool rememberMe = false, // rememberMe parameter is now effectively unused here for mobile
  }) async {
    try {
      final fb_auth.UserCredential userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final fb_auth.User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        // Fetch full AppUser data from Firestore
        final userDoc = await _firestore.collection('users').doc(firebaseUser.uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          return AppUser.fromFirestore(userDoc.data()!, userDoc.id);
        } else {
           print("Error: User signed in but Firestore document missing for UID: ${firebaseUser.uid}");
           throw Exception("User data not found. Please contact support.");
        }
      }
      return null;
    } on fb_auth.FirebaseAuthException catch (e) {
      print("FirebaseAuthException on Sign In: ${e.message} (Code: ${e.code})");
      throw Exception("Sign in failed: ${e.message}");
    } catch (e) {
      print("Error on Sign In: $e");
      throw Exception("An unexpected error occurred during sign in.");
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      print("Error on Sign Out: $e");
      // Optionally handle errors, though signOut rarely fails critically
    }
  }

  // TODO: Implement other auth methods if needed (Phone Auth, Google Sign-In etc.)
  // Future<AppUser?> signInWithGoogle() async { ... }
  // Future<void> signInWithPhoneNumber(String phoneNumber, ...) async { ... }
  // Future<AppUser?> verifyPhoneNumberOTP(String verificationId, String smsCode) async { ... }

} 