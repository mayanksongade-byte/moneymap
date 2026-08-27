import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../config/routes/app_routes.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../../../core/services/notification_service.dart';
import 'package:moneymap/features/auth/presentation/providers/app_auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _exitController;
  late final AnimationController _floatController;

  late final Animation<double> _fadeIn;
  late final Animation<double> _scale;
  late final Animation<double> _exitFade;
  late final Animation<double> _float;

  @override
  void initState() {
    super.initState();

    NotificationService().requestPermissions();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeIn),
      ),
    );

    _scale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOutBack),
      ),
    );

    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: Curves.easeInOut,
      ),
    );

    _float = Tween<double>(begin: 0.0, end: -15.0).animate(
      CurvedAnimation(
        parent: _floatController,
        curve: Curves.easeInOutQuad,
      ),
    );

    _entranceController.forward().then((_) => _navigateToNext());

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  void _navigateToNext() async {
    if (!mounted) return;
    
    try {
      final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
      
      // 1. Wait for Auth Provider to initialize (includes Firebase session restoration)
      int retries = 0;
      while (!authProvider.isInitialized && retries < 40) {
        await Future.delayed(const Duration(milliseconds: 100));
        retries++;
      }
      
      if (!mounted) return;

      // 2. Start Exit Animation (Navigate while fading out)
      _exitController.forward();
      
      // Short delay to let the fade-out start before navigation switch
      await Future.delayed(const Duration(milliseconds: 150));

      if (!mounted) return;

      // 3. Final Routing Decision
      final status = authProvider.status;
      switch (status) {
        case AuthStatus.authenticated:
        case AuthStatus.guest:
          context.go(AppRoutes.home);
          break;
          
        case AuthStatus.unverified:
          context.go(AppRoutes.verifyEmail);
          break;
          
        case AuthStatus.unauthenticated:
        case AuthStatus.initial:
          if (authProvider.onboardingComplete) {
            context.go(AppRoutes.auth);
          } else {
            context.go(AppRoutes.onboarding);
          }
          break;
      }
    } catch (e) {
      if (mounted) context.go(AppRoutes.onboarding);
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _exitController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const Color brandBlue = Color(0xFF2F7CF6);

    return Scaffold(
      backgroundColor: themeColors.background,
      body: AnimatedBuilder(
        animation: Listenable.merge([_entranceController, _exitController]),
        builder: (context, child) {
          // Combined opacity: fade in then fade out when ready
          final double currentOpacity = _exitController.isAnimating || _exitController.isCompleted
              ? _exitFade.value
              : _fadeIn.value;

          return Opacity(
            opacity: currentOpacity,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isDark
                            ? [const Color(0xFF0F172A), const Color(0xFF020617)]
                            : [const Color(0xFFF8FAFC), const Color(0xFFEDF2F7)],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -50,
                  right: -50,
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: brandBlue.withOpacity(isDark ? 0.08 : 0.05),
                    ),
                  ),
                ),
                Center(
                  child: FadeTransition(
                    opacity: _fadeIn,
                    child: ScaleTransition(
                      scale: _scale,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedBuilder(
                            animation: _float,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(0, _float.value),
                                child: Container(
                                  width: 150,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDark 
                                        ? Colors.white.withOpacity(0.05) 
                                        : Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: brandBlue.withOpacity(isDark ? 0.2 : 0.1),
                                        blurRadius: 40,
                                        offset: const Offset(0, 20),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: Colors.white.withOpacity(isDark ? 0.1 : 0.8),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Image.asset(
                                      'assets/images/Lable_Logo/Lable.png',
                                      width: 200,
                                      height: 200,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.wallet, size: 60, color: brandBlue),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 40),
                          Text(
                            AppConstants.appName.toUpperCase(),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 10,
                              color: themeColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Finance. Simplified.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 1.5,
                              color: themeColors.textPrimary.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 60,
                  left: 0,
                  right: 0,
                  child: FadeTransition(
                    opacity: _fadeIn,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_outline_rounded, size: 14, 
                                 color: themeColors.textPrimary.withOpacity(0.3)),
                            const SizedBox(width: 6),
                            Text(
                              'SECURE & ENCRYPTED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                                color: themeColors.textPrimary.withOpacity(0.3),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: 40,
                          height: 2,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              backgroundColor: brandBlue.withOpacity(0.1),
                              valueColor: const AlwaysStoppedAnimation<Color>(brandBlue),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
