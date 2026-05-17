import 'exercise_log.dart';

class WorkoutSession {
  final String id;
  final String uid;
  final String displayName;
  final String? planId;
  final String? planName;
  final DateTime date;
  final int durationSeconds;
  final List<ExerciseLog> exercises;
  final double totalVolumeKg;

  const WorkoutSession({
    required this.id,
    required this.uid,
    required this.displayName,
    this.planId,
    this.planName,
    required this.date,
    required this.durationSeconds,
    required this.exercises,
    required this.totalVolumeKg,
  });

  WorkoutSession copyWith({
    String? id,
    String? uid,
    String? displayName,
    String? planId,
    String? planName,
    DateTime? date,
    int? durationSeconds,
    List<ExerciseLog>? exercises,
    double? totalVolumeKg,
  }) {
    return WorkoutSession(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      planId: planId ?? this.planId,
      planName: planName ?? this.planName,
      date: date ?? this.date,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      exercises: exercises ?? this.exercises,
      totalVolumeKg: totalVolumeKg ?? this.totalVolumeKg,
    );
  }

  factory WorkoutSession.fromMap(Map<String, dynamic> map) {
    return WorkoutSession(
      id: map['id'] as String,
      uid: map['uid'] as String,
      displayName: map['displayName'] as String,
      planId: map['planId'] as String?,
      planName: map['planName'] as String?,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      durationSeconds: map['durationSeconds'] as int,
      exercises: (map['exercises'] as List<dynamic>)
          .map((e) => ExerciseLog.fromMap(e as Map<String, dynamic>))
          .toList(),
      totalVolumeKg: (map['totalVolumeKg'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'displayName': displayName,
      'planId': planId,
      'planName': planName,
      'date': date.millisecondsSinceEpoch,
      'durationSeconds': durationSeconds,
      'exercises': exercises.map((e) => e.toMap()).toList(),
      'totalVolumeKg': totalVolumeKg,
    };
  }

  static double computeTotalVolume(List<ExerciseLog> exercises) {
    return exercises
        .expand((e) => e.sets)
        .where((s) => s.completed)
        .fold(0.0, (sum, s) => sum + s.reps * s.weightKg);
  }
}
