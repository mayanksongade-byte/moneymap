import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/routes/app_routes.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors_extension.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _scale;
  late Animation<double> _glow;
  late Animation<double> _loadingSweep;
  late Animation<double> _exitFade;

  @override
  void initState() {
    super.initState();

    // Total animation sequence duration: 2.8 seconds
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    // PHASE 1: FADE IN (0 - 500ms)
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.18, curve: Curves.easeOutCubic),
      ),
    );

    // PHASE 2: SCALE ENTRANCE (200 - 900ms)
    _scale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.07, 0.32, curve: Curves.easeOutQuart),
      ),
    );

    // PHASE 3: SUBTLE SETTLE & GLOW (900 - 1600ms)
    _glow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.32, 0.57, curve: Curves.easeInOutSine),
      ),
    );

    // PHASE 4: LOADING SWEEP (1000 - 2400ms)
    _loadingSweep = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.85, curve: Curves.easeInOutSine),
      ),
    );

    // PHASE 5: EXIT TRANSITION (2000 - 2600ms)
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.71, 0.93, curve: Curves.easeInCubic),
      ),
    );

    // Start animation and navigate upon completion
    _controller.forward().then((_) => _navigateToNext());
  }

  void _navigateToNext() {
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      context.go(AppRoutes.home);
    } else {
      context.go(AppRoutes.onboarding);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Theme-aware palette using AppColorsExtension
    final themeColors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Primary brand color for glow (stays consistent)
    const Color royalBlue = Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: themeColors.background,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _exitFade.value,
              child: Stack(
                children: [
                  // Main Logo Focus
                  Center(
                    child: FadeTransition(
                      opacity: _fadeIn,
                      child: ScaleTransition(
                        scale: _scale,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // BACKGROUND GLOW: Theme-adaptive subtle light effect
                            Opacity(
                              opacity: _glow.value * (isDark ? 0.15 : 0.08), 
                              child: Container(
                                width: 320,
                                height: 320,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: royalBlue.withAlpha(isDark ? 120 : 80),
                                      blurRadius: 60,
                                      spreadRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            // MONEYMAP LOGO
                            Image.asset(
                              'assets/images/Lable_Logo/Lable.png',
                              width: 250, 
                              height: 250,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 140,
                                color: themeColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // BRAND TEXT & LOADING INDICATOR
                  Positioned(
                    bottom: 80,
                    left: 0,
                    right: 0,
                    child: FadeTransition(
                      opacity: _fadeIn,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppConstants.appName.toUpperCase(),
                            style: TextStyle(
                              color: themeColors.textPrimary.withAlpha(120),
                              fontSize: 12,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 5.0,
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // LOADING INDICATOR: Theme-aware animated line
                          _buildPremiumLoadingBar(themeColors.textPrimary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPremiumLoadingBar(Color color) {
    return Container(
      width: 48,
      height: 1.2,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(1),
      ),
      child: Stack(
        children: [
          FractionalTranslation(
            translation: Offset(_loadingSweep.value, 0),
            child: Container(
              width: 24,
              height: 1.2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withAlpha(0),
                    color.withAlpha(80),
                    color.withAlpha(0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
