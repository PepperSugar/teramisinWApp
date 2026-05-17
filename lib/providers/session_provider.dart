import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/workout_session.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';

// ---------------------------------------------------------------------------
// All sessions — used by Feed and Leaderboard
// ---------------------------------------------------------------------------

class AllSessionsNotifier extends AsyncNotifier<List<WorkoutSession>> {
  @override
  Future<List<WorkoutSession>> build() => DatabaseService().getAllSessions();

  /// Pull every session from Firestore into local SQLite, then reload.
  /// Called on pull-to-refresh so friends' new sessions appear.
  Future<void> syncFromFirestore() async {
    try {
      final remote = await FirestoreService().getAllSessions();
      for (final s in remote) {
        await DatabaseService().upsertSession(s);
      }
    } catch (_) {
      // Network unavailable — keep local cache as-is.
    }
    ref.invalidateSelf();
  }
}

final allSessionsProvider =
    AsyncNotifierProvider<AllSessionsNotifier, List<WorkoutSession>>(
        AllSessionsNotifier.new);

// ---------------------------------------------------------------------------
// Sessions for a single user — used by History and Profile
// ---------------------------------------------------------------------------

final sessionProvider = FutureProvider.family<List<WorkoutSession>, String>(
  (ref, uid) => DatabaseService().getSessionsByUid(uid),
);
