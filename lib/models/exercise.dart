class Exercise {
  final String id;
  final String name;
  final String muscleGroup;
  final bool isCustom;
  final String createdBy;

  const Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.isCustom,
    required this.createdBy,
  });

  Exercise copyWith({
    String? id,
    String? name,
    String? muscleGroup,
    bool? isCustom,
    String? createdBy,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      isCustom: isCustom ?? this.isCustom,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      id: map['id'] as String,
      name: map['name'] as String,
      muscleGroup: map['muscleGroup'] as String,
      isCustom: map['isCustom'] as bool,
      createdBy: map['createdBy'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'muscleGroup': muscleGroup,
      'isCustom': isCustom,
      'createdBy': createdBy,
    };
  }
}
