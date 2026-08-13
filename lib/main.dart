import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
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

  // 2. Initialize Notification Service Foundation
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
        ChangeNotifierProvider(create: (_) => TransactionProvider()..loadTransactions()..loadMonthlyTransactions()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => BudgetProvider()..loadBudget()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => CurrencyProvider()),
        ChangeNotifierProxyProvider2<TransactionProvider, BudgetProvider, NotificationProvider>(
          create: (_) => NotificationProvider()..loadSettings(),
          update: (context, transactionProvider, budgetProvider, notificationProvider) {
            if (notificationProvider != null) {
              // Automatically check budget whenever data changes
              notificationProvider.checkBudgetStatus(
                transactionProvider.monthlyExpense,
                budgetProvider.monthlyLimit,
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
