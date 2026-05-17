class PlanExercise {
  final String exerciseId;
  final String exerciseName;
  final int targetSets;

  const PlanExercise({
    required this.exerciseId,
    required this.exerciseName,
    required this.targetSets,
  });

  PlanExercise copyWith({
    String? exerciseId,
    String? exerciseName,
    int? targetSets,
  }) {
    return PlanExercise(
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      targetSets: targetSets ?? this.targetSets,
    );
  }

  factory PlanExercise.fromMap(Map<String, dynamic> map) {
    return PlanExercise(
      exerciseId: map['exerciseId'] as String,
      exerciseName: map['exerciseName'] as String,
      targetSets: map['targetSets'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'exerciseId': exerciseId,
      'exerciseName': exerciseName,
      'targetSets': targetSets,
    };
  }
}

class WorkoutPlan {
  final String id;
  final String uid;
  final String displayName;
  final String name;
  final List<PlanExercise> exercises;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WorkoutPlan({
    required this.id,
    required this.uid,
    required this.displayName,
    required this.name,
    required this.exercises,
    required this.createdAt,
    required this.updatedAt,
  });

  WorkoutPlan copyWith({
    String? id,
    String? uid,
    String? displayName,
    String? name,
    List<PlanExercise>? exercises,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkoutPlan(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      name: name ?? this.name,
      exercises: exercises ?? this.exercises,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory WorkoutPlan.fromMap(Map<String, dynamic> map) {
    return WorkoutPlan(
      id: map['id'] as String,
      uid: map['uid'] as String,
      displayName: map['displayName'] as String,
      name: map['name'] as String,
      exercises: (map['exercises'] as List<dynamic>)
          .map((e) => PlanExercise.fromMap(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'displayName': displayName,
      'name': name,
      'exercises': exercises.map((e) => e.toMap()).toList(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }
}
