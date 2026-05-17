import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/colors.dart';
import '../constants/theme.dart';

class SetRow extends StatelessWidget {
  final int setNumber;
  final TextEditingController weightController;
  final TextEditingController repsController;
  final bool completed;
  final ValueChanged<bool> onCompletedChanged;

  const SetRow({
    super.key,
    required this.setNumber,
    required this.weightController,
    required this.repsController,
    required this.completed,
    required this.onCompletedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: completed
          ? AppColors.primaryDim.withValues(alpha: 0.25)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Row(
        children: [
          // Set number
          SizedBox(
            width: 28,
            child: Text(
              '$setNumber',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySecondary(13).copyWith(
                color: completed ? AppColors.primary : AppColors.textDisabled,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Weight field
          Expanded(
            flex: 3,
            child: _CompactField(
              controller: weightController,
              hint: '0',
              suffix: 'kg',
              decimal: true,
              enabled: !completed,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Reps field
          Expanded(
            flex: 2,
            child: _CompactField(
              controller: repsController,
              hint: '0',
              suffix: 'reps',
              decimal: false,
              enabled: !completed,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),

          // Checkbox
          SizedBox(
            width: 40,
            child: Checkbox(
              value: completed,
              onChanged: (v) => onCompletedChanged(v ?? false),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String suffix;
  final bool decimal;
  final bool enabled;

  const _CompactField({
    required this.controller,
    required this.hint,
    required this.suffix,
    required this.decimal,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      textAlign: TextAlign.center,
      style: AppTextStyles.stat(14),
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        if (decimal)
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
        else
          FilteringTextInputFormatter.digitsOnly,
      ],
      decoration: InputDecoration(
        hintText: hint,
        suffixText: suffix,
        suffixStyle: AppTextStyles.bodySecondary(11),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 6),
      ),
    );
  }
}
