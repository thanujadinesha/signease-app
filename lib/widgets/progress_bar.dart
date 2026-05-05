import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ProgressBar extends StatelessWidget {
  final int currentStep; // 1–4

  const ProgressBar({super.key, required this.currentStep});

  static const _labels = ['Signature', 'Document', 'Place', 'Download'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Column(
        children: [
          // Dots + lines row
          Row(
            children: List.generate(4, (i) {
              final step = i + 1;
              final isDone = step < currentStep;
              final isActive = step == currentStep;
              return Expanded(
                flex: i < 3 ? 1 : 0,
                child: Row(
                  children: [
                    _StepDot(step: step, isDone: isDone, isActive: isActive),
                    if (i < 3)
                      Expanded(
                        child: Container(
                          height: 1.5,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          color: isDone ? AppColors.success : AppColors.border,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          // Labels
          Row(
            children: List.generate(4, (i) {
              final step = i + 1;
              final isDone = step < currentStep;
              final isActive = step == currentStep;
              return Expanded(
                child: Text(
                  _labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: isDone
                        ? AppColors.success
                        : isActive
                            ? AppColors.accent2
                            : AppColors.text3,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int step;
  final bool isDone;
  final bool isActive;

  const _StepDot({
    required this.step,
    required this.isDone,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDone
        ? AppColors.success
        : isActive
            ? AppColors.accent
            : AppColors.surface;

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDone
              ? AppColors.success
              : isActive
                  ? AppColors.accent
                  : AppColors.border,
          width: 1.5,
        ),
        boxShadow: isActive
            ? [BoxShadow(color: AppColors.accentGlow, blurRadius: 16)]
            : null,
      ),
      child: Center(
        child: isDone
            ? const Icon(Icons.check, size: 14, color: Colors.white)
            : Text(
                '$step',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : AppColors.text3,
                ),
              ),
      ),
    );
  }
}
