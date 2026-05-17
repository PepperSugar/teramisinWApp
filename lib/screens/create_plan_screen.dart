import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../constants/colors.dart';
import '../constants/theme.dart';
import '../models/exercise.dart';
import '../models/workout_plan.dart';
import '../providers/auth_provider.dart';
import '../providers/exercise_provider.dart';
import '../providers/plan_provider.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class CreatePlanScreen extends ConsumerStatefulWidget {
  final String? planId;
  const CreatePlanScreen({super.key, this.planId});

  @override
  ConsumerState<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends ConsumerState<CreatePlanScreen> {
  final _nameController = TextEditingController();
  final List<PlanExercise> _exercises = [];
  WorkoutPlan? _originalPlan;
  bool _saving = false;

  bool get _isEditing => widget.planId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      Future.microtask(_loadExistingPlan);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingPlan() async {
    final plans = await ref.read(planProvider.future);
    WorkoutPlan? found;
    for (final p in plans) {
      if (p.id == widget.planId) {
        found = p;
        break;
      }
    }
    if (found != null && mounted) {
      setState(() {
        _nameController.text = found!.name;
        _exercises.addAll(found.exercises);
        _originalPlan = found;
      });
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _snack('Enter a plan name.');
      return;
    }
    if (_exercises.isEmpty) {
      _snack('Add at least one exercise.');
      return;
    }

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final plan = WorkoutPlan(
        id: widget.planId ?? const Uuid().v4(),
        uid: user.uid,
        displayName: user.displayName ?? 'Unknown',
        name: name,
        exercises: List.from(_exercises),
        createdAt: _originalPlan?.createdAt ?? now,
        updatedAt: now,
      );
      await ref.read(planProvider.notifier).save(plan);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) _snack('Failed to save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _removeExercise(int index) =>
      setState(() => _exercises.removeAt(index));

  void _incrementSets(int index) => setState(() {
        _exercises[index] = _exercises[index]
            .copyWith(targetSets: (_exercises[index].targetSets + 1).clamp(1, 10));
      });

  void _decrementSets(int index) => setState(() {
        _exercises[index] = _exercises[index]
            .copyWith(targetSets: (_exercises[index].targetSets - 1).clamp(1, 10));
      });

  void _openExercisePicker() {
    final already = _exercises.map((e) => e.exerciseId).toSet();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ExercisePickerSheet(
        alreadyAdded: already,
        onPick: (exercise) => setState(() {
          _exercises.add(PlanExercise(
            exerciseId: exercise.id,
            exerciseName: exercise.name,
            targetSets: 3,
          ));
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Plan' : 'Create Plan'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text(
                'Save',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Plan name input
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
            child: TextField(
              controller: _nameController,
              style: AppTextStyles.heading(18),
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'Plan name  (e.g. Push Day A)',
              ),
            ),
          ),
          const Divider(),
          // Exercise list (reorderable)
          Expanded(
            child: _exercises.isEmpty
                ? _buildEmptyExercises()
                : ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    itemCount: _exercises.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = _exercises.removeAt(oldIndex);
                        _exercises.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (_, i) => _ExerciseRow(
                      key: ValueKey(_exercises[i].exerciseId),
                      index: i,
                      exercise: _exercises[i],
                      onIncrement: () => _incrementSets(i),
                      onDecrement: () => _decrementSets(i),
                      onRemove: () => _removeExercise(i),
                    ),
                  ),
          ),
          // Add exercise button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openExercisePicker,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Exercise'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyExercises() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.playlist_add,
              size: 52, color: AppColors.textDisabled),
          const SizedBox(height: AppSpacing.md),
          Text('No exercises yet', style: AppTextStyles.bodySecondary(14)),
          const SizedBox(height: AppSpacing.xs),
          Text('Tap Add Exercise below to begin',
              style: AppTextStyles.bodySecondary(12)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise row inside the plan builder
// ---------------------------------------------------------------------------

class _ExerciseRow extends StatelessWidget {
  final int index;
  final PlanExercise exercise;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  const _ExerciseRow({
    super.key,
    required this.index,
    required this.exercise,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          // Drag handle
          ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle,
                color: AppColors.textDisabled, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Exercise name
          Expanded(
            child: Text(exercise.exerciseName, style: AppTextStyles.body(15)),
          ),
          // Sets stepper
          _SetsControl(
            sets: exercise.targetSets,
            onDecrement: onDecrement,
            onIncrement: onIncrement,
          ),
          const SizedBox(width: AppSpacing.sm),
          // Remove
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close,
                color: AppColors.textDisabled, size: 20),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sets stepper
// ---------------------------------------------------------------------------

class _SetsControl extends StatelessWidget {
  final int sets;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _SetsControl({
    required this.sets,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(icon: Icons.remove, onTap: onDecrement),
        SizedBox(
          width: 48,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$sets',
                  style: AppTextStyles.stat(16), textAlign: TextAlign.center),
              Text(sets == 1 ? 'set' : 'sets',
                  style: AppTextStyles.bodySecondary(10),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
        _StepButton(icon: Icons.add, onTap: onIncrement),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _StepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 16, color: AppColors.textPrimary),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise picker bottom sheet
// ---------------------------------------------------------------------------

class _ExercisePickerSheet extends ConsumerStatefulWidget {
  final Set<String> alreadyAdded;
  final void Function(Exercise) onPick;

  const _ExercisePickerSheet({
    required this.alreadyAdded,
    required this.onPick,
  });

  @override
  ConsumerState<_ExercisePickerSheet> createState() =>
      _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends ConsumerState<_ExercisePickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _pick(Exercise exercise) {
    widget.onPick(exercise);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(exerciseProvider);
    final screenHeight = MediaQuery.of(context).size.height;

    return SizedBox(
      height: screenHeight * 0.82,
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header + search
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add Exercise', style: AppTextStyles.heading(16)),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search exercises...',
                    prefixIcon: Icon(Icons.search,
                        color: AppColors.textDisabled, size: 20),
                  ),
                  onChanged: (v) => setState(() => _query = v.toLowerCase()),
                ),
              ],
            ),
          ),
          const Divider(),
          // List
          Expanded(
            child: exercisesAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary)),
              error: (e, st) => Center(
                child: Text('Could not load exercises.',
                    style: AppTextStyles.bodySecondary(14)),
              ),
              data: (exercises) {
                final filtered = _query.isEmpty
                    ? exercises
                    : exercises
                        .where((e) =>
                            e.name.toLowerCase().contains(_query) ||
                            e.muscleGroup.toLowerCase().contains(_query))
                        .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text('No exercises found.',
                        style: AppTextStyles.bodySecondary(14)),
                  );
                }

                // Flat list when searching, grouped otherwise
                return _query.isNotEmpty
                    ? _FlatList(
                        exercises: filtered,
                        alreadyAdded: widget.alreadyAdded,
                        onPick: _pick,
                      )
                    : _GroupedList(
                        exercises: filtered,
                        alreadyAdded: widget.alreadyAdded,
                        onPick: _pick,
                      );
              },
            ),
          ),
          // New custom exercise
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showNewExerciseDialog(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New custom exercise'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNewExerciseDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    var selectedGroup = 'Chest';
    const groups = [
      'Chest', 'Back', 'Shoulders', 'Legs',
      'Biceps', 'Triceps', 'Core', 'Cardio', 'Other',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('New Custom Exercise', style: AppTextStyles.heading(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(hintText: 'Exercise name'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: selectedGroup,
                dropdownColor: AppColors.surfaceAlt,
                style: AppTextStyles.body(14),
                decoration: const InputDecoration(hintText: 'Muscle group'),
                items: groups
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (v) => setDialog(() => selectedGroup = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;

                final user = ref.read(authStateProvider).valueOrNull;
                if (user == null) return;

                final exercise = Exercise(
                  id: const Uuid().v4(),
                  name: name,
                  muscleGroup: selectedGroup,
                  isCustom: true,
                  createdBy: user.uid,
                );

                await ref.read(exerciseProvider.notifier).addCustom(exercise);

                if (ctx.mounted) Navigator.of(ctx).pop();
                // Pick the new exercise and close the sheet
                _pick(exercise);
              },
              child: const Text('Add',
                  style: TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Flat exercise list (used when searching)
// ---------------------------------------------------------------------------

class _FlatList extends StatelessWidget {
  final List<Exercise> exercises;
  final Set<String> alreadyAdded;
  final void Function(Exercise) onPick;

  const _FlatList({
    required this.exercises,
    required this.alreadyAdded,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      itemCount: exercises.length,
      itemBuilder: (_, i) => _ExerciseTile(
        exercise: exercises[i],
        isAdded: alreadyAdded.contains(exercises[i].id),
        onTap: () => onPick(exercises[i]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grouped exercise list (used when not searching)
// ---------------------------------------------------------------------------

class _GroupedList extends StatelessWidget {
  final List<Exercise> exercises;
  final Set<String> alreadyAdded;
  final void Function(Exercise) onPick;

  const _GroupedList({
    required this.exercises,
    required this.alreadyAdded,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    // Group by muscle group
    final groups = <String, List<Exercise>>{};
    for (final e in exercises) {
      groups.putIfAbsent(e.muscleGroup, () => []).add(e);
    }
    final sortedKeys = groups.keys.toList()..sort();

    final items = <Widget>[];
    for (final group in sortedKeys) {
      items.add(_GroupHeader(label: group));
      for (final e in groups[group]!) {
        items.add(_ExerciseTile(
          exercise: e,
          isAdded: alreadyAdded.contains(e.id),
          onTap: () => onPick(e),
        ));
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      children: items,
    );
  }
}

// ---------------------------------------------------------------------------
// Shared tiles
// ---------------------------------------------------------------------------

class _GroupHeader extends StatelessWidget {
  final String label;
  const _GroupHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
      child: Text(label.toUpperCase(), style: AppTextStyles.bodySecondary(11)),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  final Exercise exercise;
  final bool isAdded;
  final VoidCallback onTap;

  const _ExerciseTile({
    required this.exercise,
    required this.isAdded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: isAdded ? null : onTap,
      dense: true,
      title: Text(
        exercise.name,
        style: AppTextStyles.body(14).copyWith(
          color: isAdded ? AppColors.textDisabled : AppColors.textPrimary,
        ),
      ),
      subtitle: isAdded
          ? null
          : Text(exercise.muscleGroup, style: AppTextStyles.bodySecondary(11)),
      trailing: isAdded
          ? const Icon(Icons.check, color: AppColors.primary, size: 18)
          : null,
    );
  }
}
