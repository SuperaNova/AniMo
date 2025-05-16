import 'package:firebase_auth/firebase_auth.dart' as fb_auth; // Aliased to avoid conflict if we have our own User model
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animo/core/models/app_user.dart'; // Assuming this path from our previous structure

/// Service to handle Firebase authentication operations.
///
/// Manages user authentication including sign-up, sign-in, and sign-out.
/// Also handles fetching user data from Firestore and mapping between
/// Firebase Auth models and app-specific user models.
class FirebaseAuthService {
  final fb_auth.FirebaseAuth _firebaseAuth = fb_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream of authentication state changes.
  ///
  /// Returns a stream of [AppUser] objects representing the current user's
  /// authentication state. When user signs in, the stream emits an [AppUser].
  /// When user signs out, the stream emits null.
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

  /// The current Firebase user if authenticated, or null if not.
  ///
  /// This is a lightweight accessor that only returns the Firebase Auth user
  /// without fetching the full user profile from Firestore.
  fb_auth.User? get currentFirebaseUser => _firebaseAuth.currentUser;

  /// Gets the current app user with full profile data.
  ///
  /// Fetches the current user's complete profile information from Firestore.
  /// Returns null if user is not authenticated or if Firestore data can't be retrieved.
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


  /// Creates a new user account with email and password.
  ///
  /// Registers a new user in Firebase Auth and creates a corresponding user
  /// document in Firestore with additional profile information.
  ///
  /// The [email] and [password] are used for authentication.
  /// The [displayName] is saved to the user profile.
  /// The [role] determines the user's permissions in the app.
  /// The optional [phoneNumber] is saved to the user profile if provided.
  ///
  /// Returns the newly created [AppUser] if successful, or null if registration fails.
  /// Throws an exception with details about the failure reason.
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

  /// Signs in a user with email and password.
  ///
  /// Authenticates the user with Firebase Auth and fetches their full profile
  /// from Firestore.
  ///
  /// The [email] and [password] are used for authentication.
  /// The [rememberMe] parameter is not used for mobile platforms.
  ///
  /// Returns the authenticated [AppUser] if successful, or null if sign-in fails.
  /// Throws an exception with details about the failure reason.
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

  /// Signs out the current user.
  ///
  /// Ends the current user's session and clears authentication state.
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