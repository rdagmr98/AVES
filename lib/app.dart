// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'constants/app_constants.dart';
import 'providers/auth_provider.dart';
import 'providers/currency_provider.dart';

import 'screens/activities/add_activity_screen.dart';
import 'screens/activities/my_activities_screen.dart';
import 'screens/activities/pta_screen.dart';
import 'screens/admin/currency_settings_screen.dart';
import 'screens/admin/insert_activity_admin_screen.dart';
import 'screens/admin/pta_management_screen.dart';
import 'screens/admin/user_management_screen.dart';
import 'screens/admin/validate_activities_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/dashboard/admin_crew_dashboard.dart';
import 'screens/dashboard/admin_p66_dashboard.dart';
import 'screens/dashboard/admin_privileges_dashboard.dart';
import 'screens/dashboard/user_dashboard.dart';
import 'screens/helicopters/helicopter_detail_screen.dart';
import 'screens/helicopters/my_fleet_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'services/gh_db_service.dart';

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
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  late final StreamSubscription<html.Event> _unloadSub;

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
        path: '/admin/p66',
        builder: (context, state) => const AdminP66Dashboard(),
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
        builder: (context, state) => AddActivityScreen(
          initialTab: int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/activities/my',
        builder: (context, state) =>
            MyActivitiesScreen(initialType: state.uri.queryParameters['type']),
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
      GoRoute(
        path: '/admin/pta',
        builder: (context, state) => const PtaManagementScreen(),
      ),
      GoRoute(path: '/pta', builder: (context, state) => const PtaScreen()),
      GoRoute(
        path: '/helicopters/fleet',
        builder: (context, state) => const MyFleetScreen(),
      ),
      GoRoute(
        path: '/helicopters/:id',
        builder: (context, state) => HelicopterDetailScreen(
          helicopterId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
    ],
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final location = state.matchedLocation;
      const publicRoutes = {'/', '/login', '/register'};
      const adminPrivRoutes = {'/admin/priv', '/admin/pta', '/admin/p66'};
      const adminRoutes = {
        '/admin/priv',
        '/admin/crew',
        '/admin/validate',
        '/admin/users',
        '/admin/settings',
        '/admin/insert',
        '/admin/pta',
        '/admin/p66',
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

      // /register resta: signUp autentica, ma la schermata deve completare
      // licenze/privilegi, mostrare il dialog e fare logout.
      if (location == '/' || location == '/login') {
        return defaultHome();
      }

      if (location == '/dashboard' &&
          !auth.isAdmin &&
          auth.role != AppStrings.roleUser) {
        return defaultHome();
      }

      if (adminPrivRoutes.contains(location) && !auth.isAdminPriv) {
        return defaultHome();
      }

      if ((location == '/admin/settings') && !auth.isAdmin) {
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
    GhDbService.saveError.addListener(_onSaveError);
    // Salvataggi in coda non ancora su GitHub: il browser chiede conferma prima
    // di chiudere/ricaricare, così una F5 subito dopo "Salva" non perde dati.
    _unloadSub = html.window.onBeforeUnload.listen((e) {
      if (GhDbService.pendingSaves.value > 0) {
        (e as html.BeforeUnloadEvent).returnValue = 'Salvataggio in corso';
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider).initialize();
    });
  }

  @override
  void dispose() {
    GhDbService.saveError.removeListener(_onSaveError);
    _unloadSub.cancel();
    super.dispose();
  }

  void _onSaveError() {
    if (GhDbService.saveError.value == null) return;
    _messengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text(
          'Salvataggio non riuscito. Controlla la connessione e riprova.',
        ),
        backgroundColor: AppColors.currencyExpired,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppStrings.appName,
      scaffoldMessengerKey: _messengerKey,
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
