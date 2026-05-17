import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/theme.dart';

/// Persistent (non-modal) rest timer bar shown at the bottom of the log screen.
/// All timer logic lives in the parent screen; this widget is purely presentational.
class RestTimerBar extends StatelessWidget {
  final int secondsRemaining;
  final VoidCallback onSkip;
  final VoidCallback onAddTime;
  final VoidCallback onSubtractTime;

  const RestTimerBar({
    super.key,
    required this.secondsRemaining,
    required this.onSkip,
    required this.onAddTime,
    required this.onSubtractTime,
  });

  @override
  Widget build(BuildContext context) {
    final m = secondsRemaining ~/ 60;
    final s = secondsRemaining % 60;
    final timeStr = '$m:${s.toString().padLeft(2, '0')}';
    final isLow = secondsRemaining <= 10;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Icon(
              Icons.timer_outlined,
              size: 18,
              color: isLow ? AppColors.danger : AppColors.primary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text('REST', style: AppTextStyles.bodySecondary(11)),
            const SizedBox(width: AppSpacing.sm),
            Text(
              timeStr,
              style: AppTextStyles.stat(20).copyWith(
                color: isLow ? AppColors.danger : AppColors.primary,
              ),
            ),
            const Spacer(),
            _AdjustButton(label: '-15', onTap: onSubtractTime),
            const SizedBox(width: AppSpacing.xs),
            _AdjustButton(label: '+15', onTap: onAddTime),
            const SizedBox(width: AppSpacing.sm),
            GestureDetector(
              onTap: onSkip,
              child: Text(
                'Skip',
                style: AppTextStyles.bodySecondary(13)
                    .copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdjustButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AdjustButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: AppTextStyles.body(12)),
      ),
    );
  }
}
