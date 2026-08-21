import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/routes/app_routes.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../../../core/services/notification_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final AnimationController _floatController;

  late final Animation<double> _fadeIn;
  late final Animation<double> _scale;
  late final Animation<double> _exitFade;
  late final Animation<double> _float;

  @override
  void initState() {
    super.initState();

    NotificationService().requestPermissions();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _scale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.85, 1.0, curve: Curves.easeInOut),
      ),
    );

    _float = Tween<double>(begin: 0.0, end: -15.0).animate(
      CurvedAnimation(
        parent: _floatController,
        curve: Curves.easeInOutQuad,
      ),
    );

    _mainController.forward().then((_) => _navigateToNext());

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
      final user = FirebaseAuth.instance.currentUser;
      
      if (user != null) {
        // Reload user with timeout to handle no internet
        try {
          await user.reload().timeout(const Duration(seconds: 2));
        } catch (_) {
          // Ignore reload errors (like no connection) and proceed
        }
        
        final updatedUser = FirebaseAuth.instance.currentUser;
        
        if (updatedUser != null && (updatedUser.emailVerified || updatedUser.isAnonymous)) {
          context.go(AppRoutes.home);
        } else {
          context.go(AppRoutes.verifyEmail);
        }
      } else {
        context.go(AppRoutes.onboarding);
      }
    } catch (e) {
      // Fallback in case of any critical error
      context.go(AppRoutes.onboarding);
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
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
        animation: _mainController,
        builder: (context, child) {
          return Opacity(
            opacity: _exitFade.value,
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
