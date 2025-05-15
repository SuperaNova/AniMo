import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animo/services/firebase_auth_service.dart';
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

    _emailController.addListener(_updateLoginButtonState);
    _passwordController.addListener(_updateLoginButtonState);
  }

  void _updateLoginButtonState() {
    if (mounted) {
      setState(() {
        _isLoginButtonActive = _emailController.text.isNotEmpty && _passwordController.text.isNotEmpty;
      });
    }
  }

  Future<void> _loginUser() async {
    if (_formKey.currentState!.validate()) {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }
      try {
        final authService = Provider.of<FirebaseAuthService>(context, listen: false);
        await authService.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          rememberMe: _rememberMe,
        );
        if (mounted) {
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.removeListener(_updateLoginButtonState);
    _emailController.dispose();
    _passwordController.removeListener(_updateLoginButtonState);
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color activeLoginButtonColor = Theme.of(context).colorScheme.primary;
    final Color neutralLoginButtonColor = Colors.grey[400]!;
    final Color sheetBackgroundColor = Theme.of(context).colorScheme.surfaceVariant;
    final Color fieldFillColor = Colors.grey[200]!;
    final double fieldBorderRadius = 15.0;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/login_bg.png"), // Ensure asset exists
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: <Widget>[
                  // Top section for Logo and Welcome Text
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end, // Align content to the bottom of this expanded section
                        children: <Widget>[
                          Image.asset(
                            'assets/animo_full_logo.png',
                            height: screenHeight * 0.15, // Adjusted for better proportion
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 16.0),
                          Text(
                            'Welcome to AniMo',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSecondaryFixedVariant,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    blurRadius: 2.0,
                                    color: Colors.black.withOpacity(0.3),
                                    offset: const Offset(1.0, 1.0),
                                  ),
                                ]
                            ),
                          ),
                          const SizedBox(height: 24.0), // Space above the sheet
                        ],
                      ),
                    ),
                  ),

                  // Sliding Bottom Sheet for Login Form
                  SlideTransition(
                    position: _slideAnimation,
                    child: ConstrainedBox( // Constrain the max height of the sheet
                      constraints: BoxConstraints(
                        maxHeight: screenHeight * 0.65, // Sheet can take up to 65% of screen height
                        // Adjust this value as needed for your content
                      ),
                      child: Material(
                        color: sheetBackgroundColor,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(30.0)),
                        elevation: 8.0,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(32.0, 32.0, 32.0, 0), // Adjust bottom padding here
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
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
                                      checkColor: sheetBackgroundColor,
                                      side: BorderSide(color: _hintTextColor),
                                    ),
                                    Text(
                                      'Remember me',
                                      style: TextStyle(color: _darkTextColor.withOpacity(0.8), fontSize: 14),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 25),
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
                                if (_errorMessage != null && _errorMessage!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 14),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                // This SizedBox helps push content up when keyboard appears
                                // It's inside the SingleChildScrollView, so it adds to scrollable content
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
              Positioned(
                top: 10,
                left: 10,
                child: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, color: Colors.black),
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