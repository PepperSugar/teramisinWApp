import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/workout_session.dart';
import '../models/workout_plan.dart';
import '../models/exercise.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._();
  factory DatabaseService() => _instance;
  DatabaseService._();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'teramisin.db');
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sessions (
        id TEXT PRIMARY KEY,
        uid TEXT NOT NULL,
        data TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE plans (
        id TEXT PRIMARY KEY,
        uid TEXT NOT NULL,
        data TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE exercises (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE users (
        uid TEXT PRIMARY KEY,
        data TEXT NOT NULL
      )
    ''');

    // Seed default exercise library
    await _seedDefaultExercises(db);
  }

  // ---------------------------------------------------------------------------
  // Exercise seed data
  // ---------------------------------------------------------------------------

  static const List<Exercise> _kSeedExercises = [
    // Chest
    Exercise(id: 'ex_bench_press',         name: 'Bench Press',           muscleGroup: 'Chest',     isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_incline_bench_press',  name: 'Incline Bench Press',   muscleGroup: 'Chest',     isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_decline_bench_press',  name: 'Decline Bench Press',   muscleGroup: 'Chest',     isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_dumbbell_fly',         name: 'Dumbbell Fly',          muscleGroup: 'Chest',     isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_cable_fly',            name: 'Cable Fly',             muscleGroup: 'Chest',     isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_chest_dip',            name: 'Chest Dip',             muscleGroup: 'Chest',     isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_push_up',              name: 'Push-Up',               muscleGroup: 'Chest',     isCustom: false, createdBy: 'system'),
    // Back
    Exercise(id: 'ex_deadlift',             name: 'Deadlift',              muscleGroup: 'Back',      isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_pull_up',              name: 'Pull-Up',               muscleGroup: 'Back',      isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_lat_pulldown',         name: 'Lat Pulldown',          muscleGroup: 'Back',      isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_barbell_row',          name: 'Barbell Row',           muscleGroup: 'Back',      isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_dumbbell_row',         name: 'Dumbbell Row',          muscleGroup: 'Back',      isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_seated_cable_row',     name: 'Seated Cable Row',      muscleGroup: 'Back',      isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_t_bar_row',            name: 'T-Bar Row',             muscleGroup: 'Back',      isCustom: false, createdBy: 'system'),
    // Shoulders
    Exercise(id: 'ex_overhead_press',       name: 'Overhead Press',        muscleGroup: 'Shoulders', isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_db_shoulder_press',    name: 'Dumbbell Shoulder Press',muscleGroup: 'Shoulders',isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_lateral_raise',        name: 'Lateral Raise',         muscleGroup: 'Shoulders', isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_front_raise',          name: 'Front Raise',           muscleGroup: 'Shoulders', isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_face_pull',            name: 'Face Pull',             muscleGroup: 'Shoulders', isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_arnold_press',         name: 'Arnold Press',          muscleGroup: 'Shoulders', isCustom: false, createdBy: 'system'),
    // Legs
    Exercise(id: 'ex_squat',                name: 'Squat',                 muscleGroup: 'Legs',      isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_leg_press',            name: 'Leg Press',             muscleGroup: 'Legs',      isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_romanian_deadlift',    name: 'Romanian Deadlift',     muscleGroup: 'Legs',      isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_leg_extension',        name: 'Leg Extension',         muscleGroup: 'Legs',      isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_leg_curl',             name: 'Leg Curl',              muscleGroup: 'Legs',      isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_standing_calf_raise',  name: 'Standing Calf Raise',   muscleGroup: 'Legs',      isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_seated_calf_raise',    name: 'Seated Calf Raise',     muscleGroup: 'Legs',      isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_lunges',               name: 'Lunges',                muscleGroup: 'Legs',      isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_bulgarian_split_squat',name: 'Bulgarian Split Squat', muscleGroup: 'Legs',      isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_hack_squat',           name: 'Hack Squat',            muscleGroup: 'Legs',      isCustom: false, createdBy: 'system'),
    // Biceps
    Exercise(id: 'ex_barbell_curl',         name: 'Barbell Curl',          muscleGroup: 'Biceps',    isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_dumbbell_curl',        name: 'Dumbbell Curl',         muscleGroup: 'Biceps',    isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_hammer_curl',          name: 'Hammer Curl',           muscleGroup: 'Biceps',    isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_preacher_curl',        name: 'Preacher Curl',         muscleGroup: 'Biceps',    isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_cable_curl',           name: 'Cable Curl',            muscleGroup: 'Biceps',    isCustom: false, createdBy: 'system'),
    // Triceps
    Exercise(id: 'ex_tricep_dip',           name: 'Tricep Dip',            muscleGroup: 'Triceps',   isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_skull_crusher',        name: 'Skull Crusher',         muscleGroup: 'Triceps',   isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_tricep_pushdown',      name: 'Tricep Pushdown',       muscleGroup: 'Triceps',   isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_overhead_tricep_ext',  name: 'Overhead Tricep Extension',muscleGroup: 'Triceps',isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_close_grip_bench',     name: 'Close-Grip Bench Press',muscleGroup: 'Triceps',   isCustom: false, createdBy: 'system'),
    // Core
    Exercise(id: 'ex_plank',               name: 'Plank',                 muscleGroup: 'Core',      isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_crunch',              name: 'Crunch',                muscleGroup: 'Core',      isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_leg_raise',           name: 'Leg Raise',             muscleGroup: 'Core',      isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_cable_crunch',        name: 'Cable Crunch',          muscleGroup: 'Core',      isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_russian_twist',       name: 'Russian Twist',         muscleGroup: 'Core',      isCustom: false, createdBy: 'system'),
    // Cardio
    Exercise(id: 'ex_running',             name: 'Running',               muscleGroup: 'Cardio',    isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_rowing_machine',      name: 'Rowing Machine',        muscleGroup: 'Cardio',    isCustom: false, createdBy: 'system'),
    Exercise(id: 'ex_jump_rope',           name: 'Jump Rope',             muscleGroup: 'Cardio',    isCustom: false, createdBy: 'system'),
  ];

  Future<void> _seedDefaultExercises(Database db) async {
    final batch = db.batch();
    for (final e in _kSeedExercises) {
      batch.insert(
        'exercises',
        {'id': e.id, 'data': jsonEncode(e.toMap()), 'synced': 0},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  // ---------------------------------------------------------------------------
  // Sessions
  // ---------------------------------------------------------------------------

  Future<void> upsertSession(WorkoutSession session) async {
    final d = await db;
    await d.insert(
      'sessions',
      {'id': session.id, 'uid': session.uid, 'data': jsonEncode(session.toMap()), 'synced': 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<WorkoutSession>> getSessionsByUid(String uid) async {
    final d = await db;
    final rows = await d.query('sessions', where: 'uid = ?', whereArgs: [uid], orderBy: 'rowid DESC');
    return rows.map((r) => WorkoutSession.fromMap(jsonDecode(r['data'] as String) as Map<String, dynamic>)).toList();
  }

  Future<List<WorkoutSession>> getAllSessions() async {
    final d = await db;
    final rows = await d.query('sessions', orderBy: 'rowid DESC');
    return rows.map((r) => WorkoutSession.fromMap(jsonDecode(r['data'] as String) as Map<String, dynamic>)).toList();
  }

  Future<void> deleteSession(String id) async {
    final d = await db;
    await d.delete('sessions', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------------
  // Plans
  // ---------------------------------------------------------------------------

  Future<void> upsertPlan(WorkoutPlan plan) async {
    final d = await db;
    await d.insert(
      'plans',
      {'id': plan.id, 'uid': plan.uid, 'data': jsonEncode(plan.toMap()), 'synced': 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<WorkoutPlan>> getAllPlans() async {
    final d = await db;
    final rows = await d.query('plans', orderBy: 'rowid DESC');
    return rows.map((r) => WorkoutPlan.fromMap(jsonDecode(r['data'] as String) as Map<String, dynamic>)).toList();
  }

  Future<void> deletePlan(String id) async {
    final d = await db;
    await d.delete('plans', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------------
  // Exercises
  // ---------------------------------------------------------------------------

  Future<void> upsertExercise(Exercise exercise) async {
    final d = await db;
    await d.insert(
      'exercises',
      {'id': exercise.id, 'data': jsonEncode(exercise.toMap()), 'synced': 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Exercise>> getAllExercises() async {
    final d = await db;
    final rows = await d.query('exercises', orderBy: 'id ASC');
    return rows.map((r) => Exercise.fromMap(jsonDecode(r['data'] as String) as Map<String, dynamic>)).toList();
  }

  /// Returns exercises from local DB, seeding defaults if the table is empty.
  /// Handles the case where the DB was created before seed data was added.
  Future<List<Exercise>> getOrSeedExercises() async {
    final existing = await getAllExercises();
    if (existing.isNotEmpty) return existing;
    await _seedDefaultExercises(await db);
    return getAllExercises();
  }

  Future<void> deleteExercise(String id) async {
    final d = await db;
    await d.delete('exercises', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------------
  // Sync helpers
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getUnsynced(String table) async {
    final d = await db;
    return d.query(table, where: 'synced = ?', whereArgs: [0]);
  }

  Future<void> markSynced(String table, String id) async {
    final d = await db;
    await d.update(table, {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }
}
