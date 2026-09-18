import 'package:go_router/go_router.dart';

import 'features/auth/account_screen.dart';
import 'features/home/home_screen.dart';
import 'features/point_buy/point_buy_screen.dart';

/// Routes de l'app. Les chemins sont aussi les URL sur le web.
abstract final class AppRoutes {
  static const home = '/';
  static const pointBuy = '/point-buy';
  static const account = '/account';
}

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const HomeScreen(),
      routes: [
        GoRoute(
          path: 'point-buy',
          builder: (context, state) => const PointBuyScreen(),
        ),
        GoRoute(
          path: 'account',
          builder: (context, state) => const AccountScreen(),
        ),
      ],
    ),
  ],
);
