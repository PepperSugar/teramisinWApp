class SetModel {
  final int reps;
  final double weightKg;
  final bool completed;

  const SetModel({
    required this.reps,
    required this.weightKg,
    required this.completed,
  });

  SetModel copyWith({
    int? reps,
    double? weightKg,
    bool? completed,
  }) {
    return SetModel(
      reps: reps ?? this.reps,
      weightKg: weightKg ?? this.weightKg,
      completed: completed ?? this.completed,
    );
  }

  factory SetModel.fromMap(Map<String, dynamic> map) {
    return SetModel(
      reps: map['reps'] as int,
      weightKg: (map['weightKg'] as num).toDouble(),
      completed: map['completed'] as bool,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reps': reps,
      'weightKg': weightKg,
      'completed': completed,
    };
  }

  static SetModel empty() => const SetModel(reps: 0, weightKg: 0, completed: false);
}
