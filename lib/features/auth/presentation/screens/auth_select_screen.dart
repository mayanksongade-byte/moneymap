import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../../../../core/constants/string_constants.dart';
import '../../../../core/constants/color_constants.dart';
import '../providers/app_auth_provider.dart';
import '../../../../config/routes/app_routes.dart';

class AuthSelectScreen extends StatefulWidget {
  const AuthSelectScreen({super.key});

  @override
  State<AuthSelectScreen> createState() => _AuthSelectScreenState();
}

class _AuthSelectScreenState extends State<AuthSelectScreen> with TickerProviderStateMixin {
  late AnimationController _floatingController;
  late AnimationController _fadeController;
  bool _isGoogleLoading = false;
  bool _isGuestLoading = false;
  
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    _checkInitialConnectivity();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      setState(() {
        _isOffline = results.contains(ConnectivityResult.none);
      });
    });
  }

  Future<void> _checkInitialConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    setState(() {
      _isOffline = results.contains(ConnectivityResult.none);
    });
  }

  @override
  void dispose() {
    _floatingController.dispose();
    _fadeController.dispose();
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final authProvider = Provider.of<AppAuthProvider>(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // 1. Premium Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark 
                  ? [const Color(0xFF08111F), const Color(0xFF0D1B2A), const Color(0xFF101827)]
                  : [colors.background, colors.surface, colors.background],
              ),
            ),
          ),

          // 2. Subtle Radial Glow
          Positioned(
            top: size.height * 0.1,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: size.width * 0.7,
                height: size.width * 0.7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.12 : 0.08),
                      blurRadius: 100,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Main Content
          SafeArea(
            child: Column(
              children: [
                if (_isOffline)
                  _buildOfflineBanner(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 20), // Reduced height to keep text at the very top

                    // Welcome Title & Subtitle - Now at the very top
                    _SlideUpAnimation(
                      delay: 200,
                      child: Column(
                        children: [
                          Text(
                            'Welcome to MoneyMap',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Take control of your finances with smart expense tracking, powerful insights, and secure money management.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 16,
                              height: 1.5,
                            ),
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Hero Illustration
                    SizedBox(
                      height: size.height * 0.35,
                      child: AnimatedBuilder(
                        animation: _floatingController,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, 15 * Curves.easeInOutSine.transform(_floatingController.value) - 7.5),
                            child: child,
                          );
                        },
                        child: Image.asset(
                          'assets/images/Welcome_illustration/Welcome.png',
                          cacheHeight: 600, // Optimized decoding
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Google Button
                    _SlideUpAnimation(
                      delay: 400,
                      child: _PremiumButton(
                        onPressed: authProvider.isLoading ? null : _handleGoogleSignIn,
                        isLoading: _isGoogleLoading,
                        backgroundColor: isDark ? Colors.white : colors.surface,
                        foregroundColor: isDark ? Colors.black : colors.textPrimary,
                        icon: SvgPicture.asset(
                          "assets/icons/google.svg",
                          width: 24,
                          height: 24,
                        ),
                        text: AppStrings.continueWithGoogle,
                        hasShadow: true,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Divider
                    _SlideUpAnimation(
                      delay: 500,
                      child: Row(
                        children: [
                          Expanded(child: Divider(color: colors.divider)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: colors.divider)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Login Button
                    _SlideUpAnimation(
                      delay: 600,
                      child: _PremiumButton(
                        onPressed: () => context.push(AppRoutes.login),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                        ),
                        text: AppStrings.login,
                        trailingIcon: Icons.arrow_forward_rounded,
                        glowColor: const Color(0xFF2563EB).withValues(alpha: 0.3),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Create Account Button
                    _SlideUpAnimation(
                      delay: 700,
                      child: _PremiumButton(
                        onPressed: () => context.push(AppRoutes.register),
                        isOutline: true,
                        borderColor: const Color(0xFF2563EB),
                        foregroundColor: isDark ? Colors.white : const Color(0xFF2563EB),
                        text: AppStrings.createAccount,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Guest Option
                    _SlideUpAnimation(
                      delay: 800,
                      child: TextButton(
                        onPressed: authProvider.isLoading ? null : _handleGuestSignIn,
                        style: TextButton.styleFrom(
                          foregroundColor: colors.textSecondary,
                        ),
                        child: _isGuestLoading 
                          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: colors.textSecondary))
                          : Text(
                              '${AppStrings.continueAsGuest} →',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                            ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Footer
                    _SlideUpAnimation(
                      delay: 900,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: bottomPadding > 0 ? bottomPadding : 24),
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 4,
                          children: [
                            Text(
                              'By continuing, you agree to our',
                              style: TextStyle(color: colors.textSecondary, fontSize: 12),
                            ),
                            _ClickableFooterText(text: 'Terms of Service', onTap: () {}, color: colors.textPrimary),
                            Text(
                              'and',
                              style: TextStyle(color: colors.textSecondary, fontSize: 12),
                            ),
                            _ClickableFooterText(text: 'Privacy Policy', onTap: () {}, color: colors.textPrimary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final success = await authProvider.signInWithGoogle();
    if (mounted) setState(() => _isGoogleLoading = false);

    if (success && context.mounted) {
      if (authProvider.status == AuthStatus.unverified) {
        context.go(AppRoutes.verifyEmail);
      } else {
        context.go(AppRoutes.home);
      }
    }
  }

  Future<void> _handleGuestSignIn() async {
    setState(() => _isGuestLoading = true);
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final success = await authProvider.continueAsGuest();
    if (mounted) setState(() => _isGuestLoading = false);

    if (success && context.mounted) {
      context.go(AppRoutes.home);
    }
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: AppColors.error,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              "No internet connection. Please connect to log in.",
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Widget? icon;
  final IconData? trailingIcon;
  final Gradient? gradient;
  final bool isOutline;
  final Color? borderColor;
  final bool hasShadow;
  final Color? glowColor;

  const _PremiumButton({
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.foregroundColor,
    this.icon,
    this.trailingIcon,
    this.gradient,
    this.isOutline = false,
    this.borderColor,
    this.hasShadow = false,
    this.glowColor,
  });

  @override
  State<_PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<_PremiumButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onPressed == null ? null : (_) => setState(() => _scale = 0.96),
      onTapUp: widget.onPressed == null ? null : (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: widget.isOutline ? Colors.transparent : (widget.gradient == null ? widget.backgroundColor : null),
            gradient: widget.isOutline ? null : widget.gradient,
            borderRadius: BorderRadius.circular(18),
            border: widget.isOutline ? Border.all(color: widget.borderColor ?? Colors.white, width: 1.5) : null,
            boxShadow: [
              if (widget.hasShadow)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              if (widget.glowColor != null)
                BoxShadow(
                  color: widget.glowColor!,
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.isLoading)
                SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: widget.foregroundColor ?? Colors.white,
                  ),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      widget.icon!,
                      const SizedBox(width: 12),
                    ],
                    Text(
                      widget.text,
                      style: TextStyle(
                        color: widget.foregroundColor ?? Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              if (widget.trailingIcon != null && !widget.isLoading)
                Positioned(
                  right: 20,
                  child: Icon(widget.trailingIcon, color: widget.foregroundColor ?? Colors.white, size: 22),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClickableFooterText extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final Color color;

  const _ClickableFooterText({required this.text, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}

class _SlideUpAnimation extends StatefulWidget {
  final Widget child;
  final int delay;

  const _SlideUpAnimation({required this.child, this.delay = 0});

  @override
  State<_SlideUpAnimation> createState() => _SlideUpAnimationState();
}

class _SlideUpAnimationState extends State<_SlideUpAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuint,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: SlideTransition(
        position: _offsetAnimation,
        child: widget.child,
      ),
    );
  }
}
