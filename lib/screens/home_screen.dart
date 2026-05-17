import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/colors.dart';
import '../constants/theme.dart';
import '../models/workout_session.dart';
import '../models/workout_plan.dart';
import '../providers/auth_provider.dart';
import '../providers/plan_provider.dart';
import '../providers/session_provider.dart';

// ---------------------------------------------------------------------------
// Home screen
// ---------------------------------------------------------------------------

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);

    return authAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      error: (e, st) =>
          const Scaffold(backgroundColor: AppColors.background),
      data: (user) {
        if (user == null) {
          return const Scaffold(backgroundColor: AppColors.background);
        }

        final sessionsAsync = ref.watch(sessionProvider(user.uid));
        final displayName = user.displayName ?? 'Athlete';
        final firstName = displayName.split(' ').first;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            title:
                Text(_greeting(firstName), style: AppTextStyles.heading(20)),
            centerTitle: false,
          ),
          body: sessionsAsync.when(
            loading: () => const Center(
                child:
                    CircularProgressIndicator(color: AppColors.primary)),
            error: (e, st) => Center(
              child: Text('Failed to load data',
                  style: AppTextStyles.body(14)
                      .copyWith(color: AppColors.textSecondary)),
            ),
            data: (sessions) => _HomeBody(
              displayName: displayName,
              uid: user.uid,
              sessions: sessions,
            ),
          ),
        );
      },
    );
  }

  static String _greeting(String firstName) {
    final hour = DateTime.now().hour;
    final part = hour < 12
        ? 'morning'
        : hour < 17
            ? 'afternoon'
            : 'evening';
    return 'Good $part, $firstName';
  }
}

// ---------------------------------------------------------------------------
// Body — all computed stats live here
// ---------------------------------------------------------------------------

class _HomeBody extends StatelessWidget {
  final String displayName;
  final String uid;
  final List<WorkoutSession> sessions;

  const _HomeBody({
    required this.displayName,
    required this.uid,
    required this.sessions,
  });

  @override
  Widget build(BuildContext context) {
    final streak = _computeStreak(sessions);
    final totalSeconds =
        sessions.fold<int>(0, (sum, s) => sum + s.durationSeconds);
    final totalSessions = sessions.length;
    final lastSession =
        sessions.isEmpty ? null : _mostRecent(sessions);
    final loggedDaysThisWeek = _loggedDaysThisWeek(sessions);

    return ListView(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      children: [
        // ---- Profile + streak card ----
        _ProfileCard(
          displayName: displayName,
          streak: streak,
        ),
        const SizedBox(height: AppSpacing.sm),

        // ---- Quick start ----
        _QuickStart(uid: uid),
        const SizedBox(height: AppSpacing.md),

        // ---- Stats row ----
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Sessions',
                value: '$totalSessions',
                unit: totalSessions == 1 ? 'workout' : 'workouts',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatCard(
                label: 'Time logged',
                value: _formatDuration(totalSeconds),
                unit: '',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // ---- This week ----
        _SectionHeader(title: 'This week'),
        const SizedBox(height: AppSpacing.xs),
        _WeekDots(loggedDays: loggedDaysThisWeek),
        const SizedBox(height: AppSpacing.md),

        // ---- Last workout ----
        _SectionHeader(title: 'Last workout'),
        const SizedBox(height: AppSpacing.xs),
        if (lastSession == null)
          _EmptyLastWorkout()
        else
          _LastWorkoutCard(session: lastSession),

        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  // ---- Helpers ----

  /// Returns the number of unique workout days in the current unbroken chain.
  /// The chain breaks when there is a gap of 4+ days between any two
  /// consecutive logged days (or between the most recent log and today).
  static int _computeStreak(List<WorkoutSession> sessions) {
    if (sessions.isEmpty) return 0;

    // Unique calendar days, sorted newest → oldest
    final days = sessions
        .map((s) => DateTime(s.date.year, s.date.month, s.date.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // If the most recent workout was 4+ days ago the streak is broken
    if (today.difference(days.first).inDays >= 4) return 0;

    int streak = 1;
    for (int i = 1; i < days.length; i++) {
      final gap = days[i - 1].difference(days[i]).inDays;
      if (gap >= 4) break;
      streak++;
    }
    return streak;
  }

  static WorkoutSession _mostRecent(List<WorkoutSession> sessions) {
    return sessions.reduce(
        (a, b) => a.date.isAfter(b.date) ? a : b);
  }

  /// Returns the set of weekday indices (1=Mon … 7=Sun) that have a session
  /// in the current Mon–Sun week.
  static Set<int> _loggedDaysThisWeek(List<WorkoutSession> sessions) {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));

    final logged = <int>{};
    for (final s in sessions) {
      final d = DateTime(s.date.year, s.date.month, s.date.day);
      if (!d.isBefore(monday) && !d.isAfter(sunday)) {
        logged.add(d.weekday); // 1=Mon … 7=Sun
      }
    }
    return logged;
  }

  static String _formatDuration(int totalSeconds) {
    if (totalSeconds == 0) return '0 min';
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    if (h == 0) return '${m}min';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}

// ---------------------------------------------------------------------------
// Profile + streak card
// ---------------------------------------------------------------------------

class _ProfileCard extends StatelessWidget {
  final String displayName;
  final int streak;

  const _ProfileCard({required this.displayName, required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Avatar
          _AvatarCircle(name: displayName, radius: 26),
          const SizedBox(width: AppSpacing.md),

          // Name + streak
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName,
                    style: AppTextStyles.heading(17),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                if (streak > 0)
                  Row(
                    children: [
                      Icon(Icons.local_fire_department,
                          color: AppColors.primary, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '$streak ${streak == 1 ? 'day' : 'day'} streak',
                        style: AppTextStyles.body(13)
                            .copyWith(color: AppColors.primary),
                      ),
                    ],
                  )
                else
                  Text(
                    'No active streak — log a workout to start one',
                    style: AppTextStyles.bodySecondary(12),
                  ),
              ],
            ),
          ),

          // Large streak number
          if (streak > 0)
            Column(
              children: [
                Text(
                  '$streak',
                  style: AppTextStyles.stat(32)
                      .copyWith(color: AppColors.primary),
                ),
                Text('streak', style: AppTextStyles.bodySecondary(11)),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stat card (sessions / time)
// ---------------------------------------------------------------------------

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _StatCard(
      {required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.bodySecondary(12)),
          const SizedBox(height: 2),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                    text: value,
                    style: AppTextStyles.stat(22)
                        .copyWith(color: AppColors.primary)),
                if (unit.isNotEmpty)
                  TextSpan(
                      text: ' $unit',
                      style: AppTextStyles.bodySecondary(12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// This week — Mon through Sun dots
// ---------------------------------------------------------------------------

class _WeekDots extends StatelessWidget {
  final Set<int> loggedDays; // 1=Mon … 7=Sun

  const _WeekDots({required this.loggedDays});

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayWeekday = now.weekday; // 1=Mon … 7=Sun

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (i) {
          final weekday = i + 1; // 1=Mon … 7=Sun
          final logged = loggedDays.contains(weekday);
          final isToday = weekday == todayWeekday;

          return Column(
            children: [
              Text(
                _labels[i],
                style: AppTextStyles.bodySecondary(11).copyWith(
                  color: isToday
                      ? AppColors.textPrimary
                      : AppColors.textDisabled,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: logged ? AppColors.primary : AppColors.surfaceAlt,
                  border: isToday
                      ? Border.all(color: AppColors.primary, width: 1.5)
                      : null,
                ),
                child: logged
                    ? const Icon(Icons.check,
                        color: AppColors.background, size: 14)
                    : null,
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Last workout card
// ---------------------------------------------------------------------------

class _LastWorkoutCard extends StatelessWidget {
  final WorkoutSession session;

  const _LastWorkoutCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final daysAgo = DateTime.now()
        .difference(session.date)
        .inDays;
    final timeLabel = daysAgo == 0
        ? 'Today'
        : daysAgo == 1
            ? 'Yesterday'
            : '$daysAgo days ago';

    final durationMin = (session.durationSeconds / 60).round();
    final planLabel = session.planName ?? 'Free workout';

    return GestureDetector(
      onTap: () => context.push('/history'),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plan name + timestamp
            Row(
              children: [
                Expanded(
                  child: Text(planLabel,
                      style: AppTextStyles.body(15)
                          .copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '$timeLabel · ${durationMin}min',
                  style: AppTextStyles.bodySecondary(12),
                ),
              ],
            ),

            if (session.exercises.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: AppSpacing.xs),

              // Exercise list
              ...session.exercises.map((ex) {
                final completedSets =
                    ex.sets.where((s) => s.completed).length;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(ex.exerciseName,
                            style: AppTextStyles.body(13).copyWith(
                                color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis),
                      ),
                      Text(
                        '$completedSets ${completedSets == 1 ? 'set' : 'sets'}',
                        style: AppTextStyles.body(13)
                            .copyWith(color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'View history',
                  style: AppTextStyles.bodySecondary(12)
                      .copyWith(color: AppColors.primary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyLastWorkout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Text(
          'No workouts logged yet. Hit the Log tab to get started.',
          style:
              AppTextStyles.bodySecondary(13).copyWith(color: AppColors.textDisabled),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick start
// ---------------------------------------------------------------------------

class _QuickStart extends ConsumerWidget {
  final String uid;
  const _QuickStart({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        // Quick Log — no plan, blank session
        Expanded(
          child: _QuickButton(
            icon: Icons.add_circle_outline,
            label: 'Quick Log',
            onTap: () => context.push('/log'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Start from Plan — pick a plan first
        Expanded(
          child: _QuickButton(
            icon: Icons.list_alt_outlined,
            label: 'Start from Plan',
            filled: true,
            onTap: () => _showPlanPicker(context, ref),
          ),
        ),
      ],
    );
  }

  Future<void> _showPlanPicker(BuildContext context, WidgetRef ref) async {
    final plansAsync = ref.read(planProvider);

    // While plans are loading show a brief loading indicator in the sheet
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => _PlanPickerSheet(
        plansAsync: plansAsync,
        uid: uid,
        onPlanSelected: (plan) {
          Navigator.of(context).pop();
          context.push('/log?planId=${plan.id}');
        },
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _QuickButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm + 2, horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: filled ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: filled ? AppColors.background : AppColors.primary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: AppTextStyles.body(13).copyWith(
                color: filled ? AppColors.background : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Bottom sheet that lists plans to pick from
class _PlanPickerSheet extends StatelessWidget {
  final AsyncValue<List<WorkoutPlan>> plansAsync;
  final String uid;
  final void Function(WorkoutPlan) onPlanSelected;

  const _PlanPickerSheet({
    required this.plansAsync,
    required this.uid,
    required this.onPlanSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
            child: Text('Choose a plan', style: AppTextStyles.heading(17)),
          ),
          const Divider(color: AppColors.border, height: 1),
          plansAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary)),
            ),
            error: (e, st) => Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text('Could not load plans',
                  style: AppTextStyles.bodySecondary(13)),
            ),
            data: (plans) {
              if (plans.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    'No plans yet. Create one in the Plans tab.',
                    style: AppTextStyles.bodySecondary(13)
                        .copyWith(color: AppColors.textDisabled),
                  ),
                );
              }

              // Show your plans first, then friends'
              final mine = plans.where((p) => p.uid == uid).toList();
              final others = plans.where((p) => p.uid != uid).toList();
              final sorted = [...mine, ...others];

              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs),
                  itemCount: sorted.length,
                  separatorBuilder: (_, i) =>
                      const Divider(color: AppColors.border, height: 1),
                  itemBuilder: (_, i) {
                    final plan = sorted[i];
                    final isOwn = plan.uid == uid;
                    return ListTile(
                      tileColor: Colors.transparent,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs),
                      title: Text(plan.name,
                          style: AppTextStyles.body(14)
                              .copyWith(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${plan.exercises.length} exercise${plan.exercises.length == 1 ? '' : 's'}${isOwn ? '' : ' · ${plan.displayName}'}',
                        style: AppTextStyles.bodySecondary(12),
                      ),
                      trailing: const Icon(Icons.chevron_right,
                          color: AppColors.textSecondary, size: 20),
                      onTap: () => onPlanSelected(plan),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: AppTextStyles.bodySecondary(11).copyWith(
        letterSpacing: 1.0,
        color: AppColors.textDisabled,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Avatar circle (consistent with Feed + Leaderboard)
// ---------------------------------------------------------------------------

class _AvatarCircle extends StatelessWidget {
  final String name;
  final double radius;

  const _AvatarCircle({required this.name, this.radius = 16});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final color = _colorForName(name);
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        initial,
        style: AppTextStyles.body(radius * 0.85).copyWith(
          color: AppColors.background,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static const _palette = [
    Color(0xFF4ADE80),
    Color(0xFF60A5FA),
    Color(0xFFF472B6),
    Color(0xFFFBBF24),
    Color(0xFFA78BFA),
    Color(0xFF34D399),
    Color(0xFFFB923C),
  ];

  static Color _colorForName(String name) {
    if (name.isEmpty) return _palette[0];
    int hash = 0;
    for (final c in name.runes) {
      hash = (hash * 31 + c) & 0x7fffffff;
    }
    return _palette[hash % _palette.length];
  }
}
