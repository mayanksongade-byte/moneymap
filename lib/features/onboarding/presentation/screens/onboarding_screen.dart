import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/string_constants.dart';
import '../../../../config/routes/app_routes.dart';
import '../../../../core/theme/app_colors_extension.dart';
import 'package:moneymap/features/auth/presentation/providers/app_auth_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _floatingController;

  final List<OnboardingData> _pages = [
    OnboardingData(
      image: 'assets/images/onbording_illustration/Track_Every_Expanse.png',
      title: AppStrings.trackEveryExpense,
      description: AppStrings.trackEveryExpenseDesc,
    ),
    OnboardingData(
      image: 'assets/images/onbording_illustration/Visual_Lnsights.png',
      title: AppStrings.visualInsights,
      description: AppStrings.visualInsightsDesc,
    ),
    OnboardingData(
      image: 'assets/images/onbording_illustration/Achieve_goals.png',
      title: AppStrings.achieveYourGoals,
      description: AppStrings.achieveYourGoalsDesc,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _navigateToAuth() {
    context.read<AppAuthProvider>().completeOnboarding();
    context.go(AppRoutes.auth);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        fit: StackFit.expand,
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

          // 2. Glow Effects
          Positioned(
            top: -size.width * 0.2,
            right: -size.width * 0.2,
            child: _GlowEffect(color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.08 : 0.05), size: size.width * 0.8),
          ),
          Positioned(
            bottom: size.height * 0.2,
            left: -size.width * 0.3,
            child: _GlowEffect(color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.06 : 0.04), size: size.width * 0.9),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 3. Skip Button
                SizedBox(
                  width: size.width,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: TextButton(
                        onPressed: () {
                          context.read<AppAuthProvider>().completeOnboarding();
                          _pageController.animateToPage(2, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              AppStrings.skip, 
                              style: TextStyle(
                                color: colors.textSecondary, 
                                fontSize: 16, 
                                fontWeight: FontWeight.w600
                              )
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded, size: 16, color: colors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // 4. Content Area
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      return AnimatedBuilder(
                        animation: _pageController,
                        builder: (context, child) {
                          double value = 1.0;
                          if (_pageController.position.haveDimensions) {
                            value = (_pageController.page! - index).abs();
                            value = (1 - (value * 0.5)).clamp(0.0, 1.0);
                          }
                          return Opacity(opacity: value, child: child);
                        },
                        child: _buildPageContent(index, size, colors),
                      );
                    },
                  ),
                ),

                // 5. Bottom Controls
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPadding > 0 ? bottomPadding : 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: size.width,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(3, (index) => _AnimatedIndicator(isActive: _currentPage == index, colors: colors)),
                        ),
                      ),
                      const SizedBox(height: 32),
                      _PremiumActionButton(
                        text: _currentPage == 2 ? AppStrings.getStarted : AppStrings.next,
                        onPressed: () {
                          if (_currentPage == 2) {
                            _navigateToAuth();
                          } else {
                            _pageController.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.easeInOutQuart);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageContent(int index, Size size, AppColorsExtension colors) {
    final page = _pages[index];
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: size.height * 0.48,
            child: AnimatedBuilder(
              animation: _floatingController,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, 10 * Curves.easeInOutSine.transform(_floatingController.value) - 5),
                child: child,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Image.asset(page.image, fit: BoxFit.contain),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  page.title, 
                  textAlign: TextAlign.center, 
                  style: TextStyle(
                    fontSize: 28, 
                    fontWeight: FontWeight.bold, 
                    color: colors.textPrimary, 
                    height: 1.2
                  )
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: size.width * 0.75,
                  child: Text(
                    page.description, 
                    textAlign: TextAlign.center, 
                    maxLines: 4, 
                    style: TextStyle(
                      fontSize: 16, 
                      color: colors.textSecondary, 
                      height: 1.6
                    )
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowEffect extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowEffect({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    final double safeSize = size.abs().clamp(1.0, 1000.0);
    return Container(
      width: safeSize,
      height: safeSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: (safeSize * 0.5).abs(), spreadRadius: (safeSize * 0.1).abs())],
      ),
    );
  }
}

class _AnimatedIndicator extends StatelessWidget {
  final bool isActive;
  final AppColorsExtension colors;
  const _AnimatedIndicator({required this.isActive, required this.colors});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 28 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF2563EB) : colors.textDisabled.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: isActive ? const Color(0xFF2563EB).withValues(alpha: 0.3) : Colors.transparent,
            blurRadius: isActive ? 8 : 0,
            spreadRadius: isActive ? 1 : 0,
          )
        ],
      ),
    );
  }
}

class _PremiumActionButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  const _PremiumActionButton({required this.text, required this.onPressed});

  @override
  State<_PremiumActionButton> createState() => _PremiumActionButtonState();
}

class _PremiumActionButtonState extends State<_PremiumActionButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF3B82F6)]),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(widget.text, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              const Positioned(right: 20, child: Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22)),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingData {
  final String image;
  final String title;
  final String description;
  OnboardingData({required this.image, required this.title, required this.description});
}
