import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors_extension.dart';
import '../providers/app_auth_provider.dart';
import '../../../../config/routes/app_routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  late AnimationController _fadeController;
  late AnimationController _floatController;
  
  bool _obscurePassword = true;
  bool _isGoogleLoading = false;

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
    _passwordController.dispose();
    _fadeController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
      final success = await authProvider.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      
      if (!mounted) return;

      if (success) {
        if (authProvider.status == AuthStatus.unverified) {
          context.go(AppRoutes.verifyEmail);
        } else {
          context.go(AppRoutes.home);
        }
      } else {
        // Show error message if login fails
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.error ?? 'Login failed. Please check your credentials.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final success = await authProvider.signInWithGoogle();
    
    if (!mounted) return;
    setState(() => _isGoogleLoading = false);

    if (success) {
      if (authProvider.status == AuthStatus.unverified) {
        context.go(AppRoutes.verifyEmail);
      } else {
        context.go(AppRoutes.home);
      }
    } else {
      // Show error message if Google sign-in fails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error ?? 'Google sign-in failed.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final authProvider = Provider.of<AppAuthProvider>(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
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
              top: size.height * 0.1,
              right: -size.width * 0.2,
              child: Container(
                width: size.width * 0.8,
                height: size.width * 0.8,
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
      
            // 3. Main Content
            SafeArea(
              child: Column(
                children: [
                  // Custom App Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _handleBack,
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: colors.border),
                            ),
                            child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: colors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
      
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Form(
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
                                    'Welcome Back',
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Login to your account',
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Continue managing your finances securely.',
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
      
                            const SizedBox(height: 30),
      
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
      
                            const SizedBox(height: 40),
      
                            // Email Field
                            _SlideUpAnimation(
                              delay: 300,
                              child: _GlassTextField(
                                controller: _emailController,
                                hintText: 'Email Address',
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Please enter your email';
                                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                            ),
      
                            const SizedBox(height: 20),
      
                            // Password Field
                            _SlideUpAnimation(
                              delay: 400,
                              child: _GlassTextField(
                                controller: _passwordController,
                                hintText: 'Password',
                                icon: Icons.lock_outline_rounded,
                                obscureText: _obscurePassword,
                                isPassword: true,
                                onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Please enter your password';
                                  if (value.length < 6) return 'Password must be at least 6 characters';
                                  return null;
                                },
                              ),
                            ),
      
                            // Forgot Password
                            _SlideUpAnimation(
                              delay: 450,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => context.push(AppRoutes.forgotPassword),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF3B82F6),
                                    minimumSize: Size.zero,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  child: const Text(
                                    'Forgot Password?',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ),
      
                            const SizedBox(height: 10),
      
                            // Login Button
                            _SlideUpAnimation(
                              delay: 500,
                              child: _PremiumButton(
                                text: 'Login',
                                onPressed: authProvider.isLoading ? null : _handleLogin,
                                isLoading: authProvider.isLoading,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                                ),
                                trailingIcon: Icons.arrow_forward_rounded,
                                glowColor: const Color(0xFF2563EB).withValues(alpha: 0.3),
                              ),
                            ),
      
                            const SizedBox(height: 24),
      
                            // Divider
                            _SlideUpAnimation(
                              delay: 550,
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
      
                            // Google Button
                            _SlideUpAnimation(
                              delay: 600,
                              child: _PremiumButton(
                                onPressed: (authProvider.isLoading || authProvider.isGoogleLoading) ? null : _handleGoogleSignIn,
                                isLoading: authProvider.isGoogleLoading,
                                backgroundColor: isDark ? Colors.white : colors.surface,
                                foregroundColor: isDark ? Colors.black : colors.textPrimary,
                                icon: SvgPicture.asset(
                                  "assets/icons/google.svg",
                                  width: 24,
                                  height: 24,
                                ),
                                text: 'Continue with Google',
                                hasShadow: true,
                              ),
                            ),
      
                            const SizedBox(height: 32),
      
                            // Register Link
                            _SlideUpAnimation(
                              delay: 650,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Don't have an account? ",
                                    style: TextStyle(color: colors.textSecondary),
                                  ),
                                  GestureDetector(
                                    onTap: () => context.push(AppRoutes.register),
                                    child: const Text(
                                      'Create Account',
                                      style: TextStyle(
                                        color: Color(0xFF3B82F6),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
      
                            const SizedBox(height: 32),
      
                            // Footer Links
                            _SlideUpAnimation(
                              delay: 700,
                              child: Column(
                                children: [
                                  Text(
                                    'By continuing you agree to our',
                                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _FooterLink(text: 'Terms of Service', onTap: () {}, color: colors.textPrimary),
                                      Text('  •  ', style: TextStyle(color: colors.divider)),
                                      _FooterLink(text: 'Privacy Policy', onTap: () {}, color: colors.textPrimary),
                                    ],
                                  ),
                                ],
                              ),
                            ),
      
                            SizedBox(height: bottomPadding + 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isDark 
                ? Colors.white.withValues(alpha: _isFocused ? 0.08 : 0.04)
                : colors.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isFocused 
                  ? const Color(0xFF3B82F6).withValues(alpha: 0.5) 
                  : colors.border,
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
            cursorColor: Colors.blue,
            style: TextStyle(color: colors.textPrimary, fontSize: 16),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(color: colors.textHint),
              prefixIcon: Icon(
                widget.icon, 
                color: _isFocused ? const Color(0xFF3B82F6) : colors.textSecondary, 
                size: 22
              ),
              suffixIcon: widget.isPassword
                  ? IconButton(
                      onPressed: widget.onToggleVisibility,
                      icon: Icon(
                        widget.obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: colors.textSecondary,
                        size: 20,
                      ),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
        ),
      ],
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
          height: 58,
          decoration: BoxDecoration(
            color: widget.isOutline ? Colors.transparent : (widget.gradient == null ? widget.backgroundColor : null),
            gradient: widget.isOutline ? null : widget.gradient,
            borderRadius: BorderRadius.circular(20),
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

class _FooterLink extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final Color color;

  const _FooterLink({required this.text, required this.onTap, required this.color});

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
