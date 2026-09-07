import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/theme/light_theme.dart';
import 'core/theme/dark_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/providers/currency_provider.dart';
import 'core/providers/notification_provider.dart';
import 'config/routes/app_router.dart';
import 'core/services/service_locator.dart';
import 'core/services/notification_service.dart';
import 'features/auth/presentation/providers/app_auth_provider.dart';
import 'features/home/presentation/providers/transaction_provider.dart';
import 'features/budget/presentation/providers/budget_provider.dart';
import 'features/category/presentation/providers/category_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // 2. Initialize Notification Service
  final notificationService = NotificationService();
  await notificationService.init();
  await notificationService.requestPermissions();

  // 3. Setup Service Locator
  await setupServiceLocator();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppAuthProvider()),
        ChangeNotifierProxyProvider<AppAuthProvider, TransactionProvider>(
          create: (_) => TransactionProvider(),
          update: (_, auth, tx) => tx!..updateAuth(auth.effectiveUid, auth.status),
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProxyProvider<AppAuthProvider, BudgetProvider>(
          create: (_) => BudgetProvider(),
          update: (_, auth, budget) => budget!..updateAuth(auth.userId, auth.status),
        ),
        ChangeNotifierProxyProvider<AppAuthProvider, CategoryProvider>(
          create: (_) => CategoryProvider(),
          update: (_, auth, category) => category!..updateAuth(auth.userId, auth.status),
        ),
        ChangeNotifierProvider(create: (_) => CurrencyProvider()),
        ChangeNotifierProxyProvider4<TransactionProvider, BudgetProvider, CurrencyProvider, AppAuthProvider, NotificationProvider>(
          create: (_) => NotificationProvider()..loadSettings(),
          update: (context, transactionProvider, budgetProvider, currencyProvider, authProvider, notificationProvider) {
            if (notificationProvider != null) {
              // 0. UPDATE USER NAME: For personalized notifications
              notificationProvider.updateUserName(
                authProvider.effectiveDisplayName.split(' ').first
              );

              // 1. INSTANT BUDGET CHECK: When limit is crossed
              notificationProvider.checkBudgetStatus(
                transactionProvider.monthlyExpense,
                budgetProvider.monthlyLimit,
                currencySymbol: currencyProvider.currencySymbol,
              );

              // 2. WEEKLY SMART RECAP: Update info for Sunday morning
              notificationProvider.updateSmartInsights(
                transactionProvider.transactions,
                currencyProvider.currencySymbol,
              );

              // 3. DAILY ACTIVITY INSIGHT: Update evening reminder message
              notificationProvider.updateDailyActivityInsight(
                transactionProvider.transactions,
              );
            }
            return notificationProvider!;
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp.router(
            title: 'MoneyMap',
            debugShowCheckedModeBanner: false,
            theme: LightTheme.theme,
            darkTheme: DarkTheme.theme,
            themeMode: themeProvider.themeMode,
            routerConfig: AppRouter.router,
          );
        },
      ),
    );
  }
}
