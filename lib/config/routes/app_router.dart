import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'app_routes.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/auth_select_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/home/presentation/screens/add_transaction_screen.dart';
import '../../features/home/presentation/screens/all_transactions_screen.dart';
import '../../features/home/presentation/screens/transaction_details_screen.dart';
import '../../features/home/presentation/screens/success_screen.dart';
import '../../features/home/data/models/transaction_model.dart';
import '../../features/budget/presentation/screens/budget_screen.dart';
import '../../features/category/presentation/screens/category_management_screen.dart';
import '../../features/statistics/presentation/screens/statistics_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/settings_screen.dart';
import '../../features/notification/presentation/screens/notification_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        pageBuilder: (context, state) => _slideUpTransitionPage(
          state: state,
          child: const OnboardingScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.auth,
        pageBuilder: (context, state) => _slideUpTransitionPage(
          state: state,
          child: const AuthSelectScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => _slideUpTransitionPage(
          state: state,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.register,
        pageBuilder: (context, state) => _slideUpTransitionPage(
          state: state,
          child: const RegisterScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        pageBuilder: (context, state) => _slideUpTransitionPage(
          state: state,
          child: const ForgotPasswordScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        pageBuilder: (context, state) => _slideUpTransitionPage(
          state: state,
          child: const VerifyEmailScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.addTransaction,
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return _slideUpTransitionPage(
            state: state,
            child: AddTransactionScreen(
              transactionToEdit: extra?['transactionToEdit'] as TransactionModel?,
              initialType: extra?['initialType'] as String?,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.allTransactions,
        pageBuilder: (context, state) => _slideUpTransitionPage(
          state: state,
          child: const AllTransactionsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.transactionDetails,
        pageBuilder: (context, state) {
          final transaction = state.extra as TransactionModel;
          return _slideUpTransitionPage(
            state: state,
            child: TransactionDetailsScreen(transaction: transaction),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.success,
        pageBuilder: (context, state) {
          final transaction = state.extra as Map<String, dynamic>;
          return _slideUpTransitionPage(
            state: state,
            child: SuccessScreen(transaction: transaction),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.budget,
        pageBuilder: (context, state) => _slideUpTransitionPage(
          state: state,
          child: const BudgetScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.categoryManagement,
        pageBuilder: (context, state) => _slideUpTransitionPage(
          state: state,
          child: const CategoryManagementScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.statistics,
        builder: (context, state) => const StatisticsScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        pageBuilder: (context, state) => _slideUpTransitionPage(
          state: state,
          child: const SettingsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        pageBuilder: (context, state) => _slideUpTransitionPage(
          state: state,
          child: const NotificationScreen(),
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('No route defined for ${state.uri}')),
    ),
  );

  static CustomTransitionPage<T> _slideUpTransitionPage<T>({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            )),
            child: child,
          ),
        );
      },
    );
  }
}
