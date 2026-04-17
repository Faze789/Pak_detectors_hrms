import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_viewmodel.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _navigateBasedOnAuthStatus();
  }

  void _setupAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  Future<void> _navigateBasedOnAuthStatus() async {
    // SplashScreen is ONLY shown for the / route now.
    // /apply/{jobId} is handled directly by onGenerateRoute in main.dart
    // so we no longer need any deep-link logic here.
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    final authViewModel = context.read<AuthViewModel>();
    await authViewModel.initialize();
    if (!mounted) return;

    if (authViewModel.isLoggedIn && authViewModel.currentUser != null) {
      final role = authViewModel.currentUser!.role;
      if (role == 'hr') {
        Navigator.of(context).pushReplacementNamed('/hr_dashboard');
      } else {
        Navigator.of(context).pushReplacementNamed('/employee_dashboard');
      }
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _handleContinue() {
    final authViewModel = context.read<AuthViewModel>();
    if (authViewModel.isLoggedIn && authViewModel.currentUser != null) {
      final role = authViewModel.currentUser!.role;
      if (role == 'hr') {
        Navigator.of(context).pushReplacementNamed('/hr_dashboard');
      } else {
        Navigator.of(context).pushReplacementNamed('/employee_dashboard');
      }
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF4F46E5), Color(0xFF3B82F6), Color(0xFF475569)],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // LOGO CARD
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.people_alt_rounded,
                      size: 96,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Text(
                          'HRMS Pro',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Smart Human Resource & Employee Management System',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: const Color(0xFFE0E7FF),
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Attendance • Payroll • Leaves • Employees • Reports',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: const Color(0xFFC7D2FE),
                                fontWeight: FontWeight.w400,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ElevatedButton(
                      onPressed: _handleContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF4F46E5),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 48,
                          vertical: 24,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 12,
                        shadowColor: Colors.black.withOpacity(0.3),
                      ),
                      child: Text(
                        'Tap To Continue',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: const Color(0xFF4F46E5),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
