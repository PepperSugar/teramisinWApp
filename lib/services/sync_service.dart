import 'dart:convert';
import '../models/workout_session.dart';
import '../models/workout_plan.dart';
import '../models/exercise.dart';
import 'database_service.dart';
import 'firestore_service.dart';

class SyncService {
  final _local = DatabaseService();
  final _remote = FirestoreService();

  /// Push all locally unsynced records to Firestore.
  Future<void> pushPending() async {
    await Future.wait([
      _pushSessions(),
      _pushPlans(),
      _pushExercises(),
    ]);
  }

  /// Pull latest data from Firestore into SQLite.
  Future<void> pullAll() async {
    final sessions = await _remote.getAllSessions();
    for (final s in sessions) {
      await _local.upsertSession(s);
    }

    final plans = await _remote.getAllPlans();
    for (final p in plans) {
      await _local.upsertPlan(p);
    }

    final exercises = await _remote.getAllExercises();
    for (final e in exercises) {
      await _local.upsertExercise(e);
    }
  }

  Future<void> _pushSessions() async {
    final rows = await _local.getUnsynced('sessions');
    for (final row in rows) {
      final session = WorkoutSession.fromMap(
        jsonDecode(row['data'] as String) as Map<String, dynamic>,
      );
      await _remote.upsertSession(session);
      await _local.markSynced('sessions', session.id);
    }
  }

  Future<void> _pushPlans() async {
    final rows = await _local.getUnsynced('plans');
    for (final row in rows) {
      final plan = WorkoutPlan.fromMap(
        jsonDecode(row['data'] as String) as Map<String, dynamic>,
      );
      await _remote.upsertPlan(plan);
      await _local.markSynced('plans', plan.id);
    }
  }

  Future<void> _pushExercises() async {
    final rows = await _local.getUnsynced('exercises');
    for (final row in rows) {
      final exercise = Exercise.fromMap(
        jsonDecode(row['data'] as String) as Map<String, dynamic>,
      );
      await _remote.upsertExercise(exercise);
      await _local.markSynced('exercises', exercise.id);
    }
  }
}
