# Workout Tracker — Project Context

## Overview
A social workout tracking app for a small private group of friends (3–5 users).
Cross-platform: iOS and Android. Built with Flutter.

---

## Stack

| Layer        | Choice                                      |
|--------------|---------------------------------------------|
| Framework    | Flutter (Dart)                              |
| Navigation   | go_router                                   |
| Local DB     | SQLite via `sqflite`                        |
| Backend/Sync | Firebase Firestore (Spark free tier)        |
| Auth         | Firebase Auth — Google Sign-In only         |
| Charts       | fl_chart                                    |
| State        | Riverpod                                    |

---

## pubspec.yaml Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Navigation
  go_router: ^13.0.0

  # Firebase
  firebase_core: ^2.0.0
  firebase_auth: ^4.0.0
  cloud_firestore: ^4.0.0
  google_sign_in: ^6.0.0

  # Local DB
  sqflite: ^2.3.0
  path: ^1.8.0

  # State management
  flutter_riverpod: ^2.4.0

  # Charts
  fl_chart: ^0.66.0

  # Utilities
  uuid: ^4.0.0
  intl: ^0.18.0
  shared_preferences: ^2.2.0

  # Fonts
  google_fonts: ^6.1.0
```

---

## Commands

- `flutter run` — run on connected device/emulator
- `flutter run -d android` — run on Android
- `flutter run -d ios` — run on iOS simulator
- `flutter test` — run tests
- `flutter analyze` — static analysis
- `flutter pub get` — install dependencies
- `flutterfire configure` — set up Firebase (run once)

---

## Folder Structure

```
/lib
  main.dart                     — app entry point, Firebase init
  /models                       — Dart data classes
    user_model.dart
    workout_session.dart
    workout_plan.dart
    exercise.dart
    exercise_log.dart
    set_model.dart
  /services
    auth_service.dart           — Firebase Auth + Google Sign-In
    firestore_service.dart      — all Firestore reads/writes
    database_service.dart       — all SQLite reads/writes
    sync_service.dart           — offline-first sync logic
  /providers                    — Riverpod providers
    auth_provider.dart
    session_provider.dart
    plan_provider.dart
    exercise_provider.dart
    leaderboard_provider.dart
  /screens
    home_screen.dart
    log_workout_screen.dart
    history_screen.dart
    progress_screen.dart
    plans_screen.dart
    create_plan_screen.dart
    feed_screen.dart
    profile_screen.dart
    leaderboard_screen.dart
    compare_screen.dart
  /widgets                      — reusable UI components
    set_row.dart
    exercise_card.dart
    workout_card.dart
    rest_timer.dart
    stat_chip.dart
    green_button.dart
    plan_card.dart
  /constants
    colors.dart                 — color tokens
    theme.dart                  — ThemeData, spacing, typography
  /router
    app_router.dart             — go_router config
firestore.rules                 — Firestore security rules
```

---

## Data Models

```dart
// lib/models/user_model.dart
class UserModel {
  final String uid;
  final String displayName;
  final String photoURL;
  final DateTime joinedAt;
}

// lib/models/workout_plan.dart
class WorkoutPlan {
  final String id;
  final String uid;
  final String displayName;     // denormalized creator name
  final String name;            // e.g. "Push Day A"
  final List<PlanExercise> exercises;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class PlanExercise {
  final String exerciseId;
  final String exerciseName;    // denormalized
  final int targetSets;
}

// lib/models/workout_session.dart
class WorkoutSession {
  final String id;
  final String uid;
  final String displayName;     // denormalized
  final String? planId;
  final String? planName;
  final DateTime date;
  final int durationSeconds;
  final List<ExerciseLog> exercises;
  final double totalVolumeKg;   // precomputed
}

// lib/models/exercise_log.dart
class ExerciseLog {
  final String exerciseId;
  final String exerciseName;    // denormalized
  final List<SetModel> sets;
  final double maxWeightKg;     // precomputed
}

// lib/models/set_model.dart
class SetModel {
  final int reps;
  final double weightKg;
  final bool completed;
}

// lib/models/exercise.dart
class Exercise {
  final String id;
  final String name;
  final String muscleGroup;
  final bool isCustom;
  final String createdBy;
}
```

---

## Screens

| # | Screen | Route | Description |
|---|--------|-------|-------------|
| 1 | Home | `/` | Last workout summary, "Start from Plan" + "Start Empty", weekly streak |
| 2 | Log Workout | `/log` | Pre-filled from plan OR blank, sets/reps/weight, rest timer, save |
| 3 | History | `/history` | Your past sessions, expandable details |
| 4 | Progress | `/progress` | PR / volume / frequency charts (yours) |
| 5 | Plans | `/plans` | Browse all plans (yours + friends'), create new |
| 6 | Create/Edit Plan | `/plans/create` | Plan name, add exercises, set target sets, save |
| 7 | Community Feed | `/feed` | All users' recent workouts, tap to view profile |
| 8 | User Profile | `/profile/:uid` | Any user's history, PRs, "Compare with me" button |
| 9 | Leaderboard | `/leaderboard` | Ranked by exercise: top weight / volume / frequency |
| 10 | Compare | `/compare/:uid` | Side-by-side charts of you vs selected user |

Bottom nav tabs: Home, Log, Plans, Feed, Leaderboard
Shell screens (pushed on stack): History, Progress, Profile, Compare, Create Plan

---

## Sync Strategy

- **Offline-first**: all writes go to local SQLite immediately via `database_service.dart`
- **Background sync**: `sync_service.dart` pushes to Firestore when online
- **Auth gate**: Google Sign-In required; only whitelisted emails can access any data
- On app start: pull latest data from Firestore into SQLite if online

---

## Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isWhitelisted() {
      return request.auth.token.email in [
        "you@gmail.com",
        "friend1@gmail.com",
        "friend2@gmail.com"
      ];
    }

    function isOwner(uid) {
      return request.auth.uid == uid;
    }

    match /users/{uid} {
      allow read: if isWhitelisted();
      allow write: if isOwner(uid);
    }

    match /sessions/{id} {
      allow read: if isWhitelisted();
      allow write: if isOwner(resource.data.uid);
    }

    match /plans/{id} {
      allow read: if isWhitelisted();
      allow write, delete: if isOwner(resource.data.uid);
    }

    match /exercises/{id} {
      allow read: if isWhitelisted();
      allow create: if isWhitelisted();
      allow update, delete: if isOwner(resource.data.createdBy);
    }
  }
}
```

---

## Design System

### Theme: Minimal Green (Dark)

Clean, minimal dark UI with a green accent. No gradients, no drop shadows,
no decorative illustrations. Every widget should feel purposeful and lightweight.
Inspired by fitness apps like Strong — functional over decorative.

### Color Tokens (`/lib/constants/colors.dart`)

```dart
class AppColors {
  // Backgrounds
  static const background   = Color(0xFF0D0D0D); // near-black
  static const surface      = Color(0xFF1A1A1A); // cards, sheets
  static const surfaceAlt   = Color(0xFF222222); // inputs, secondary surfaces

  // Green accent
  static const primary      = Color(0xFF4ADE80); // bright green — buttons, active
  static const primaryMuted = Color(0xFF166534); // muted green — tags, badges
  static const primaryDim   = Color(0xFF14532D); // dark green — pressed states

  // Text
  static const textPrimary   = Color(0xFFF5F5F5);
  static const textSecondary = Color(0xFFA3A3A3);
  static const textDisabled  = Color(0xFF525252);

  // Utility
  static const border  = Color(0xFF2A2A2A);
  static const danger  = Color(0xFFF87171);
}
```

### Typography

```dart
// Use google_fonts package
// Headings:  GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)
// Body:      GoogleFonts.inter(fontWeight: FontWeight.w400)
// Stats:     GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600)
// Stats (weights, reps, PRs) are always displayed in AppColors.primary green
```

### Spacing Scale

```dart
class AppSpacing {
  static const xs  = 4.0;
  static const sm  = 8.0;
  static const md  = 16.0;
  static const lg  = 24.0;
  static const xl  = 32.0;
  static const xxl = 48.0;
}
```

### Widget Rules

- **Buttons**: `ElevatedButton` with `primary` green fill for main actions; outlined green for secondary
- **Cards**: `surface` background, `border` color border, `8px` border radius — `elevation: 0`
- **Inputs**: `surfaceAlt` fill, green `focusedBorder` only — `InputBorder.none` when unfocused
- **Bottom nav**: `background` color, active icon + label in `primary` green
- **Charts**: green line/bar on dark background, minimal grid lines in `border` color
- **Rest timer**: full-screen modal, large green countdown number, minimal controls
- **Set rows**: `Row` — set number, weight `TextField`, reps `TextField`, `Checkbox`
- No emojis in UI. No gradients. No decorative illustrations. `elevation: 0` everywhere.

---

## Coding Conventions

- Dart null safety enforced — no `dynamic`, avoid `!` force-unwrap unless justified with a comment
- All models are immutable (`final` fields) with `copyWith`, `fromMap`, and `toMap` methods
- Riverpod for all state — no `setState` except for purely local widget state (e.g. active text field)
- All Firebase calls inside `/services` only — never directly in screens or providers
- All SQLite queries inside `database_service.dart` only
- Every screen handles three states: loading, empty, and data — use `AsyncValue` from Riverpod
- File names in `snake_case`, class names in `PascalCase`
- Widgets extracted into `/widgets` if used in more than one screen

---

## Key Implementation Notes

- **Starting from a plan**: pre-fill exercises and generate empty `SetModel` rows up to
  `targetSets`; user fills in actual reps + weight live during the session
- **totalVolumeKg**: computed before saving = sum of `(reps × weightKg)` across all
  completed sets in the session
- **maxWeightKg**: computed per `ExerciseLog` = max `weightKg` across all completed sets
- **Leaderboard**: Firestore `collectionGroup` query on `/sessions`, filtered by
  `exerciseId`, ordered by `maxWeightKg` descending
- **Rest timer**: preference stored via `shared_preferences`; default 90 seconds;
  foreground only — implement with a `Timer` inside a Riverpod `StateNotifier`
- **Whitelist check**: after Google Sign-In succeeds, verify `user.email` against the
  allowed list before navigating into the app; show an "Access Denied" screen if not matched
