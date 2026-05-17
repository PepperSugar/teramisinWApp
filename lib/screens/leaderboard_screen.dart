import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/colors.dart';
import '../constants/theme.dart';
import '../providers/session_provider.dart';
import '../providers/leaderboard_provider.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  LeaderboardFilter _filter = LeaderboardFilter.totalSets;

  @override
  Widget build(BuildContext context) {
    final asyncSessions = ref.watch(allSessionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Leaderboard', style: AppTextStyles.heading(20)),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Filter chips
          _FilterBar(
            selected: _filter,
            onSelected: (f) => setState(() => _filter = f),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Ranked list
          Expanded(
            child: asyncSessions.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (e, st) => Center(
                child: Text(
                  'Failed to load data',
                  style: AppTextStyles.body(14)
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
              data: (sessions) {
                final ranked = computeLeaderboard(sessions, _filter);

                if (ranked.isEmpty) {
                  return Center(
                    child: Text(
                      'No workouts logged yet',
                      style: AppTextStyles.body(14)
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  );
                }

                return RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  onRefresh: () async {
                    await ref
                        .read(allSessionsProvider.notifier)
                        .syncFromFirestore();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                    itemCount: ranked.length,
                    itemBuilder: (context, i) => _LeaderboardRow(
                      rank: i + 1,
                      stats: ranked[i],
                      filter: _filter,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter chip bar
// ---------------------------------------------------------------------------

class _FilterBar extends StatelessWidget {
  final LeaderboardFilter selected;
  final void Function(LeaderboardFilter) onSelected;

  const _FilterBar({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: LeaderboardFilter.values.map((f) {
          final isSelected = f == selected;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: GestureDetector(
              onTap: () => onSelected(f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
                decoration: BoxDecoration(
                  color:
                      isSelected ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                ),
                child: Text(
                  f.label,
                  style: AppTextStyles.body(13).copyWith(
                    color: isSelected
                        ? AppColors.background
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single ranked row
// ---------------------------------------------------------------------------

class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final UserStats stats;
  final LeaderboardFilter filter;

  const _LeaderboardRow({
    required this.rank,
    required this.stats,
    required this.filter,
  });

  @override
  Widget build(BuildContext context) {
    final value = stats.valueFor(filter);
    final displayValue = filter == LeaderboardFilter.totalWeight
        ? '${_formatWeight(value as double)} ${filter.unit}'
        : '${value.toInt()} ${filter.unit}';

    return GestureDetector(
      onTap: () => context.push('/profile/${stats.uid}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: rank <= 3 ? _rankBorderColor(rank) : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            // Rank badge
            SizedBox(
              width: 32,
              child: rank <= 3
                  ? _MedalBadge(rank: rank)
                  : Text(
                      '$rank',
                      style: AppTextStyles.body(14).copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
            ),
            const SizedBox(width: AppSpacing.sm),

            // Avatar
            _AvatarCircle(name: stats.displayName, radius: 18),
            const SizedBox(width: AppSpacing.sm),

            // Name
            Expanded(
              child: Text(
                stats.displayName,
                style: AppTextStyles.body(15)
                    .copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Stat value
            Text(
              displayValue,
              style: AppTextStyles.stat(15)
                  .copyWith(color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  Color _rankBorderColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // gold
      case 2:
        return const Color(0xFFC0C0C0); // silver
      case 3:
        return const Color(0xFFCD7F32); // bronze
      default:
        return AppColors.border;
    }
  }

  String _formatWeight(double kg) {
    if (kg >= 1000) {
      return '${(kg / 1000).toStringAsFixed(1)}k';
    }
    return kg.toStringAsFixed(1);
  }
}

// ---------------------------------------------------------------------------
// Medal badge for top 3
// ---------------------------------------------------------------------------

class _MedalBadge extends StatelessWidget {
  final int rank;
  const _MedalBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    final color = switch (rank) {
      1 => const Color(0xFFFFD700),
      2 => const Color(0xFFC0C0C0),
      _ => const Color(0xFFCD7F32),
    };
    return Text(
      switch (rank) { 1 => '1st', 2 => '2nd', _ => '3rd' },
      style: AppTextStyles.body(12).copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
      textAlign: TextAlign.center,
    );
  }
}

// ---------------------------------------------------------------------------
// Avatar circle (same pattern as Feed screen)
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
