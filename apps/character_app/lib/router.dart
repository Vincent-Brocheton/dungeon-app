import 'package:go_router/go_router.dart';

import 'features/admin/admin_dashboard_screen.dart';
import 'features/admin/admin_editor_stub_screen.dart';
import 'features/auth/account_screen.dart';
import 'features/home/home_screen.dart';
import 'features/point_buy/point_buy_screen.dart';

/// Routes de l'app. Les chemins sont aussi les URL sur le web.
abstract final class AppRoutes {
  static const home = '/';
  static const pointBuy = '/point-buy';
  static const account = '/account';
  static const admin = '/admin';
  static const adminSpecies = '/admin/species';
  static const adminSubspecies = '/admin/subspecies';
  static const adminClasses = '/admin/classes';
  static const adminSubclasses = '/admin/subclasses';
  static const adminSpells = '/admin/spells';
  static const adminFeats = '/admin/feats';
  static const adminBackgrounds = '/admin/backgrounds';
  static const adminInvocations = '/admin/invocations';
  static const adminLevelProgression = '/admin/level-progression';
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
        GoRoute(
          path: 'admin',
          builder: (context, state) => const AdminDashboardScreen(),
          routes: [
            GoRoute(
              path: 'species',
              builder:
                  (context, state) =>
                      const AdminEditorStubScreen(title: 'Espèces'),
            ),
            GoRoute(
              path: 'subspecies',
              builder:
                  (context, state) =>
                      const AdminEditorStubScreen(title: 'Sous-espèces'),
            ),
            GoRoute(
              path: 'classes',
              builder:
                  (context, state) =>
                      const AdminEditorStubScreen(title: 'Classes'),
            ),
            GoRoute(
              path: 'subclasses',
              builder:
                  (context, state) =>
                      const AdminEditorStubScreen(title: 'Sous-classes'),
            ),
            GoRoute(
              path: 'spells',
              builder:
                  (context, state) =>
                      const AdminEditorStubScreen(title: 'Sorts'),
            ),
            GoRoute(
              path: 'feats',
              builder:
                  (context, state) =>
                      const AdminEditorStubScreen(title: 'Dons'),
            ),
            GoRoute(
              path: 'backgrounds',
              builder:
                  (context, state) =>
                      const AdminEditorStubScreen(title: 'Historiques'),
            ),
            GoRoute(
              path: 'invocations',
              builder:
                  (context, state) => const AdminEditorStubScreen(
                    title: 'Manifestations occultes',
                  ),
            ),
            GoRoute(
              path: 'level-progression',
              builder:
                  (context, state) => const AdminEditorStubScreen(
                    title: 'Tables de progression',
                  ),
            ),
          ],
        ),
      ],
    ),
  ],
);
