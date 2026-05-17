import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/theme.dart';
import '../models/workout_plan.dart';

class PlanCard extends StatelessWidget {
  final WorkoutPlan plan;
  final bool isOwner;
  final VoidCallback onStart;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const PlanCard({
    super.key,
    required this.plan,
    required this.isOwner,
    required this.onStart,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            if (plan.exercises.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildExerciseChips(),
            ],
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onStart,
                child: const Text('Start Workout'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final exerciseCount = plan.exercises.length;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(plan.name, style: AppTextStyles.heading(16)),
              const SizedBox(height: 2),
              Text(
                '${plan.displayName}  ·  '
                '$exerciseCount exercise${exerciseCount == 1 ? '' : 's'}',
                style: AppTextStyles.bodySecondary(12),
              ),
            ],
          ),
        ),
        if (isOwner) _buildMenu(context),
      ],
    );
  }

  Widget _buildMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
      color: AppColors.surfaceAlt,
      padding: EdgeInsets.zero,
      onSelected: (value) {
        if (value == 'edit') onEdit?.call();
        if (value == 'delete') onDelete?.call();
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'edit',
          child: Text('Edit', style: AppTextStyles.body(14)),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Text(
            'Delete',
            style: AppTextStyles.body(14).copyWith(color: AppColors.danger),
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseChips() {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: plan.exercises.map((e) {
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${e.exerciseName}  ×${e.targetSets}',
            style: AppTextStyles.body(11).copyWith(color: AppColors.textSecondary),
          ),
        );
      }).toList(),
    );
  }
}
