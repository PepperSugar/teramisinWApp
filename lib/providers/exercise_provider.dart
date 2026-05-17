import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/exercise.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';

class ExerciseNotifier extends AsyncNotifier<List<Exercise>> {
  @override
  Future<List<Exercise>> build() =>
      // getOrSeedExercises seeds defaults if the table is empty (covers devices
      // that had the DB created before seed data was introduced).
      DatabaseService().getOrSeedExercises();

  Future<void> addCustom(Exercise exercise) async {
    await DatabaseService().upsertExercise(exercise);
    FirestoreService().upsertExercise(exercise).ignore();
    ref.invalidateSelf();
  }
}

final exerciseProvider =
    AsyncNotifierProvider<ExerciseNotifier, List<Exercise>>(ExerciseNotifier.new);
