import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AuthFieldLabel extends StatelessWidget {
  final String label;
  const AuthFieldLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.text2,
        ),
      );
}

class AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType keyboardType;
  final Widget? suffix;
  final String? Function(String?)? validator;

  const AuthField({
    super.key,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.suffix,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 15, color: AppColors.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.text3, fontSize: 14),
        suffixIcon: suffix != null
            ? Padding(
                padding: const EdgeInsets.only(right: 14),
                child: suffix,
              )
            : null,
        suffixIconConstraints:
            const BoxConstraints(minWidth: 44, minHeight: 44),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),
    );
  }
}

class AuthButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const AuthButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.accent, Color(0xFF6D28D9)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: AppColors.accentGlow,
                blurRadius: 20,
                offset: const Offset(0, 4))
          ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.1,
                  ),
                ),
        ),
      ),
    );
  }
}
