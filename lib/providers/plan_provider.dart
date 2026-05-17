import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/workout_plan.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';

class PlanNotifier extends AsyncNotifier<List<WorkoutPlan>> {
  @override
  Future<List<WorkoutPlan>> build() => DatabaseService().getAllPlans();

  /// Save (create or update) a plan locally and push to Firestore in the background.
  Future<void> save(WorkoutPlan plan) async {
    await DatabaseService().upsertPlan(plan);
    // Fire-and-forget — if offline this will fail silently; sync handles it later.
    FirestoreService().upsertPlan(plan).ignore();
    ref.invalidateSelf();
  }

  /// Delete a plan locally and remove from Firestore in the background.
  Future<void> delete(String id) async {
    await DatabaseService().deletePlan(id);
    FirestoreService().deletePlan(id).ignore();
    ref.invalidateSelf();
  }

  /// Pull all plans from Firestore into local SQLite, then reload.
  /// Called on pull-to-refresh so friends' newly created plans appear.
  Future<void> syncFromFirestore() async {
    try {
      final remote = await FirestoreService().getAllPlans();
      for (final p in remote) {
        await DatabaseService().upsertPlan(p);
      }
    } catch (_) {
      // Network unavailable — just reload from local cache below.
    }
    ref.invalidateSelf();
  }
}

final planProvider =
    AsyncNotifierProvider<PlanNotifier, List<WorkoutPlan>>(PlanNotifier.new);
