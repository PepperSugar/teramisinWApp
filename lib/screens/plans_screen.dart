import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/colors.dart';
import '../constants/theme.dart';
import '../models/workout_plan.dart';
import '../providers/auth_provider.dart';
import '../providers/plan_provider.dart';
import '../widgets/plan_card.dart';

class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(planProvider);
    final currentUid = ref.watch(authStateProvider).valueOrNull?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Plans')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/plans/create'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.background,
        elevation: 0,
        child: const Icon(Icons.add),
      ),
      body: plansAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(
          child: Text(
            'Could not load plans.',
            style: AppTextStyles.body(14).copyWith(color: AppColors.textSecondary),
          ),
        ),
        data: (plans) => _PlansBody(plans: plans, currentUid: currentUid),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _PlansBody extends ConsumerWidget {
  final List<WorkoutPlan> plans;
  final String? currentUid;

  const _PlansBody({required this.plans, required this.currentUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (plans.isEmpty) return _EmptyState(onCreateTap: () => context.push('/plans/create'));

    final myPlans = plans.where((p) => p.uid == currentUid).toList();
    final friendPlans = plans.where((p) => p.uid != currentUid).toList();

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(planProvider.notifier).syncFromFirestore(),
      child: ListView(
        padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: 96),
        children: [
          if (myPlans.isNotEmpty) ...[
            _SectionHeader(label: 'Your Plans'),
            ...myPlans.map(
              (p) => _cardPadding(
                PlanCard(
                  plan: p,
                  isOwner: true,
                  onStart: () => context.push('/log?planId=${p.id}'),
                  onEdit: () => context.push('/plans/create?planId=${p.id}'),
                  onDelete: () => _confirmDelete(context, ref, p),
                ),
              ),
            ),
          ],
          if (friendPlans.isNotEmpty) ...[
            _SectionHeader(label: "Friends' Plans"),
            ...friendPlans.map(
              (p) => _cardPadding(
                PlanCard(
                  plan: p,
                  isOwner: false,
                  onStart: () => context.push('/log?planId=${p.id}'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cardPadding(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: child,
      );

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    WorkoutPlan plan,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete "${plan.name}"?', style: AppTextStyles.heading(16)),
        content: Text(
          'This cannot be undone.',
          style: AppTextStyles.body(14).copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(planProvider.notifier).delete(plan.id);
    }
  }
}

// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.bodySecondary(11),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _EmptyState({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.fitness_center, size: 52, color: AppColors.textDisabled),
          const SizedBox(height: AppSpacing.md),
          Text('No plans yet', style: AppTextStyles.heading(18)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Build a plan and share it with the group.',
            style: AppTextStyles.bodySecondary(14),
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton(
            onPressed: onCreateTap,
            child: const Text('Create Plan'),
          ),
        ],
      ),
    );
  }
}
