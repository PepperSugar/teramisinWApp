import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../screens/home_screen.dart';
import '../screens/log_workout_screen.dart';
import '../screens/history_screen.dart';
import '../screens/progress_screen.dart';
import '../screens/plans_screen.dart';
import '../screens/create_plan_screen.dart';
import '../screens/feed_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/leaderboard_screen.dart';
import '../screens/compare_screen.dart';
import '../screens/login_screen.dart';
import '../widgets/app_shell.dart';

// Bridges Firebase auth stream → GoRouter refresh so redirects fire on
// sign-in / sign-out automatically.
class _AuthChangeNotifier extends ChangeNotifier {
  late final StreamSubscription<User?> _sub;

  _AuthChangeNotifier() {
    _sub = FirebaseAuth.instance.authStateChanges().listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final _authNotifier = _AuthChangeNotifier();

final appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: _authNotifier,
  redirect: (context, state) {
    final loggedIn = FirebaseAuth.instance.currentUser != null;
    final onLogin = state.matchedLocation == '/login';

    if (!loggedIn && !onLogin) return '/login';
    if (loggedIn && onLogin) return '/';
    return null;
  },
  routes: [
    // Auth screen — no shell, no bottom nav
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),

    // Main app shell with bottom nav
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/plans',
          builder: (context, state) => const PlansScreen(),
        ),
        GoRoute(
          path: '/feed',
          builder: (context, state) => const FeedScreen(),
        ),
        GoRoute(
          path: '/leaderboard',
          builder: (context, state) => const LeaderboardScreen(),
        ),
      ],
    ),

    // Stack screens — full screen, no bottom nav
    // /log is here (not in ShellRoute) so every navigation creates a fresh
    // LogWorkoutScreen with the correct planId from initState.
    GoRoute(
      path: '/log',
      builder: (context, state) {
        final planId = state.uri.queryParameters['planId'];
        return LogWorkoutScreen(planId: planId);
      },
    ),
    GoRoute(
      path: '/history',
      builder: (context, state) => const HistoryScreen(),
    ),
    GoRoute(
      path: '/progress',
      builder: (context, state) => const ProgressScreen(),
    ),
    GoRoute(
      path: '/plans/create',
      builder: (context, state) {
        final planId = state.uri.queryParameters['planId'];
        return CreatePlanScreen(planId: planId);
      },
    ),
    GoRoute(
      path: '/profile/:uid',
      builder: (context, state) {
        final uid = state.pathParameters['uid']!;
        return ProfileScreen(uid: uid);
      },
    ),
    GoRoute(
      path: '/compare/:uid',
      builder: (context, state) {
        final uid = state.pathParameters['uid']!;
        return CompareScreen(uid: uid);
      },
    ),
  ],
);

// Tab index mapping for bottom nav
// /log is a stack route (outside the shell), so it never maps to a tab index.
int tabIndexForLocation(String location) {
  if (location.startsWith('/plans')) return 2;
  if (location.startsWith('/feed')) return 3;
  if (location.startsWith('/leaderboard')) return 4;
  return 0;
}

// Index 1 (Log) intentionally omitted — it's handled via context.push in AppShell.
const _tabRoutes = ['/', '/', '/plans', '/feed', '/leaderboard'];

String routeForTabIndex(int index) => _tabRoutes[index];
