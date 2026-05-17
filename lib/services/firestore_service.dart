import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/workout_session.dart';
import '../models/workout_plan.dart';
import '../models/exercise.dart';
import '../models/user_model.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  // Users
  Future<void> upsertUser(UserModel user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  Future<List<UserModel>> getUsers() async {
    final snap = await _db.collection('users').get();
    return snap.docs.map((d) => UserModel.fromMap(d.data())).toList();
  }

  // Sessions
  Future<void> upsertSession(WorkoutSession session) async {
    await _db.collection('sessions').doc(session.id).set(session.toMap());
  }

  Future<List<WorkoutSession>> getSessionsByUid(String uid) async {
    final snap = await _db
        .collection('sessions')
        .where('uid', isEqualTo: uid)
        .orderBy('date', descending: true)
        .get();
    return snap.docs.map((d) => WorkoutSession.fromMap(d.data())).toList();
  }

  Future<List<WorkoutSession>> getAllSessions() async {
    final snap = await _db
        .collection('sessions')
        .orderBy('date', descending: true)
        .get();
    return snap.docs.map((d) => WorkoutSession.fromMap(d.data())).toList();
  }

  Future<void> deleteSession(String id) async {
    await _db.collection('sessions').doc(id).delete();
  }

  // Plans
  Future<void> upsertPlan(WorkoutPlan plan) async {
    await _db.collection('plans').doc(plan.id).set(plan.toMap());
  }

  Future<List<WorkoutPlan>> getAllPlans() async {
    final snap = await _db
        .collection('plans')
        .orderBy('updatedAt', descending: true)
        .get();
    return snap.docs.map((d) => WorkoutPlan.fromMap(d.data())).toList();
  }

  Future<void> deletePlan(String id) async {
    await _db.collection('plans').doc(id).delete();
  }

  // Exercises
  Future<void> upsertExercise(Exercise exercise) async {
    await _db.collection('exercises').doc(exercise.id).set(exercise.toMap());
  }

  Future<List<Exercise>> getAllExercises() async {
    final snap = await _db.collection('exercises').get();
    return snap.docs.map((d) => Exercise.fromMap(d.data())).toList();
  }

  // Leaderboard: top sessions for a given exercise ordered by maxWeightKg
  Future<List<WorkoutSession>> getLeaderboardSessions(String exerciseId) async {
    final snap = await _db
        .collectionGroup('sessions')
        .where('exercises', arrayContains: {'exerciseId': exerciseId})
        .orderBy('totalVolumeKg', descending: true)
        .limit(50)
        .get();
    return snap.docs.map((d) => WorkoutSession.fromMap(d.data())).toList();
  }
}
