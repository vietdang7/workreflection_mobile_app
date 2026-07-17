import 'package:flutter/material.dart';
import '../../core/theme/wr_colors.dart';

/// Shown briefly while the router evaluates session + onboarding state.
/// The GoRouter redirect fires immediately and replaces this screen.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: WrColors.navy,
      body: Center(
        child: CircularProgressIndicator(
          color: WrColors.white,
        ),
      ),
    );
  }
}
