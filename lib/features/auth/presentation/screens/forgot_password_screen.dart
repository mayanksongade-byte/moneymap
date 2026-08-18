import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/color_constants.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../providers/app_auth_provider.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  late AnimationController _fadeController;
  late AnimationController _floatController;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _fadeController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink(AppAuthProvider authProvider) async {
    if (!_formKey.currentState!.validate()) return;

    final success = await authProvider.resetPassword(_emailController.text.trim());

    if (!mounted) return;

    if (success) {
      setState(() => _isSuccess = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(authProvider.error ?? "Something went wrong."),
        ),
      );
    }
  }

  Future<void> _launchGmail() async {
    final Uri url = Uri.parse('googlegmail://');
    final Uri fallbackUrl = Uri.parse('https://mail.google.com');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      await launchUrl(fallbackUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final authProvider = Provider.of<AppAuthProvider>(context);
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // 1. Premium Background with theme colors
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
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.1 : 0.05),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Custom App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: colors.border),
                          ),
                          child: Icon(Icons.arrow_back_ios_new_rounded, color: colors.textPrimary, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                      child: _isSuccess ? _buildSuccessState(colors, isDark) : _buildFormState(authProvider, colors),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormState(AppAuthProvider authProvider, AppColorsExtension colors) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          // Header Section
          _SlideUpAnimation(
            delay: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Forgot Password',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Reset your password',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Enter your registered email address and we'll send you a secure password reset link.",
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // Hero Illustration
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

          const SizedBox(height: 50),

          // Email Input
          _SlideUpAnimation(
            delay: 300,
            child: _GlassTextField(
              controller: _emailController,
              hintText: "Email Address",
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) return "Please enter your email";
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                  return "Enter a valid email";
                }
                return null;
              },
            ),
          ),

          const SizedBox(height: 40),

          // Send Link Button
          _SlideUpAnimation(
            delay: 400,
            child: _PremiumButton(
              text: "Send Reset Link",
              isLoading: authProvider.isLoading,
              onPressed: () => _sendResetLink(authProvider),
              gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF3B82F6)]),
              trailingIcon: Icons.arrow_forward_rounded,
              glowColor: const Color(0xFF2563EB).withValues(alpha: 0.3),
            ),
          ),

          const SizedBox(height: 24),

          _SlideUpAnimation(
            delay: 500,
            child: Center(
              child: TextButton(
                onPressed: () => context.pop(),
                child: Text(
                  "Back to Login",
                  style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState(AppColorsExtension colors, bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 60),
        _SlideUpAnimation(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: colors.border),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF10B981),
                    size: 64,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Check your Email",
                  style: TextStyle(color: colors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  "Password reset link has been sent successfully to:",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.textSecondary, fontSize: 16, height: 1.5),
                ),
                const SizedBox(height: 8),
                Text(
                  _emailController.text.trim(),
                  style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 32),
                _PremiumButton(
                  text: "Open Gmail",
                  onPressed: _launchGmail,
                  backgroundColor: colors.surfaceVariant,
                  foregroundColor: colors.textPrimary,
                  icon: Icon(Icons.mail_outline_rounded, color: colors.textPrimary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),
        _SlideUpAnimation(
          delay: 200,
          child: _PremiumButton(
            text: "Back to Login",
            onPressed: () => context.pop(),
            gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF3B82F6)]),
          ),
        ),
      ],
    );
  }
}

class _GlassTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool obscureText;
  final bool isPassword;
  final VoidCallback? onToggleVisibility;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _GlassTextField({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.obscureText = false,
    this.isPassword = false,
    this.onToggleVisibility,
    this.keyboardType,
    this.validator,
  });

  @override
  State<_GlassTextField> createState() => _GlassTextFieldState();
}

class _GlassTextFieldState extends State<_GlassTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.white.withValues(alpha: _isFocused ? 0.08 : 0.04)
            : colors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isFocused ? const Color(0xFF3B82F6).withValues(alpha: 0.5) : colors.border,
          width: 1.5,
        ),
        boxShadow: [
          if (_isFocused)
            BoxShadow(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
              blurRadius: 15,
              spreadRadius: 2,
            ),
        ],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        validator: widget.validator,
        style: TextStyle(color: colors.textPrimary, fontSize: 16),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(color: colors.textHint),
          prefixIcon: Icon(widget.icon, color: _isFocused ? const Color(0xFF3B82F6) : colors.textSecondary, size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
          height: 58,
          decoration: BoxDecoration(
            color: widget.gradient == null ? widget.backgroundColor : null,
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
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
