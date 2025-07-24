import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _rippleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rippleAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );

    _startAnimations();
    _checkUserAndNavigate();
  }

  void _startAnimations() {
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _scaleController.forward();
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      _rippleController.repeat();
    });
  }

  Future<void> _checkUserAndNavigate() async {
    // Wait for 2 seconds to show the splash screen
    await Future.delayed(const Duration(seconds: 2));

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userEmail = prefs.getString('email');
      final String? lastDashboard = prefs.getString('last_dashboard');

      if (userEmail != null && userEmail.isNotEmpty) {
        // User is logged in, check last dashboard
        if (lastDashboard == 'admin') {
          Navigator.of(context).pushReplacementNamed('/admin-dashboard');
        } else if (lastDashboard == 'user') {
          Navigator.of(context).pushReplacementNamed('/user-dashboard');
        } else {
          // Default to GetStartedScreen if last_dashboard is not set
          Navigator.of(context).pushReplacementNamed('/get-started');
        }
      } else {
        // No user logged in, go to GetStartedScreen
        Navigator.of(context).pushReplacementNamed('/get-started');
      }
    } catch (e) {
      // Handle any errors and fallback to GetStartedScreen
      debugPrint('Error checking user data: $e');
      Navigator.of(context).pushReplacementNamed('/get-started');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_fadeAnimation, _scaleAnimation, _rippleAnimation]),
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Ripple effect
                for (int i = 0; i < 3; i++)
                  Container(
                    width: 200 + (i * 50) * _rippleAnimation.value,
                    height: 200 + (i * 50) * _rippleAnimation.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(
                          (1 - _rippleAnimation.value) * 0.3,
                        ),
                        width: 2,
                      ),
                    ),
                  ),
                // LBN Text
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: const Text(
                      'LBN',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}