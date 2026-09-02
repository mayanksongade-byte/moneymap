import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../constants/color_constants.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../../config/routes/app_routes.dart';

class AppBottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends State<AppBottomNav>
    with TickerProviderStateMixin {
  AnimationController? _addRef;
  AnimationController? _slideRef;

  AnimationController get _addCtrl => _addRef ??= AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: widget.currentIndex == 2 ? 1 : 0,
  );

  AnimationController get _slideCtrl => _slideRef ??= AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    value: 1,
  );

  late double _fromIndex;
  late double _toIndex;
  int _pressed = -1;

  static const _items = <_NavItemData>[
    _NavItemData(Icons.grid_view_outlined, Icons.grid_view_rounded, 'Home'),
    _NavItemData(Icons.insights_outlined, Icons.insights_rounded, 'Stats'),
    _NavItemData(Icons.add_rounded, Icons.add_rounded, 'Add', isCenter: true),
    _NavItemData(Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    _fromIndex = widget.currentIndex.toDouble();
    _toIndex = widget.currentIndex.toDouble();
  }

  @override
  void didUpdateWidget(covariant AppBottomNav old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      final cur = _lerpIndex();
      _fromIndex = cur;
      _toIndex = widget.currentIndex.toDouble();
      _slideCtrl
        ..value = 0
        ..forward();

      widget.currentIndex == 2 ? _addCtrl.forward() : _addCtrl.reverse();
    }
  }

  double _lerpIndex() {
    final t = Curves.easeOutCubic.transform(_slideCtrl.value);
    return _fromIndex + (_toIndex - _fromIndex) * t;
  }

  @override
  void dispose() {
    _addRef?.dispose();
    _slideRef?.dispose();
    super.dispose();
  }

  void _tap(int i) {
    if (widget.currentIndex == i && i != 2) return;
    
    i == 2 ? HapticFeedback.mediumImpact() : HapticFeedback.selectionClick();

    // Notify parent first
    widget.onTap(i);

    switch (i) {
      case 0:
        context.go(AppRoutes.home);
        break;
      case 1:
        context.go(AppRoutes.statistics);
        break;
      case 2:
        context.push(AppRoutes.addTransaction, extra: {'initialType': 'expense'});
        break;
      case 3:
        context.go(AppRoutes.profile);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    const double barHeight = 72;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 10),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.12),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: Container(
                  height: barHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    color: colors.surface.withValues(alpha: isDark ? 0.92 : 0.96),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: barHeight,
            child: LayoutBuilder(

              builder: (context, c) {
                final itemW = c.maxWidth / _items.length;
                final pillW = itemW * 0.85;

                return AnimatedBuilder(
                  animation: Listenable.merge([_slideCtrl, _addCtrl]),
                  builder: (context, _) {
                    final pos = _lerpIndex();
                    final pillOpacity = (1 - _addCtrl.value).clamp(0.0, 1.0);

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          top: 10,
                          bottom: 10,
                          left: itemW * pos + (itemW - pillW) / 2,
                          child: Opacity(
                            opacity: pillOpacity,
                            child: Container(
                              width: pillW,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                color: AppColors.primary.withValues(alpha: 0.08),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          left: itemW * pos + (itemW - 24) / 2,
                          child: Opacity(
                            opacity: pillOpacity,
                            child: Container(
                              width: 24,
                              height: 3,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(3)),
                                boxShadow: [
                                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.5), blurRadius: 8),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            for (var i = 0; i < _items.length; i++)
                              Expanded(
                                child: _items[i].isCenter
                                    ? _center(i)
                                    : _item(i, _items[i]),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(int index, _NavItemData item) {
    final selected = widget.currentIndex == index;
    final colors = context.colors;
    final color = selected ? AppColors.primary : colors.textDisabled;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = index),
      onTapCancel: () => setState(() => _pressed = -1),
      onTapUp: (_) => setState(() => _pressed = -1),
      onTap: () => _tap(index),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed == index ? 0.92 : 1.0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? item.filled : item.outlined,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              item.label.toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _center(int index) {
    final t = Curves.easeOutCubic.transform(_addCtrl.value);
    final pressedScale = _pressed == index ? 0.88 : 1.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = index),
      onTapCancel: () => setState(() => _pressed = -1),
      onTapUp: (_) => setState(() => _pressed = -1),
      onTap: () => _tap(index),
      child: Center(
        child: Transform.scale(
          scale: pressedScale,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: Offset.zero,
                    ),
                  ],
                ),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, Color(0xFF1E40AF)],
                  ),
                  border: Border.all(color: Colors.white24, width: 1.5),
                ),
                child: Transform.rotate(
                  angle: t * 0.7854,
                  child: const Icon(Icons.add_rounded, size: 28, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData outlined;
  final IconData filled;
  final String label;
  final bool isCenter;

  const _NavItemData(this.outlined, this.filled, this.label, {this.isCenter = false});
}
