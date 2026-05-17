import 'set_model.dart';

class ExerciseLog {
  final String exerciseId;
  final String exerciseName;
  final List<SetModel> sets;
  final double maxWeightKg;

  const ExerciseLog({
    required this.exerciseId,
    required this.exerciseName,
    required this.sets,
    required this.maxWeightKg,
  });

  ExerciseLog copyWith({
    String? exerciseId,
    String? exerciseName,
    List<SetModel>? sets,
    double? maxWeightKg,
  }) {
    return ExerciseLog(
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      sets: sets ?? this.sets,
      maxWeightKg: maxWeightKg ?? this.maxWeightKg,
    );
  }

  factory ExerciseLog.fromMap(Map<String, dynamic> map) {
    return ExerciseLog(
      exerciseId: map['exerciseId'] as String,
      exerciseName: map['exerciseName'] as String,
      sets: (map['sets'] as List<dynamic>)
          .map((s) => SetModel.fromMap(s as Map<String, dynamic>))
          .toList(),
      maxWeightKg: (map['maxWeightKg'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'exerciseId': exerciseId,
      'exerciseName': exerciseName,
      'sets': sets.map((s) => s.toMap()).toList(),
      'maxWeightKg': maxWeightKg,
    };
  }

  static double computeMaxWeight(List<SetModel> sets) {
    final completed = sets.where((s) => s.completed);
    if (completed.isEmpty) return 0;
    return completed.map((s) => s.weightKg).reduce((a, b) => a > b ? a : b);
  }
}
