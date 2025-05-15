import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animo/services/firebase_auth_service.dart';
// import 'package:animo/features/auth/screens/registration_screen.dart'; // No longer navigating to registration from here
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // For FirebaseException

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _rememberMe = false;
  bool _isPasswordVisible = false;
  bool _isLoginButtonActive = false;

  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  final Color _darkTextColor = Colors.black87;
  final Color _hintTextColor = Colors.grey[600]!;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1), // Start off-screen (bottom)
      end: Offset.zero, // End at its natural position
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuint, // Smooth easing curve
    ));

    _animationController.forward(); // Start the animation

    // Add listeners to update login button state dynamically
    _emailController.addListener(_updateLoginButtonState);
    _passwordController.addListener(_updateLoginButtonState);
  }

  void _updateLoginButtonState() {
    // Update the state only if the widget is still in the tree
    if (mounted) {
      setState(() {
        _isLoginButtonActive = _emailController.text.isNotEmpty && _passwordController.text.isNotEmpty;
      });
    }
  }

  Future<void> _loginUser() async {
    // Validate form fields
    if (_formKey.currentState!.validate()) {
      // Update state to show loading indicator
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }
      try {
        // Access FirebaseAuthService using Provider
        final authService = Provider.of<FirebaseAuthService>(context, listen: false);
        // Attempt to sign in
        await authService.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          rememberMe: _rememberMe,
        );
        // If login is successful, AuthWrapper will handle navigation.
        // To ensure AuthWrapper can display the dashboard, pop the LoginScreen.
        if (mounted) {
          // Check if the current route can be popped before calling pop.
          if (Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }
        }
      } catch (e) {
        // Handle errors during login
        if (mounted) {
          setState(() {
            if (e is FirebaseException) {
              // Handle Firebase specific errors
              _errorMessage = e.message ?? "An unknown Firebase error occurred.";
            } else {
              // Handle other exceptions (e.g., custom exceptions from FirebaseAuthService)
              _errorMessage = e.toString().replaceFirst("Exception: ", "");
            }
          });
        }
      } finally {
        // Ensure loading indicator is turned off, regardless of success or failure
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    // Dispose controllers to free up resources
    _animationController.dispose();
    _emailController.removeListener(_updateLoginButtonState);
    _emailController.dispose();
    _passwordController.removeListener(_updateLoginButtonState);
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Define colors and dimensions based on context and theme
    final Color activeLoginButtonColor = Theme.of(context).colorScheme.primary;
    final Color neutralLoginButtonColor = Colors.grey[400]!;
    final Color sheetBackgroundColor = Theme.of(context).colorScheme.surfaceVariant;
    final Color fieldFillColor = Colors.grey[200]!;
    final double fieldBorderRadius = 15.0;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        // Background image
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/login_bg.png"), // Ensure asset exists
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Stack( // Use Stack for layering UI elements
            children: [
              // Back button
              Positioned(
                top: 10,
                left: 10,
                child: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, color: _darkTextColor),
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
              // Logo and Welcome Text Area
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.only(
                      left: 24.0,
                      right: 24.0,
                      bottom: screenHeight * 0.46 // Reserve space for the bottom sheet
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end, // Align to bottom of available space
                    children: [
                      Image.asset(
                        'assets/animo_logo.png', // Ensure asset exists
                        height: 150.0,
                      ),
                      const SizedBox(height: 15.0),
                      Text(
                        'Welcome to AniMo',
                        style: TextStyle(
                          color: _darkTextColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Sliding Bottom Sheet for Login Form
              Align(
                alignment: Alignment.bottomCenter,
                child: SlideTransition(
                  position: _slideAnimation, // Apply slide animation
                  child: Container(
                    padding: const EdgeInsets.all(32.0).copyWith(top: 32.0),
                    decoration: BoxDecoration(
                        color: sheetBackgroundColor,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(30.0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.3),
                            spreadRadius: 2,
                            blurRadius: 10,
                            offset: const Offset(0, -3),
                          ),
                        ]
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min, // Take minimum vertical space
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          // Email Field
                          TextFormField(
                            controller: _emailController,
                            style: TextStyle(color: _darkTextColor),
                            decoration: InputDecoration(
                              hintText: 'Email',
                              hintStyle: TextStyle(color: _hintTextColor),
                              filled: true,
                              fillColor: fieldFillColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(fieldBorderRadius),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Please enter your email';
                              if (!RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(value)) {
                                return 'Please enter a valid email address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          // Password Field
                          TextFormField(
                            controller: _passwordController,
                            style: TextStyle(color: _darkTextColor),
                            decoration: InputDecoration(
                              hintText: 'Password',
                              hintStyle: TextStyle(color: _hintTextColor),
                              filled: true,
                              fillColor: fieldFillColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(fieldBorderRadius),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                  color: _hintTextColor,
                                ),
                                onPressed: () {
                                  if (mounted) {
                                    setState(() {
                                      _isPasswordVisible = !_isPasswordVisible;
                                    });
                                  }
                                },
                              ),
                            ),
                            obscureText: !_isPasswordVisible,
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Please enter your password';
                              if (value.length < 6) return 'Password must be at least 6 characters';
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          // Remember Me Checkbox
                          Row(
                            children: [
                              Checkbox(
                                value: _rememberMe,
                                onChanged: (bool? value) {
                                  if (mounted) {
                                    setState(() {
                                      _rememberMe = value ?? false;
                                    });
                                  }
                                },
                                activeColor: activeLoginButtonColor,
                                checkColor: sheetBackgroundColor, // Or Colors.white for better contrast
                                side: BorderSide(color: _hintTextColor),
                              ),
                              Text(
                                'Remember me',
                                style: TextStyle(color: _darkTextColor.withOpacity(0.8), fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 25),
                          // Login Button or Loading Indicator
                          _isLoading
                              ? Center(child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: CircularProgressIndicator(color: activeLoginButtonColor),
                          ))
                              : ElevatedButton(
                            onPressed: _isLoginButtonActive ? _loginUser : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isLoginButtonActive ? activeLoginButtonColor : neutralLoginButtonColor,
                              foregroundColor: _isLoginButtonActive ? (activeLoginButtonColor.computeLuminance() > 0.5 ? Colors.black : Colors.white) : Colors.white70,
                              padding: const EdgeInsets.symmetric(vertical: 18.0),
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              disabledBackgroundColor: neutralLoginButtonColor.withOpacity(0.7),
                            ),
                            child: const Text("Login"),
                          ),
                          const SizedBox(height: 12),
                          // Error Message Display
                          if (_errorMessage != null && _errorMessage!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          // Adjust bottom spacing for keyboard visibility
                          SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 10 : 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
