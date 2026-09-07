import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/color_constants.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../providers/app_auth_provider.dart';
import '../../../../config/routes/app_routes.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> with TickerProviderStateMixin {
  Timer? _timer;
  Timer? _resendTimer;
  int _resendCountdown = 0;
  late AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkVerification(context.read<AppAuthProvider>(), isAuto: true);
    });

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _resendTimer?.cancel();
    _floatController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() => _resendCountdown = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown == 0) {
        timer.cancel();
      } else {
        setState(() => _resendCountdown--);
      }
    });
  }

  Future<void> _checkVerification(AppAuthProvider authProvider, {bool isAuto = false}) async {
    final verified = await authProvider.isEmailVerified();

    if (!mounted) return;

    if (verified) {
      _timer?.cancel();
      if (!isAuto && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text("Email verified successfully."),
          ),
        );
      }
      if (context.mounted) {
        context.go(AppRoutes.home);
      }
    } else if (!isAuto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
          content: Text("Email is not verified yet.", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      );
    }
  }

  Future<void> _resendEmail(AppAuthProvider authProvider) async {
    if (_resendCountdown > 0) return;

    final success = await authProvider.resendVerificationEmail();
    if (!mounted) return;

    if (success) _startResendTimer();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: success ? const Color(0xFF10B981) : AppColors.error,
        content: Text(
          success ? "Verification email sent again." : authProvider.error ?? "Unable to send email.",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _launchGmail() async {
    final Uri url = Uri.parse('googlegmail://');
    final Uri fallbackUrl = Uri.parse('https://mail.google.com');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        await launchUrl(fallbackUrl);
      }
    } catch (e) {
      await launchUrl(fallbackUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context);
    final size = MediaQuery.of(context).size;
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.background,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark 
              ? [const Color(0xFF08111F), const Color(0xFF0D1B2A), const Color(0xFF101827)]
              : [colors.background, colors.surface, colors.background],
          ),
        ),
        child: Stack(
          children: [
            // 1. Subtle Glow
            Positioned(
              top: size.height * 0.1,
              left: -size.width * 0.2,
              child: Container(
                width: size.width * 0.8,
                height: size.width * 0.8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.08 : 0.04),
                      blurRadius: 100,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
            ),

            // 2. Main Content
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 32),

                      // Header
                      _SlideUpAnimation(
                        delay: 100,
                        child: Column(
                          children: [
                            Text(
                              'Email Verification',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Check Your Inbox',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "We've sent a verification link to your email address.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 15,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Illustration
                      _SlideUpAnimation(
                        delay: 200,
                        child: Center(
                          child: AnimatedBuilder(
                            animation: _floatController,
                            builder: (context, child) => Transform.translate(
                              offset: Offset(0, 10 * Curves.easeInOutSine.transform(_floatController.value) - 5),
                              child: child,
                            ),
                            child: Image.asset(
                              'assets/images/Welcome_illustration/Welcome.png',
                              height: 300,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Email Glass Card
                      _SlideUpAnimation(
                        delay: 300,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: colors.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.email_outlined, color: Color(0xFF2563EB), size: 24),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          authProvider.user?.email ?? "Your Email",
                                          style: TextStyle(
                                            color: colors.textPrimary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 14),
                                            const SizedBox(width: 4),
                                            Text(
                                              "Verification email sent",
                                              style: TextStyle(
                                                color: const Color(0xFF10B981).withValues(alpha: 0.8),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3B82F6)),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    "Checking verification status...",
                                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Action Buttons
                      _SlideUpAnimation(
                        delay: 400,
                        child: Column(
                          children: [
                            _PremiumButton(
                              text: "I've Verified",
                              isLoading: authProvider.isLoading,
                              onPressed: authProvider.isLoading ? null : () => _checkVerification(authProvider),
                              gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF3B82F6)]),
                              trailingIcon: Icons.arrow_forward_rounded,
                              glowColor: const Color(0xFF2563EB).withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            _PremiumButton(
                              text: "Open Gmail",
                              onPressed: _launchGmail,
                              isOutline: true,
                              borderColor: colors.border,
                              foregroundColor: colors.textPrimary,
                              icon: Icon(Icons.mail_outline_rounded, color: colors.textPrimary, size: 20),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Resend Section
                      _SlideUpAnimation(
                        delay: 600,
                        child: Column(
                          children: [
                            Text(
                              "Didn't receive the email?",
                              style: TextStyle(color: colors.textSecondary, fontSize: 14),
                            ),
                            TextButton(
                              onPressed: _resendCountdown > 0 ? null : () => _resendEmail(authProvider),
                              child: Text(
                                _resendCountdown > 0
                                    ? "Resend available in ${_resendCountdown}s"
                                    : "Resend Email",
                                style: TextStyle(
                                  color: _resendCountdown > 0
                                      ? colors.textDisabled
                                      : const Color(0xFF3B82F6),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
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
              if (widget.glowColor != null && !widget.isOutline)
                BoxShadow(color: widget.glowColor!, blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.isLoading)
                const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[widget.icon!, const SizedBox(width: 12)],
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
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _offsetAnimation = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuint),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
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
      child: SlideTransition(position: _offsetAnimation, child: widget.child),
    );
  }
}
