import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../constants/colors.dart';
import '../constants/theme.dart';
import '../models/exercise_log.dart';
import '../models/set_model.dart';
import '../models/workout_plan.dart';
import '../models/workout_session.dart';
import '../providers/auth_provider.dart';
import '../providers/plan_provider.dart';
import '../providers/session_provider.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';
import '../widgets/plan_card.dart';

// ---------------------------------------------------------------------------
// Workout phase state machine
// ---------------------------------------------------------------------------

enum _Phase { planSelection, loggingSet, resting, complete }

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class LogWorkoutScreen extends ConsumerStatefulWidget {
  /// When coming from Plans → Start Workout, planId is pre-set and the
  /// plan-selection step is skipped. When tapping the Log tab directly,
  /// planId is null and the user picks a plan first.
  final String? planId;
  const LogWorkoutScreen({super.key, this.planId});

  @override
  ConsumerState<LogWorkoutScreen> createState() => _LogWorkoutScreenState();
}

class _LogWorkoutScreenState extends ConsumerState<LogWorkoutScreen> {
  _Phase _phase = _Phase.planSelection;

  // Active plan & progress
  WorkoutPlan? _plan;
  int _exerciseIndex = 0;
  int _setIndex = 0;

  // Collected sets: _loggedSets[exerciseIndex] → list of SetModel for that exercise
  List<List<SetModel>> _loggedSets = [];

  // Input controllers (reused across sets)
  final _weightCtrl = TextEditingController();
  final _repsCtrl = TextEditingController();

  // Elapsed workout timer
  DateTime? _startTime;
  int _elapsedSeconds = 0;
  Timer? _elapsedTimer;

  // Rest timer
  int _restDurationSeconds = 90;
  int _restSecondsRemaining = 0;
  Timer? _restTimer;

  bool _saving = false;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() =>
            _restDurationSeconds = prefs.getInt('rest_duration') ?? 90);
      }
      if (widget.planId != null) await _autoSelectPlan(widget.planId!);
    });
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _restTimer?.cancel();
    _weightCtrl.dispose();
    _repsCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Plan selection
  // ---------------------------------------------------------------------------

  Future<void> _autoSelectPlan(String planId) async {
    final plans = await ref.read(planProvider.future);
    for (final p in plans) {
      if (p.id == planId) {
        if (mounted) _selectPlan(p);
        return;
      }
    }
  }

  void _selectPlan(WorkoutPlan plan) {
    if (plan.exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This plan has no exercises.')),
      );
      return;
    }
    setState(() {
      _plan = plan;
      _exerciseIndex = 0;
      _setIndex = 0;
      _loggedSets = List.generate(plan.exercises.length, (_) => []);
      _startTime = DateTime.now();
      _elapsedSeconds = 0;
      _phase = _Phase.loggingSet;
      _weightCtrl.clear();
      _repsCtrl.clear();
    });
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  // ---------------------------------------------------------------------------
  // Set logging
  // ---------------------------------------------------------------------------

  void _logSet() {
    final weight = double.tryParse(_weightCtrl.text.trim()) ?? 0;
    final reps = int.tryParse(_repsCtrl.text.trim()) ?? 0;

    if (reps == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter how many reps you did.')),
      );
      return;
    }

    _loggedSets[_exerciseIndex].add(SetModel(
      reps: reps,
      weightKg: weight,
      completed: true,
    ));

    final exercise = _plan!.exercises[_exerciseIndex];
    final isLastSet = _setIndex + 1 >= exercise.targetSets;
    final isLastExercise = _exerciseIndex + 1 >= _plan!.exercises.length;

    if (isLastSet && isLastExercise) {
      // All done — skip rest, go straight to summary
      _elapsedTimer?.cancel();
      setState(() => _phase = _Phase.complete);
    } else {
      // Start rest before the next set
      setState(() => _phase = _Phase.resting);
      _startRestTimer();
    }
  }

  // ---------------------------------------------------------------------------
  // Rest timer
  // ---------------------------------------------------------------------------

  void _startRestTimer() {
    _restTimer?.cancel();
    setState(() => _restSecondsRemaining = _restDurationSeconds);
    _restTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _restSecondsRemaining--);
      if (_restSecondsRemaining <= 0) {
        _restTimer?.cancel();
        _advance();
      }
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    _advance();
  }

  /// Move to the next set or exercise after rest ends.
  void _advance() {
    final exercise = _plan!.exercises[_exerciseIndex];
    final isLastSet = _setIndex + 1 >= exercise.targetSets;

    if (!isLastSet) {
      // Next set — pre-fill weight from the set just logged
      final last = _loggedSets[_exerciseIndex].last;
      setState(() {
        _setIndex++;
        _phase = _Phase.loggingSet;
        _weightCtrl.text =
            last.weightKg > 0 ? _fmtWeight(last.weightKg) : '';
        _repsCtrl.clear();
      });
    } else {
      // Next exercise
      setState(() {
        _exerciseIndex++;
        _setIndex = 0;
        _phase = _Phase.loggingSet;
        _weightCtrl.clear();
        _repsCtrl.clear();
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  Future<void> _saveWorkout() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null || _plan == null || _startTime == null) return;

    setState(() => _saving = true);
    try {
      final exerciseLogs = _plan!.exercises.asMap().entries.map((entry) {
        final pe = entry.value;
        final sets = _loggedSets.length > entry.key
            ? _loggedSets[entry.key]
            : <SetModel>[];
        return ExerciseLog(
          exerciseId: pe.exerciseId,
          exerciseName: pe.exerciseName,
          sets: sets,
          maxWeightKg: ExerciseLog.computeMaxWeight(sets),
        );
      }).where((e) => e.sets.isNotEmpty).toList();

      final session = WorkoutSession(
        id: const Uuid().v4(),
        uid: user.uid,
        displayName: user.displayName ?? 'Unknown',
        planId: _plan!.id,
        planName: _plan!.name,
        date: _startTime!,
        durationSeconds: _elapsedSeconds,
        exercises: exerciseLogs,
        totalVolumeKg: WorkoutSession.computeTotalVolume(exerciseLogs),
      );

      await DatabaseService().upsertSession(session);
      FirestoreService().upsertSession(session).ignore();

      ref.invalidate(allSessionsProvider);
      ref.invalidate(sessionProvider(user.uid));

      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Discard
  // ---------------------------------------------------------------------------

  Future<void> _confirmDiscard() async {
    // On plan-selection there's nothing to lose — just pop.
    if (_phase == _Phase.planSelection) {
      context.pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Discard Workout?', style: AppTextStyles.heading(18)),
        content: Text(
          'Your progress will not be saved.',
          style: AppTextStyles.body(14)
              .copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Going',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (discard == true && mounted) context.pop();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _formatElapsed() {
    final h = _elapsedSeconds ~/ 3600;
    final m = (_elapsedSeconds % 3600) ~/ 60;
    final s = _elapsedSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  static String _fmtWeight(double w) =>
      w == w.truncateToDouble() ? w.toInt().toString() : w.toString();

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: _buildAppBar(),
        body: switch (_phase) {
          _Phase.planSelection => _buildPlanSelection(),
          _Phase.loggingSet   => _buildLoggingSet(),
          _Phase.resting      => _buildResting(),
          _Phase.complete     => _buildComplete(),
        },
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _confirmDiscard,
      ),
      title: _phase == _Phase.planSelection
          ? const Text('Start Workout')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_formatElapsed(), style: AppTextStyles.stat(16)),
                if (_plan != null)
                  Text(_plan!.name,
                      style: AppTextStyles.bodySecondary(11)),
              ],
            ),
    );
  }

  // ── Phase 1: Plan selection ────────────────────────────────────────────────

  Widget _buildPlanSelection() {
    final plansAsync = ref.watch(planProvider);
    final currentUid =
        ref.watch(authStateProvider).valueOrNull?.uid;

    return plansAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(
          child: Text('Could not load plans.',
              style: AppTextStyles.bodySecondary(14))),
      data: (plans) {
        if (plans.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.fitness_center,
                    size: 52, color: AppColors.textDisabled),
                const SizedBox(height: AppSpacing.md),
                Text('No plans yet',
                    style: AppTextStyles.heading(18)),
                const SizedBox(height: AppSpacing.xs),
                Text('Create a plan in the Plans tab first.',
                    style: AppTextStyles.bodySecondary(14)),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton(
                  onPressed: () => context.go('/plans'),
                  child: const Text('Go to Plans'),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.only(
              top: AppSpacing.sm, bottom: AppSpacing.xl),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                  AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
              child: Text('CHOOSE A PLAN',
                  style: AppTextStyles.bodySecondary(11)),
            ),
            for (final plan in plans)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs),
                child: PlanCard(
                  plan: plan,
                  isOwner: plan.uid == currentUid,
                  onStart: () => _selectPlan(plan),
                ),
              ),
          ],
        );
      },
    );
  }

  // ── Phase 2: Log a set ────────────────────────────────────────────────────

  Widget _buildLoggingSet() {
    final exercise = _plan!.exercises[_exerciseIndex];
    final totalSets = exercise.targetSets;
    final totalExercises = _plan!.exercises.length;
    final previousSet = _loggedSets[_exerciseIndex].isNotEmpty
        ? _loggedSets[_exerciseIndex].last
        : null;

    // Auto-focus: weight if empty, reps if weight is pre-filled
    final focusWeight = _weightCtrl.text.isEmpty;

    return GestureDetector(
      // Dismiss keyboard when tapping outside fields
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        // Scrollable so the keyboard never causes overflow
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress chips
            Row(
              children: [
                _Chip(
                    'Exercise ${_exerciseIndex + 1} of $totalExercises'),
                const SizedBox(width: AppSpacing.sm),
                _Chip('Set ${_setIndex + 1} of $totalSets'),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Thin overall progress bar
            _OverallProgressBar(
              exerciseIndex: _exerciseIndex,
              setIndex: _setIndex,
              plan: _plan!,
            ),
            const SizedBox(height: AppSpacing.xl),

            // Exercise name
            Text(exercise.exerciseName,
                style: AppTextStyles.heading(30)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              previousSet != null
                  ? 'Last set: ${_fmtWeight(previousSet.weightKg)} kg'
                      ' × ${previousSet.reps} reps'
                  : 'Enter your weight and reps below',
              style: AppTextStyles.bodySecondary(13),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Large input pair
            Row(
              children: [
                Expanded(
                  child: _BigInput(
                    controller: _weightCtrl,
                    label: 'kg',
                    decimal: true,
                    autofocus: focusWeight,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: _BigInput(
                    controller: _repsCtrl,
                    label: 'reps',
                    decimal: false,
                    autofocus: !focusWeight,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _logSet,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md),
                ),
                child: const Text('Log Set',
                    style: TextStyle(fontSize: 17)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Phase 3: Rest ─────────────────────────────────────────────────────────

  Widget _buildResting() {
    final m = _restSecondsRemaining ~/ 60;
    final s = _restSecondsRemaining % 60;
    final timeStr = '$m:${s.toString().padLeft(2, '0')}';
    final isLow = _restSecondsRemaining <= 10;

    // Determine next label
    final exercise = _plan!.exercises[_exerciseIndex];
    final isLastSet = _setIndex + 1 >= exercise.targetSets;
    final String nextLabel;
    if (!isLastSet) {
      nextLabel =
          '${exercise.exerciseName}  —  Set ${_setIndex + 2} of ${exercise.targetSets}';
    } else if (_exerciseIndex + 1 < _plan!.exercises.length) {
      nextLabel = _plan!.exercises[_exerciseIndex + 1].exerciseName;
    } else {
      nextLabel = 'Last set — almost done!';
    }

    // The set that was just logged
    final justLogged = _loggedSets[_exerciseIndex].isNotEmpty
        ? _loggedSets[_exerciseIndex].last
        : null;

    return SingleChildScrollView(
      child: Center(
        child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl, vertical: AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // What was just logged
            if (justLogged != null) ...[
              Text('You logged',
                  style: AppTextStyles.bodySecondary(13)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${_fmtWeight(justLogged.weightKg)} kg'
                ' × ${justLogged.reps} reps',
                style: AppTextStyles.heading(22),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],

            // Countdown
            Text('REST', style: AppTextStyles.bodySecondary(14)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              timeStr,
              style: AppTextStyles.stat(80).copyWith(
                color:
                    isLow ? AppColors.danger : AppColors.primary,
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ±15 s controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TimerBtn(
                  label: '-15',
                  onTap: () => setState(() {
                    _restSecondsRemaining =
                        (_restSecondsRemaining - 15).clamp(1, 600);
                  }),
                ),
                const SizedBox(width: AppSpacing.lg),
                _TimerBtn(
                  label: '+15',
                  onTap: () => setState(() {
                    _restSecondsRemaining =
                        (_restSecondsRemaining + 15).clamp(1, 600);
                  }),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            OutlinedButton(
              onPressed: _skipRest,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.sm),
              ),
              child: const Text('Skip'),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // What's coming next
            Text('Next', style: AppTextStyles.bodySecondary(11)),
            const SizedBox(height: AppSpacing.xs),
            Text(nextLabel,
                style: AppTextStyles.body(15),
                textAlign: TextAlign.center),
          ],
        ),
      ),
      ),
    );
  }

  // ── Phase 4: Complete ─────────────────────────────────────────────────────

  Widget _buildComplete() {
    final totalSets =
        _loggedSets.fold(0, (n, sets) => n + sets.length);
    final totalVolume = _loggedSets.fold(0.0, (sum, sets) {
      return sum +
          sets.fold(
              0.0, (s, set) => s + set.weightKg * set.reps);
    });

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline,
                size: 72, color: AppColors.primary),
            const SizedBox(height: AppSpacing.md),
            Text('Workout Complete!',
                style: AppTextStyles.heading(26)),
            const SizedBox(height: AppSpacing.xs),
            Text(_plan!.name,
                style: AppTextStyles.bodySecondary(14)),

            const SizedBox(height: AppSpacing.xl),

            // Summary card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _SummaryRow(
                      label: 'Duration',
                      value: _formatElapsed()),
                  _SummaryRow(
                      label: 'Exercises',
                      value:
                          '${_plan!.exercises.length}'),
                  _SummaryRow(
                      label: 'Sets logged',
                      value: '$totalSets'),
                  _SummaryRow(
                      label: 'Total volume',
                      value:
                          '${totalVolume.toStringAsFixed(1)} kg'),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveWorkout,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.background))
                    : const Text('Save Workout',
                        style: TextStyle(fontSize: 17)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Supporting widgets
// ---------------------------------------------------------------------------

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.primaryMuted,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style:
              AppTextStyles.body(12).copyWith(color: AppColors.primary)),
    );
  }
}

class _OverallProgressBar extends StatelessWidget {
  final int exerciseIndex;
  final int setIndex;
  final WorkoutPlan plan;

  const _OverallProgressBar({
    required this.exerciseIndex,
    required this.setIndex,
    required this.plan,
  });

  @override
  Widget build(BuildContext context) {
    final totalSets =
        plan.exercises.fold(0, (n, e) => n + e.targetSets);
    final completedSets = plan.exercises
            .take(exerciseIndex)
            .fold(0, (n, e) => n + e.targetSets) +
        setIndex;
    final progress =
        totalSets > 0 ? completedSets / totalSets : 0.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: progress,
        backgroundColor: AppColors.surfaceAlt,
        valueColor:
            const AlwaysStoppedAnimation<Color>(AppColors.primary),
        minHeight: 3,
      ),
    );
  }
}

class _BigInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool decimal;
  final bool autofocus;

  const _BigInput({
    required this.controller,
    required this.label,
    required this.decimal,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: TextField(
            controller: controller,
            autofocus: autofocus,
            textAlign: TextAlign.center,
            style: AppTextStyles.stat(38),
            keyboardType:
                TextInputType.numberWithOptions(decimal: decimal),
            inputFormatters: [
              if (decimal)
                FilteringTextInputFormatter.allow(
                    RegExp(r'^\d*\.?\d*'))
              else
                FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: const InputDecoration(
              hintText: '0',
              border: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(label, style: AppTextStyles.bodySecondary(13)),
      ],
    );
  }
}

class _TimerBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TimerBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: AppTextStyles.body(14)),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTextStyles.body(14)
                  .copyWith(color: AppColors.textSecondary)),
          Text(value, style: AppTextStyles.stat(14)),
        ],
      ),
    );
  }
}
