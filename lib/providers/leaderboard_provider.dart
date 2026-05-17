import '../models/workout_session.dart';
import '../models/set_model.dart';

// ---------------------------------------------------------------------------
// Leaderboard filter options
// ---------------------------------------------------------------------------

enum LeaderboardFilter {
  totalSets,
  totalReps,
  totalWeight,
  daysLogged,
}

extension LeaderboardFilterLabel on LeaderboardFilter {
  String get label {
    switch (this) {
      case LeaderboardFilter.totalSets:
        return 'Total Sets';
      case LeaderboardFilter.totalReps:
        return 'Total Reps';
      case LeaderboardFilter.totalWeight:
        return 'Total Weight';
      case LeaderboardFilter.daysLogged:
        return 'Days Logged';
    }
  }

  String get unit {
    switch (this) {
      case LeaderboardFilter.totalSets:
        return 'sets';
      case LeaderboardFilter.totalReps:
        return 'reps';
      case LeaderboardFilter.totalWeight:
        return 'kg';
      case LeaderboardFilter.daysLogged:
        return 'days';
    }
  }
}

// ---------------------------------------------------------------------------
// Per-user aggregated stats
// ---------------------------------------------------------------------------

class UserStats {
  final String uid;
  final String displayName;
  final int totalSets;
  final int totalReps;
  final double totalWeightKg;
  final int daysLogged;

  const UserStats({
    required this.uid,
    required this.displayName,
    required this.totalSets,
    required this.totalReps,
    required this.totalWeightKg,
    required this.daysLogged,
  });

  num valueFor(LeaderboardFilter filter) {
    switch (filter) {
      case LeaderboardFilter.totalSets:
        return totalSets;
      case LeaderboardFilter.totalReps:
        return totalReps;
      case LeaderboardFilter.totalWeight:
        return totalWeightKg;
      case LeaderboardFilter.daysLogged:
        return daysLogged;
    }
  }
}

// ---------------------------------------------------------------------------
// Provider: derive UserStats list from allSessionsProvider
// ---------------------------------------------------------------------------

// Takes the raw session list and returns ranked UserStats for a given filter.
// Computed synchronously from already-loaded sessions — no extra fetch needed.
UserStats _statsFromSessions(String uid, String displayName,
    List<WorkoutSession> sessions) {
  int sets = 0;
  int reps = 0;
  double weight = 0;
  final uniqueDays = <String>{};

  for (final s in sessions) {
    final dayKey =
        '${s.date.year}-${s.date.month}-${s.date.day}';
    uniqueDays.add(dayKey);

    for (final ex in s.exercises) {
      for (final SetModel set in ex.sets) {
        if (set.completed) {
          sets++;
          reps += set.reps;
          weight += set.reps * set.weightKg;
        }
      }
    }
  }

  return UserStats(
    uid: uid,
    displayName: displayName,
    totalSets: sets,
    totalReps: reps,
    totalWeightKg: weight,
    daysLogged: uniqueDays.length,
  );
}

// Derives a ranked list from a flat session list (already loaded).
List<UserStats> computeLeaderboard(
    List<WorkoutSession> sessions, LeaderboardFilter filter) {
  // Group sessions by uid
  final Map<String, List<WorkoutSession>> byUser = {};
  final Map<String, String> nameForUid = {};

  for (final s in sessions) {
    byUser.putIfAbsent(s.uid, () => []).add(s);
    nameForUid[s.uid] = s.displayName;
  }

  final stats = byUser.entries
      .map((e) => _statsFromSessions(e.key, nameForUid[e.key]!, e.value))
      .toList();

  stats.sort((a, b) => b.valueFor(filter).compareTo(a.valueFor(filter)));
  return stats;
}
