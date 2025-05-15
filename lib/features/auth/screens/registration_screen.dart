import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animo/core/models/app_user.dart'; // Assuming AppUser and UserRole are here
import '../../../services/firebase_auth_service.dart';
// import 'package:firebase_auth/firebase_auth.dart'; // Only if directly handling FirebaseException, FirebaseAuthService might abstract this

class RegistrationScreen extends StatefulWidget {
  static const String routeName = '/register';

  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneNumberController = TextEditingController();

  UserRole _selectedRole = UserRole.unknown;

  bool _isLoading = false;
  String? _errorMessage;
  bool _isRegisterButtonActive = false; // For dynamic button state

  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  // Define colors similar to LoginScreen for consistency
  final Color _darkTextColor = Colors.black87;
  final Color _hintTextColor = Colors.grey[600]!;
  // final Color _fieldFillColor = Colors.grey[200]!; // Defined in build method from theme
  // final double _fieldBorderRadius = 15.0; // Defined in build method

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1), // Start from bottom
      end: Offset.zero, // End at its natural position
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuint,
    ));

    _animationController.forward(); // Start animation

    // Add listeners to update register button state
    _displayNameController.addListener(_updateRegisterButtonState);
    _emailController.addListener(_updateRegisterButtonState);
    _passwordController.addListener(_updateRegisterButtonState);
    _confirmPasswordController.addListener(_updateRegisterButtonState);
    // Phone number is optional, so it doesn't gate the button
    // _selectedRole changes will also call _updateRegisterButtonState
  }

  void _updateRegisterButtonState() {
    if (mounted) {
      setState(() {
        _isRegisterButtonActive = _displayNameController.text.isNotEmpty &&
            _emailController.text.isNotEmpty &&
            _passwordController.text.isNotEmpty &&
            _confirmPasswordController.text.isNotEmpty &&
            _selectedRole != UserRole.unknown;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _displayNameController.removeListener(_updateRegisterButtonState);
    _displayNameController.dispose();
    _emailController.removeListener(_updateRegisterButtonState);
    _emailController.dispose();
    _passwordController.removeListener(_updateRegisterButtonState);
    _passwordController.dispose();
    _confirmPasswordController.removeListener(_updateRegisterButtonState);
    _confirmPasswordController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) {
      // Also, ensure button state reflects this, though validation handles direct submission.
      _updateRegisterButtonState(); // Re-check button state if form is invalid
      return;
    }
    // Redundant check if button is properly disabled, but good for safety.
    if (_selectedRole == UserRole.unknown) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Please select a role.';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final authService = Provider.of<FirebaseAuthService>(context, listen: false);
      await authService.signUpWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        displayName: _displayNameController.text.trim(),
        phoneNumber: _phoneNumberController.text.trim(),
        role: _selectedRole,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful! Please log in.')),
        );
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop(); // Go back (e.g., to LoginScreen)
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst("Exception: ", "");
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color activeRegisterButtonColor = Theme.of(context).colorScheme.primary;
    final Color neutralRegisterButtonColor = Colors.grey[400]!;
    final Color sheetBackgroundColor = Theme.of(context).colorScheme.surfaceVariant;
    final Color fieldFillColor = Colors.grey[200]!; // Consistent with LoginScreen
    final double fieldBorderRadius = 15.0; // Consistent with LoginScreen
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        // Background image like LoginScreen
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/register_bg.png"), // Ensure this asset exists
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Back Button
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
              // Top Text Area
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 35.0,
                    right: 25.0,
                    // Adjust bottom padding to reserve space for the sheet AND some text above it
                    // This needs to be higher than LoginScreen's to fit the text
                    bottom: screenHeight * 0.68, // Example: reserves 70% from bottom for sheet + text area
                    // This might need fine-tuning
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start, // Align text to the left
                    children: [
                      const Text(
                        'Create account',
                        style: TextStyle(
                          color: Colors.black87, // Or use _darkTextColor
                          fontSize: 32, // Larger font for title
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please enter your details',
                        style: TextStyle(
                          color: Colors.black54, // Softer color for subtitle
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Sliding Bottom Sheet for Registration Form
              Align(
                alignment: Alignment.bottomCenter,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Container(
                    // Max height for the sheet to prevent it from covering the top text
                    // when keyboard is open or content is long.
                    constraints: BoxConstraints(
                      maxHeight: screenHeight * 0.75, // Example: sheet can take up to 65% of screen
                    ),
                    padding: const EdgeInsets.fromLTRB(32.0, 32.0, 32.0, 16.0), // Adjusted bottom padding
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
                      ],
                    ),
                    child: SingleChildScrollView( // Make form scrollable within the sheet
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            // Full Name Field
                            TextFormField(
                              controller: _displayNameController,
                              style: TextStyle(color: _darkTextColor),
                              decoration: InputDecoration(
                                hintText: 'Full Name',
                                hintStyle: TextStyle(color: _hintTextColor),
                                filled: true,
                                fillColor: fieldFillColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(fieldBorderRadius),
                                  borderSide: BorderSide.none,
                                ),
                                prefixIcon: Icon(Icons.person_outline, color: _hintTextColor),
                                contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Please enter your full name';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Email Field
                            TextFormField(
                              controller: _emailController,
                              style: TextStyle(color: _darkTextColor),
                              decoration: InputDecoration(
                                hintText: 'Email Address',
                                hintStyle: TextStyle(color: _hintTextColor),
                                filled: true,
                                fillColor: fieldFillColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(fieldBorderRadius),
                                  borderSide: BorderSide.none,
                                ),
                                prefixIcon: Icon(Icons.email_outlined, color: _hintTextColor),
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
                            const SizedBox(height: 16),

                            // Password Field
                            TextFormField(
                              controller: _passwordController,
                              style: TextStyle(color: _darkTextColor),
                              decoration: InputDecoration(
                                hintText: 'Password (min. 6 characters)',
                                hintStyle: TextStyle(color: _hintTextColor),
                                filled: true,
                                fillColor: fieldFillColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(fieldBorderRadius),
                                  borderSide: BorderSide.none,
                                ),
                                prefixIcon: Icon(Icons.lock_outline, color: _hintTextColor),
                                contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                                // Add suffix icon for password visibility if needed
                              ),
                              obscureText: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Please enter a password';
                                if (value.length < 6) return 'Password must be at least 6 characters';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Confirm Password Field
                            TextFormField(
                              controller: _confirmPasswordController,
                              style: TextStyle(color: _darkTextColor),
                              decoration: InputDecoration(
                                hintText: 'Confirm Password',
                                hintStyle: TextStyle(color: _hintTextColor),
                                filled: true,
                                fillColor: fieldFillColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(fieldBorderRadius),
                                  borderSide: BorderSide.none,
                                ),
                                prefixIcon: Icon(Icons.lock_person_outlined, color: _hintTextColor),
                                contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                              ),
                              obscureText: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Please confirm your password';
                                if (value != _passwordController.text) return 'Passwords do not match';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Phone Number Field
                            TextFormField(
                              controller: _phoneNumberController,
                              style: TextStyle(color: _darkTextColor),
                              decoration: InputDecoration(
                                hintText: 'Phone Number (Optional)',
                                hintStyle: TextStyle(color: _hintTextColor),
                                filled: true,
                                fillColor: fieldFillColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(fieldBorderRadius),
                                  borderSide: BorderSide.none,
                                ),
                                prefixIcon: Icon(Icons.phone_outlined, color: _hintTextColor),
                                contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (value) {
                                if (value != null && value.isNotEmpty) {
                                  if (!RegExp(r"^(09|\+639)\d{9}$").hasMatch(value)) {
                                    return 'Enter a valid PH phone number';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Role Selection Dropdown
                            DropdownButtonFormField<UserRole>(
                              value: _selectedRole == UserRole.unknown ? null : _selectedRole,
                              hint: Text('Select Your Role', style: TextStyle(color: _hintTextColor)),
                              isExpanded: true,
                              style: TextStyle(color: _darkTextColor),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: fieldFillColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(fieldBorderRadius),
                                  borderSide: BorderSide.none,
                                ),
                                prefixIcon: Icon(Icons.category_outlined, color: _hintTextColor),
                                contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10), // Adjusted for prefix
                              ),
                              dropdownColor: sheetBackgroundColor, // Match sheet background
                              items: UserRole.values
                                  .where((role) => role != UserRole.unknown)
                                  .map((UserRole role) {
                                String roleName = role.toString().split('.').last;
                                roleName = roleName[0].toUpperCase() + roleName.substring(1);
                                return DropdownMenuItem<UserRole>(
                                  value: role,
                                  child: Text(roleName),
                                );
                              }).toList(),
                              onChanged: (UserRole? newValue) {
                                if (mounted) {
                                  setState(() {
                                    _selectedRole = newValue ?? UserRole.unknown;
                                    _updateRegisterButtonState(); // Update button state on role change
                                  });
                                }
                              },
                              validator: (value) {
                                if (value == null || value == UserRole.unknown) return 'Please select a role';
                                return null;
                              },
                            ),
                            const SizedBox(height: 28),

                            // Loading Indicator or Register Button
                            _isLoading
                                ? Center(child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              child: CircularProgressIndicator(color: activeRegisterButtonColor),
                            ))
                                : ElevatedButton(
                              onPressed: _isRegisterButtonActive ? _registerUser : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isRegisterButtonActive ? activeRegisterButtonColor : neutralRegisterButtonColor,
                                foregroundColor: _isRegisterButtonActive ? (activeRegisterButtonColor.computeLuminance() > 0.5 ? Colors.black : Colors.white) : Colors.white70,
                                padding: const EdgeInsets.symmetric(vertical: 18.0),
                                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30), // Match LoginScreen button
                                ),
                                disabledBackgroundColor: neutralRegisterButtonColor.withOpacity(0.7),
                              ),
                              child: const Text("Register"),
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
                            // Adjust for keyboard
                            SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 10 : 20),
                          ],
                        ),
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
