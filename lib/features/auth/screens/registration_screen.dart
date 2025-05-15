import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animo/core/models/app_user.dart'; // Assuming AppUser and UserRole are here
import 'package:animo/services/firebase_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart'; // For FirebaseException

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
  bool _isRegisterButtonActive = false;
  bool _isPasswordVisible = false; // For password field
  bool _isConfirmPasswordVisible = false; // For confirm password field


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
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuint,
    ));

    _animationController.forward();

    _displayNameController.addListener(_updateRegisterButtonState);
    _emailController.addListener(_updateRegisterButtonState);
    _passwordController.addListener(_updateRegisterButtonState);
    _confirmPasswordController.addListener(_updateRegisterButtonState);
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
      _updateRegisterButtonState();
      return;
    }
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
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e is FirebaseException) {
            _errorMessage = e.message ?? "An unknown Firebase error occurred.";
          } else {
            _errorMessage = e.toString().replaceFirst("Exception: ", "");
          }
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
    final Color fieldFillColor = Colors.grey[200]!;
    final double fieldBorderRadius = 15.0;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      resizeToAvoidBottomInset: false, // Prevent background resize on keyboard
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/register_bg.png"), // Ensure this asset exists
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: <Widget>[
                  // Top section for "Create account" and "Please enter your details"
                  Expanded(
                    child: Container(
                      width: double.infinity, // Ensure it takes full width for CrossAxisAlignment.start
                      padding: const EdgeInsets.symmetric(horizontal: 35.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end, // Align to the bottom of this expanded section
                        crossAxisAlignment: CrossAxisAlignment.start, // Align text to the left
                        children: <Widget>[
                          const Text(
                            'Create account',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Please enter your details',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 24.0), // Space above the sheet
                        ],
                      ),
                    ),
                  ),

                  // Sliding Bottom Sheet for Registration Form
                  SlideTransition(
                    position: _slideAnimation,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        // Adjust maxHeight to ensure top text is always visible.
                        // This might need tuning based on the minimum height needed for the top text.
                        maxHeight: screenHeight * 0.78, // Example: sheet can take up to 78%
                      ),
                      child: Material(
                        color: sheetBackgroundColor,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(30.0)),
                        elevation: 8.0,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(32.0, 32.0, 32.0, 0),
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
                                    contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                                  ),
                                  obscureText: !_isPasswordVisible,
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
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                        color: _hintTextColor,
                                      ),
                                      onPressed: () {
                                        if (mounted) {
                                          setState(() {
                                            _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                                          });
                                        }
                                      },
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                                  ),
                                  obscureText: !_isConfirmPasswordVisible,
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
                                      if (!RegExp(r"^(09|\+639)\d{9}$").hasMatch(value)) { // Example PH validation
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
                                    contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
                                  ),
                                  dropdownColor: sheetBackgroundColor,
                                  items: UserRole.values
                                      .where((role) => role != UserRole.unknown) // Exclude 'unknown' from selectable roles
                                      .map((UserRole role) {
                                    String roleName = role.toString().split('.').last;
                                    roleName = roleName[0].toUpperCase() + roleName.substring(1).replaceAll('_', ' '); // Format role name
                                    return DropdownMenuItem<UserRole>(
                                      value: role,
                                      child: Text(roleName),
                                    );
                                  }).toList(),
                                  onChanged: (UserRole? newValue) {
                                    if (mounted) {
                                      setState(() {
                                        _selectedRole = newValue ?? UserRole.unknown;
                                        _updateRegisterButtonState();
                                      });
                                    }
                                  },
                                  validator: (value) {
                                    if (value == null || value == UserRole.unknown) return 'Please select a role';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 28),

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
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    disabledBackgroundColor: neutralRegisterButtonColor.withOpacity(0.7),
                                  ),
                                  child: const Text("Register"),
                                ),
                                const SizedBox(height: 12),
                                if (_errorMessage != null && _errorMessage!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 14),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Back Button (Positioned on top layer of the Stack)
              Positioned(
                top: 10,
                left: 10,
                child: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, color: Colors.white), // White for better visibility on image
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
