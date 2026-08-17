import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/constants/color_constants.dart';
import '../../../../core/constants/string_constants.dart';
import '../providers/app_auth_provider.dart';
import '../../../../config/routes/app_routes.dart';
import '../../../../core/theme/app_colors_extension.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  late AnimationController _fadeController;
  late AnimationController _floatController;
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isGoogleLoading = false;
  
  PasswordStrength _strength = PasswordStrength.weak;

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
    
    _passwordController.addListener(_updateStrength);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fadeController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  void _updateStrength() {
    final password = _passwordController.text;
    setState(() {
      _strength = _calculateStrength(password);
    });
  }

  PasswordStrength _calculateStrength(String password) {
    if (password.isEmpty) return PasswordStrength.weak;
    if (password.length < 6) return PasswordStrength.weak;
    
    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    bool hasDigits = password.contains(RegExp(r'[0-9]'));
    bool hasSpecial = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    
    int score = 0;
    if (hasUppercase) score++;
    if (hasDigits) score++;
    if (hasSpecial) score++;
    
    if (password.length >= 8 && score >= 2) return PasswordStrength.strong;
    if (password.length >= 6 && score >= 1) return PasswordStrength.medium;
    return PasswordStrength.weak;
  }

  Future<void> _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
      final success = await authProvider.register(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _nameController.text.trim(),
      );
      if (success && mounted) {
        context.go(AppRoutes.verifyEmail);
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final authProvider = Provider.of<AppAuthProvider>(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Premium Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF08111F),
                  Color(0xFF0D1B2A),
                  Color(0xFF101827),
                ],
              ),
            ),
          ),

          // 2. Subtle Radial Glow
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
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
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
                        onTap: () => context.pop(),
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
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
                                  'Create Account',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Join MoneyMap Today',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Create your secure account and start taking control of your finances.',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
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
                                  'assets/images/onbording_illustration/Achieve_goals.png',
                                  height: 300,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 40),

                          // Full Name Field
                          _SlideUpAnimation(
                            delay: 300,
                            child: _GlassTextField(
                              controller: _nameController,
                              hintText: 'Full Name',
                              icon: Icons.person_outline_rounded,
                              keyboardType: TextInputType.name,
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Please enter your name';
                                if (value.length < 2) return 'Name must be at least 2 characters';
                                return null;
                              },
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Email Field
                          _SlideUpAnimation(
                            delay: 350,
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
                            child: Column(
                              children: [
                                _GlassTextField(
                                  controller: _passwordController,
                                  hintText: 'Password',
                                  icon: Icons.lock_outline_rounded,
                                  obscureText: _obscurePassword,
                                  isPassword: true,
                                  onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) return 'Please enter a password';
                                    if (value.length < 6) return 'Password must be at least 6 characters';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                _PasswordStrengthIndicator(strength: _strength),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Confirm Password Field
                          _SlideUpAnimation(
                            delay: 450,
                            child: _GlassTextField(
                              controller: _confirmPasswordController,
                              hintText: 'Confirm Password',
                              icon: Icons.lock_clock_outlined,
                              obscureText: _obscureConfirmPassword,
                              isPassword: true,
                              onToggleVisibility: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Please confirm your password';
                                if (value != _passwordController.text) return 'Passwords do not match';
                                return null;
                              },
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Create Account Button
                          _SlideUpAnimation(
                            delay: 500,
                            child: _PremiumButton(
                              text: 'Create Account',
                              onPressed: authProvider.isLoading ? null : _handleRegister,
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
                                Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    'OR',
                                    style: TextStyle(
                                      color: const Color(0xFF94A3B8),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Google Button
                          _SlideUpAnimation(
                            delay: 600,
                            child: _PremiumButton(
                              onPressed: authProvider.isLoading ? null : _handleGoogleSignIn,
                              isLoading: _isGoogleLoading,
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
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

                          // Login Link
                          _SlideUpAnimation(
                            delay: 650,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Already have an account? ",
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                                ),
                                GestureDetector(
                                  onTap: () => context.push(AppRoutes.login),
                                  child: const Text(
                                    'Login',
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
                                  'By creating an account you agree to our',
                                  style: TextStyle(color: const Color(0xFF94A3B8), fontSize: 12),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _FooterLink(text: 'Terms of Service', onTap: () {}),
                                    Text('  •  ', style: TextStyle(color: Colors.white.withValues(alpha: 0.2))),
                                    _FooterLink(text: 'Privacy Policy', onTap: () {}),
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

          // Error Message Overlay
          if (authProvider.error != null)
            Positioned(
              top: 60,
              left: 20,
              right: 20,
              child: _SlideUpAnimation(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    authProvider.error!,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum PasswordStrength { weak, medium, strong }

class _PasswordStrengthIndicator extends StatelessWidget {
  final PasswordStrength strength;

  const _PasswordStrengthIndicator({required this.strength});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    double widthFactor;

    switch (strength) {
      case PasswordStrength.weak:
        color = Colors.redAccent;
        label = 'Weak';
        widthFactor = 0.33;
        break;
      case PasswordStrength.medium:
        color = Colors.orangeAccent;
        label = 'Medium';
        widthFactor = 0.66;
        break;
      case PasswordStrength.strong:
        color = Colors.greenAccent;
        label = 'Strong';
        widthFactor = 1.0;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Password Strength',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
            ),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 4,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: widthFactor,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 4),
                ],
              ),
            ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color hintColor = isDark ? Colors.white70 : Colors.grey;
    final Color iconDefaultColor = isDark ? Colors.white70 : Colors.grey.shade700;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isDark 
                ? Colors.white.withValues(alpha: _isFocused ? 0.08 : 0.04)
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isFocused ? const Color(0xFF3B82F6).withValues(alpha: 0.5) : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1)),
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
            style: TextStyle(color: textColor, fontSize: 16),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(color: hintColor),
              prefixIcon: Icon(widget.icon, color: _isFocused ? const Color(0xFF3B82F6) : iconDefaultColor, size: 22),
              suffixIcon: widget.isPassword
                  ? IconButton(
                      onPressed: widget.onToggleVisibility,
                      icon: Icon(
                        widget.obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: iconDefaultColor,
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

  const _FooterLink({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
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
