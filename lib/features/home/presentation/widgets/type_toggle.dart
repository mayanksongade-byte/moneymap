import 'package:flutter/material.dart';
import '../../../../core/constants/color_constants.dart';
import '../../../../core/theme/app_colors_extension.dart';

class TypeToggle extends StatelessWidget {
  final String selectedType;
  final Function(String) onTypeChanged;

  const TypeToggle({
    super.key,
    required this.selectedType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.colors.border.withValues(alpha: .30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildToggleOption(
            context: context,
            label: "Income",
            value: "income",
            icon: Icons.arrow_downward_rounded,
            isSelected: selectedType == "income",
            color: AppColors.success,
          ),

          const SizedBox(width: 6),

          _buildToggleOption(
            context: context,
            label: "Expense",
            value: "expense",
            icon: Icons.arrow_upward_rounded,
            isSelected: selectedType == "expense",
            color: AppColors.error,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOption({
    required BuildContext context,
    required String label,
    required String value,
    required bool isSelected,
    required Color color,
    required IconData icon,
  }){
    return Expanded(
      child: GestureDetector(
        onTap: () => onTypeChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: .14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? color.withValues(alpha: .35)
                  : Colors.transparent,
            ),
          ),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: TextStyle(
                color: isSelected
                    ? color
                    : context.colors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [

                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? color
                          : context.colors.background,
                    ),
                    child: Icon(
                      icon,
                      color: isSelected
                          ? Colors.white
                          : color,
                      size: 18,
                    ),
                  ),

                  const SizedBox(width: 10),

                  Text(label),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}