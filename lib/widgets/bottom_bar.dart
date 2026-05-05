import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BottomBar extends StatelessWidget {
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback? onBack;
  final bool primaryEnabled;
  final Color? primaryColor;
  final IconData? primaryIcon;

  const BottomBar({
    super.key,
    required this.primaryLabel,
    this.onPrimary,
    this.onBack,
    this.primaryEnabled = true,
    this.primaryColor,
    this.primaryIcon = Icons.chevron_right,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: 0.9),
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (onBack != null) ...[
            _GhostButton(onTap: onBack!),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: _PrimaryButton(
              label: primaryLabel,
              onTap: primaryEnabled ? onPrimary : null,
              gradient: primaryColor != null
                  ? LinearGradient(
                      colors: [primaryColor!, primaryColor!.withValues(alpha: 0.7)],
                    )
                  : null,
              icon: primaryIcon,
            ),
          ),
        ],
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  final VoidCallback onTap;

  const _GhostButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Icon(
          Icons.chevron_left,
          color: AppColors.text2,
          size: 22,
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final LinearGradient? gradient;
  final IconData? icon;

  const _PrimaryButton({
    required this.label,
    this.onTap,
    this.gradient,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 50,
        decoration: BoxDecoration(
          gradient: enabled
              ? (gradient ??
                  const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.accent, Color(0xFF6D28D9)],
                  ))
              : null,
          color: enabled ? null : AppColors.surface2,
          borderRadius: BorderRadius.circular(12),
          boxShadow: enabled
              ? [BoxShadow(color: AppColors.accentGlow, blurRadius: 20, offset: const Offset(0, 4))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: enabled ? Colors.white : AppColors.text3,
                letterSpacing: -0.1,
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: 6),
              Icon(
                icon,
                color: enabled ? Colors.white : AppColors.text3,
                size: 18,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
