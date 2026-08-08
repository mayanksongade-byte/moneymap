import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/color_constants.dart';
import '../../../../core/theme/app_colors_extension.dart';

class PremiumAmountField extends StatefulWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;

  const PremiumAmountField({
    super.key,
    required this.controller,
    this.validator,
  });

  @override
  State<PremiumAmountField> createState() => _PremiumAmountFieldState();
}

class _PremiumAmountFieldState extends State<PremiumAmountField> {
  final NumberFormat formatter = NumberFormat("#,##0.##", "en_IN");
  final FocusNode _focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      validator: widget.validator,
      focusNode: _focusNode,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.bold,
        color: context.colors.textPrimary,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      decoration: InputDecoration(
        filled: true,
        fillColor: context.colors.surface,
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 20),
          child: Icon(
            Icons.currency_rupee_rounded,
            color: AppColors.primary,
            size: 28,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 60,
        ),
        hintText: "0.00",
        hintStyle: TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.bold,
          color: context.colors.textDisabled,
        ),
        labelText: "Amount",
        labelStyle: const TextStyle(
          fontSize: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(
            color: context.colors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 28,
          horizontal: 24,
        ),
      ),
    );
  }
}