import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../features/home/data/services/transaction_service.dart';
import '../../features/budget/data/services/budget_service.dart';
import '../../features/category/data/services/category_service.dart';

final GetIt getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // External - Registering back to prevent "not registered" errors in other files
  if (!getIt.isRegistered<FirebaseAuth>()) {
    getIt.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);
  }
  if (!getIt.isRegistered<GoogleSignIn>()) {
    getIt.registerLazySingleton<GoogleSignIn>(() => GoogleSignIn());
  }

  // Services
  if (!getIt.isRegistered<TransactionService>()) {
    getIt.registerLazySingleton<TransactionService>(() => TransactionService());
  }
  if (!getIt.isRegistered<BudgetService>()) {
    getIt.registerLazySingleton<BudgetService>(() => BudgetService());
  }
  if (!getIt.isRegistered<CategoryService>()) {
    getIt.registerLazySingleton<CategoryService>(() => CategoryService());
  }
}
