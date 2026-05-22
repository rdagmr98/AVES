import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'constants/app_constants.dart';
import 'providers/auth_provider.dart';
import 'providers/currency_provider.dart';
import 'screens/activities/add_activity_screen.dart';
import 'screens/activities/my_activities_screen.dart';
import 'screens/admin/currency_settings_screen.dart';
import 'screens/admin/insert_activity_admin_screen.dart';
import 'screens/admin/user_management_screen.dart';
import 'screens/admin/validate_activities_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/dashboard/admin_crew_dashboard.dart';
import 'screens/dashboard/admin_privileges_dashboard.dart';
import 'screens/dashboard/user_dashboard.dart';
import 'screens/profile/profile_screen.dart';

final authProvider = ChangeNotifierProvider<AuthProvider>(
  (ref) => AuthProvider(),
);
final currencyProviderProv = ChangeNotifierProvider<CurrencyProvider>(
  (ref) => CurrencyProvider(),
);

class AvesApp extends ConsumerStatefulWidget {
  const AvesApp({super.key});

  @override
  ConsumerState<AvesApp> createState() => _AvesAppState();
}

class _AvesAppState extends ConsumerState<AvesApp> {
  late final GoRouter _router = GoRouter(
    initialLocation: '/',
    refreshListenable: ref.read(authProvider),
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const _RouterSplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const UserDashboard(),
      ),
      GoRoute(
        path: '/admin/priv',
        builder: (context, state) => const AdminPrivilegesDashboard(),
      ),
      GoRoute(
        path: '/admin/crew',
        builder: (context, state) => const AdminCrewDashboard(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/activities/add',
        builder: (context, state) => const AddActivityScreen(),
      ),
      GoRoute(
        path: '/activities/my',
        builder: (context, state) => const MyActivitiesScreen(),
      ),
      GoRoute(
        path: '/admin/validate',
        builder: (context, state) => const ValidateActivitiesScreen(),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (context, state) => const UserManagementScreen(),
      ),
      GoRoute(
        path: '/admin/settings',
        builder: (context, state) => const CurrencySettingsScreen(),
      ),
      GoRoute(
        path: '/admin/insert',
        builder: (context, state) => const InsertActivityAdminScreen(),
      ),
    ],
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final location = state.matchedLocation;
      const publicRoutes = {'/', '/login', '/register'};
      const adminRoutes = {
        '/admin/priv',
        '/admin/crew',
        '/admin/validate',
        '/admin/users',
        '/admin/settings',
        '/admin/insert',
      };

      String defaultHome() {
        if (auth.isAdminPriv) {
          return '/admin/priv';
        }
        if (auth.isAdminCrew) {
          return '/admin/crew';
        }
        return '/dashboard';
      }

      if (!auth.initialized) {
        return location == '/' ? null : '/';
      }

      if (!auth.isAuthenticated) {
        if (location == '/') {
          return '/login';
        }
        return publicRoutes.contains(location) ? null : '/login';
      }

      if (location == '/' || location == '/login' || location == '/register') {
        return defaultHome();
      }

      if (location == '/dashboard' &&
          !auth.isAdmin &&
          auth.role != AppStrings.roleUser) {
        return defaultHome();
      }

      if ((location == '/admin/priv' || location == '/admin/settings') &&
          !auth.isAdminPriv) {
        return defaultHome();
      }

      if (location == '/admin/crew' && !auth.isAdminCrew) {
        return defaultHome();
      }

      if (adminRoutes.contains(location) && !auth.isAdmin) {
        return defaultHome();
      }

      return null;
    },
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: _router,
    );
  }
}

class _RouterSplashScreen extends StatelessWidget {
  const _RouterSplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
