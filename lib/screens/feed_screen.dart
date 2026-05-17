import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../constants/colors.dart';
import '../constants/theme.dart';
import '../models/workout_session.dart';
import '../providers/session_provider.dart';

// ---------------------------------------------------------------------------
// Feed screen — days of the week, who worked out, expandable details
// ---------------------------------------------------------------------------

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  // Which day indices are expanded (index 3 = today)
  final Set<int> _expanded = {3};

  @override
  Widget build(BuildContext context) {
    final asyncSessions = ref.watch(allSessionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Feed', style: AppTextStyles.heading(20)),
        centerTitle: false,
      ),
      body: asyncSessions.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, st) => Center(
          child: Text('Failed to load sessions',
              style: AppTextStyles.body(14)
                  .copyWith(color: AppColors.textSecondary)),
        ),
        data: (sessions) => _FeedBody(
          sessions: sessions,
          expanded: _expanded,
          onToggle: (i) => setState(() {
            if (_expanded.contains(i)) {
              _expanded.remove(i);
            } else {
              _expanded.add(i);
            }
          }),
          onRefresh: () async {
            await ref.read(allSessionsProvider.notifier).syncFromFirestore();
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body — handles grouping and the list
// ---------------------------------------------------------------------------

class _FeedBody extends StatelessWidget {
  final List<WorkoutSession> sessions;
  final Set<int> expanded;
  final void Function(int) onToggle;
  final Future<void> Function() onRefresh;

  const _FeedBody({
    required this.sessions,
    required this.expanded,
    required this.onToggle,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    // Build list: 3 days ago → today → 3 days ahead (index 0 = 3 days ago, index 3 = today)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = List.generate(7, (i) => today.subtract(Duration(days: 3 - i)));

    // Group sessions by calendar date
    Map<String, List<WorkoutSession>> byDate = {};
    for (final s in sessions) {
      final key = _dateKey(s.date);
      byDate.putIfAbsent(key, () => []).add(s);
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        itemCount: days.length,
        itemBuilder: (context, i) {
          final date = days[i];
          final key = _dateKey(date);
          final daySessions = byDate[key] ?? [];
          final isExpanded = expanded.contains(i);

          return _DaySection(
            date: date,
            isToday: i == 3,
            sessions: daySessions,
            isExpanded: isExpanded,
            onToggle: () => onToggle(i),
          );
        },
      ),
    );
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ---------------------------------------------------------------------------
// A single day row + expandable session cards
// ---------------------------------------------------------------------------

class _DaySection extends StatelessWidget {
  final DateTime date;
  final bool isToday;
  final List<WorkoutSession> sessions;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _DaySection({
    required this.date,
    required this.isToday,
    required this.sessions,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final hasActivity = sessions.isNotEmpty;
    final dayLabel = isToday
        ? 'Today'
        : DateFormat('EEEE').format(date); // e.g. "Monday"
    final dateLabel = DateFormat('MMM d').format(date); // e.g. "May 12"

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day header row — tappable if there's activity
          GestureDetector(
            onTap: hasActivity ? onToggle : null,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  // Date label
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dayLabel,
                        style: AppTextStyles.body(14).copyWith(
                          color: isToday
                              ? AppColors.primary
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(dateLabel,
                          style: AppTextStyles.bodySecondary(12)),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.md),

                  // Avatar row or rest day label
                  if (!hasActivity)
                    Text(
                      'Rest day',
                      style: AppTextStyles.bodySecondary(13)
                          .copyWith(color: AppColors.textDisabled),
                    )
                  else
                    Expanded(
                      child: Wrap(
                        spacing: AppSpacing.xs,
                        children: sessions
                            .map((s) => _AvatarChip(
                                  name: s.displayName,
                                ))
                            .toList(),
                      ),
                    ),

                  if (hasActivity) ...[
                    const Spacer(),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Expanded session cards
          if (isExpanded && hasActivity)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Column(
                children: sessions
                    .map((s) => _SessionCard(session: s))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Session detail card — name, plan, per-exercise set counts
// ---------------------------------------------------------------------------

class _SessionCard extends StatelessWidget {
  final WorkoutSession session;

  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/profile/${session.uid}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            _AvatarCircle(name: session.displayName, radius: 18),
            const SizedBox(width: AppSpacing.sm),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User name + plan name
                  Row(
                    children: [
                      Text(
                        session.displayName,
                        style: AppTextStyles.body(14)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (session.planName != null) ...[
                        Text(
                          '  ·  ',
                          style: AppTextStyles.bodySecondary(14),
                        ),
                        Expanded(
                          child: Text(
                            session.planName!,
                            style: AppTextStyles.bodySecondary(13)
                                .copyWith(color: AppColors.primary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),

                  // Per-exercise set counts
                  ...session.exercises.map((ex) {
                    final completedSets =
                        ex.sets.where((s) => s.completed).length;
                    final totalSets = ex.sets.length;
                    return Padding(
                      padding:
                          const EdgeInsets.only(bottom: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              ex.exerciseName,
                              style: AppTextStyles.body(13).copyWith(
                                  color: AppColors.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '$completedSets${completedSets != totalSets ? '/$totalSets' : ''} ${completedSets == 1 ? 'set' : 'sets'}',
                            style: AppTextStyles.body(13).copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Avatar circle with first initial + deterministic color
// ---------------------------------------------------------------------------

class _AvatarCircle extends StatelessWidget {
  final String name;
  final double radius;

  const _AvatarCircle({required this.name, this.radius = 16});

  @override
  Widget build(BuildContext context) {
    final initial =
        name.isNotEmpty ? name[0].toUpperCase() : '?';
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
    Color(0xFF4ADE80), // green
    Color(0xFF60A5FA), // blue
    Color(0xFFF472B6), // pink
    Color(0xFFFBBF24), // amber
    Color(0xFFA78BFA), // violet
    Color(0xFF34D399), // emerald
    Color(0xFFFB923C), // orange
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

// ---------------------------------------------------------------------------
// Small avatar chip shown in the collapsed day header
// ---------------------------------------------------------------------------

class _AvatarChip extends StatelessWidget {
  final String name;

  const _AvatarChip({required this.name});

  @override
  Widget build(BuildContext context) {
    return _AvatarCircle(name: name, radius: 13);
  }
}
