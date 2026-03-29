import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:savemoney/features/auth/domain/auth_provider.dart';
import 'package:savemoney/features/auth/presentation/screens/login_screen.dart';
import 'package:savemoney/features/auth/presentation/screens/splash_screen.dart';
import 'package:savemoney/features/home/presentation/screens/home_screen.dart';
import 'package:savemoney/features/transaction/presentation/screens/transactions_screen.dart';
import 'package:savemoney/features/report/presentation/screens/reports_screen.dart';
import 'package:savemoney/features/budget/presentation/screens/budget_screen.dart';
import 'package:savemoney/features/wallet/presentation/screens/wallet_screen.dart';
import 'package:savemoney/features/savings/presentation/screens/savings_screen.dart';
import 'package:savemoney/features/family/presentation/screens/family_setup_screen.dart';
import 'package:savemoney/shared/widgets/main_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    // Auth guard
    redirect: (context, state) {
      final isLoading = authState.isLoading;
      final isOnSplash = state.matchedLocation == '/splash';

      // Đang load auth state → chỉ cho ở splash
      if (isLoading) return isOnSplash ? null : '/splash';

      final isLoggedIn = authState.valueOrNull != null;
      final isGoingToLogin = state.matchedLocation == '/login';

      // Đã load xong: rời splash
      if (isOnSplash) return isLoggedIn ? '/home' : '/login';

      if (!isLoggedIn && !isGoingToLogin) return '/login';
      if (isLoggedIn && isGoingToLogin) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/family-setup',
        name: 'family-setup',
        builder: (context, state) => const FamilySetupScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/transactions',
            name: 'transactions',
            builder: (context, state) => const TransactionsScreen(),
          ),
          GoRoute(
            path: '/reports',
            name: 'reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/budget',
            name: 'budget',
            builder: (context, state) => const BudgetScreen(),
          ),
          GoRoute(
            path: '/wallet',
            name: 'wallet',
            builder: (context, state) => const WalletScreen(),
          ),
          GoRoute(
            path: '/savings',
            name: 'savings',
            builder: (context, state) => const SavingsScreen(),
          ),
        ],
      ),
    ],
  );
});
