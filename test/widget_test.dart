import 'package:flutter_test/flutter_test.dart';
import 'package:moneymap/config/routes/app_routes.dart';

void main() {
  test('route paths are unique', () {
    final routes = <String>{
      AppRoutes.splash,
      AppRoutes.onboarding,
      AppRoutes.auth,
      AppRoutes.login,
      AppRoutes.register,
      AppRoutes.home,
      AppRoutes.addTransaction,
      AppRoutes.statistics,
      AppRoutes.profile,
      AppRoutes.settings,
    };

    expect(routes, hasLength(10));
  });
}
