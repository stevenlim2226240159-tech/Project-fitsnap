import 'package:flutter/material.dart';
import 'package:flutter_fitsnap/screens/sign_in_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToSignIn();
  }

  _navigateToSignIn() async {
    // Menampilkan splash screen selama 3 detik
    await Future.delayed(const Duration(seconds: 3), () {});
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/signin');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color.fromARGB(255, 230, 210, 240),
              const Color.fromARGB(255, 220, 198, 230),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon FitSnap
              Image.asset(
                'assets/FitSnap_icon.png',
                width: 150,
                height: 150,
              ),
              const SizedBox(height: 24),
              // Teks "FitSnap" dengan style
              const Text(
                'FitSnap',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 120, 60, 150),
                ),
              ),
              const SizedBox(height: 12),
              // Subtitle/tagline
              const Text(
                'Your Fitness Journey Starts Here',
                style: TextStyle(
                  fontSize: 14,
                  color: Color.fromARGB(255, 100, 60, 130),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 48),
              // Loading indicator
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color.fromARGB(255, 120, 60, 150),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
