import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'registration_screen.dart'; // Assuming registration_screen.dart is in the same directory

// Helper function for creating a slide transition (slide in from left, slide out to right)
Route _createSlideTransitionRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Slide in from the left
      const beginIn = Offset(1.0, 0.0); // Start from right, slide to left
      // Slide out to the right (when popping)
      const endOut = Offset(1.0, 0.0);   // End to right, slide from left

      var curve = Curves.easeInOutCubic; // Smoother transition curve

      // Tween for forward animation (pushing the new screen)
      var tweenIn = Tween(begin: beginIn, end: Offset.zero).chain(CurveTween(curve: curve));
      // Tween for reverse animation (popping the current screen)
      var tweenOut = Tween(begin: Offset.zero, end: endOut).chain(CurveTween(curve: curve));

      // Use SlideTransition for both primary and secondary animations
      // Primary animation is for the screen being pushed/popped
      // Secondary animation is for the screen underneath
      
      // When pushing a new screen (forward animation):
      // The new screen slides in (controlled by `animation`)
      // The old screen slides out (controlled by `secondaryAnimation` but with opposite direction)
      
      // When popping a screen (reverse animation of `animation`):
      // The current screen slides out (controlled by `animation` in reverse)
      // The screen below slides in (controlled by `secondaryAnimation` in reverse, but with opposite direction)

      // For slide in from left, new screen moves from right (1.0) to center (0.0)
      // For slide out to right, current screen moves from center (0.0) to right (1.0)
      
      // Let's adjust to have the new screen slide from the *right* and exit to the *right*
      // And the old screen slide to the *left* and enter from the *left*

      final inAnimation = animation.drive(tweenIn);
      // For the screen going out, we want it to slide to the left
      final outAnimation = secondaryAnimation.drive(Tween(begin: Offset.zero, end: const Offset(-0.3, 0.0)).chain(CurveTween(curve: curve)));


      // If you want new screen to slide from left, use Offset(-1.0, 0.0) for beginIn
      // Let's stick to new screen from right, old screen to left for typical forward navigation
      // And reverse for pop.

      // New screen slides from right to left (Offset(1.0, 0.0) to Offset.zero)
      // Old screen slides from center to left (Offset.zero to Offset(-1.0, 0.0))
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0), // New screen comes from the right
          end: Offset.zero,
        ).animate(animation),
        child: child,
      );

    },
    transitionDuration: const Duration(milliseconds: 300), // Adjust duration as needed
    reverseTransitionDuration: const Duration(milliseconds: 300), // For pop
  );
}

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand, // Make stack children expand to fill the screen
        children: <Widget>[
          // Background Image
          Image.asset(
            'assets/landing_bg.png', // Changed from landing_bg.jpg
            fit: BoxFit.cover,
          ),
          // Buttons Area
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0).copyWith(bottom: MediaQuery.of(context).padding.bottom + 30), // Padding from sides and bottom (respecting safe area)
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end, // Align buttons to the bottom
              crossAxisAlignment: CrossAxisAlignment.stretch, // Make buttons stretch to padding boundaries
              children: <Widget>[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C2C2C), // Dark button color from image
                    foregroundColor: Colors.white, // White text
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0), // Pill shape
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      _createSlideTransitionRoute(const LoginScreen()),
                    );
                  },
                  child: const Text('Log In'), // Corrected text
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFF7F5), // Very light pinkish/off-white from image
                    foregroundColor: const Color(0xFF2C2C2C), // Dark text
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0), // Pill shape
                    ),
                     // Optional: add a subtle border if it matches the design
                    // side: BorderSide(color: Colors.grey[300]!, width: 1),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      _createSlideTransitionRoute(const RegistrationScreen()),
                    );
                  },
                  child: const Text('Sign Up'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 