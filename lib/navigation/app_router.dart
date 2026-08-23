import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/supabase_config.dart';
import '../models/user_model.dart';
import '../screens/account_suspended_screen.dart';
import '../screens/admin_dashboard.dart';
import '../screens/admin_waste_overview_screen.dart';
import '../screens/announcements_screen.dart';
import '../screens/civilian/advisories_screen.dart';
import '../screens/civilian/ai_chat_screen.dart';
import '../screens/civilian/appointments_screen.dart';
import '../screens/civilian/community_screen.dart';
import '../screens/civilian/hotspot_map_screen.dart';
import '../screens/civilian/profile_screen.dart';
import '../screens/civilian/report_breeding_screen.dart';
import '../screens/civilian/report_case_screen.dart';
import '../screens/civilian/report_history_screen.dart';
import '../screens/civilian/report_hub_screen.dart';
import '../screens/civilian/waste_collection_screen.dart';
import '../screens/dashboard_screen.dart';
import '../widgets/request_waste_screen.dart';
import '../screens/health_worker_dashboard.dart';
import '../screens/login_screen.dart';
import '../screens/setup_required_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/staff_appointments_screen.dart';
import '../screens/user_management_screen.dart';
import '../screens/verification_queue_screen.dart';
import '../screens/waste_collection_map_screen.dart';
import '../screens/waste_management_dashboard.dart';
import '../screens/waste_personnel_account_screen.dart';
import '../services/auth_service.dart';
import 'main_shell.dart';

CustomTransitionPage<void> _fadePage(Widget child) =>
    CustomTransitionPage<void>(
      child: child,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 140),
      transitionsBuilder: (_, animation, __, widget) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: widget,
      ),
    );

GoRouter createAppRouter() => GoRouter(
  initialLocation: '/splash',
  refreshListenable: authService,
  redirect: (context, state) {
    final location = state.matchedLocation;
    if (!SupabaseConfig.isConfigured) {
      return location == '/setup' ? null : '/setup';
    }

    final authRoute = location == '/login' || location == '/signup';
    final splash = location == '/splash';
    if (!authService.isAuthenticated) {
      return authRoute || splash ? null : '/login';
    }

    final profile = authService.profile;
    if (profile == null) return splash ? null : '/splash';
    if (!profile.isActive) {
      return location == '/suspended' ? null : '/suspended';
    }

    final home = roleHomePath(profile.role);
    if (authRoute || splash || location == '/suspended') return home;
    if (location.startsWith('/civilian') && profile.role != UserRole.civilian) {
      return home;
    }
    if (location.startsWith('/doctor') && profile.role != UserRole.doctor) {
      return home;
    }
    if (location.startsWith('/waste-management') &&
        profile.role != UserRole.wastePersonnel) {
      return home;
    }
    if (location.startsWith('/admin') && profile.role != UserRole.admin) {
      return home;
    }
    return null;
  },
  routes: [
    GoRoute(path: '/setup', builder: (_, __) => const SetupRequiredScreen()),
    GoRoute(
      path: '/suspended',
      builder: (_, __) => const AccountSuspendedScreen(),
    ),
    GoRoute(
      path: '/splash',
      pageBuilder: (_, __) => _fadePage(const SplashScreen()),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (_, __) => _fadePage(const LoginScreen()),
    ),
    GoRoute(
      path: '/signup',
      pageBuilder: (_, __) => _fadePage(const SignupScreen()),
    ),

    ShellRoute(
      builder: (_, __, child) => RoleShell(
        navItems: civilianNavItems,
        extraNavItems: civilianExtraNavItems,
        roleLabel: 'Resident',
        child: child,
      ),
      routes: [
        GoRoute(
          path: '/civilian/home',
          builder: (_, __) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/civilian/report',
          builder: (_, __) => const ReportHubScreen(),
        ),
        GoRoute(
          path: '/civilian/report/case',
          builder: (_, __) => const ReportCaseScreen(),
        ),
        GoRoute(
          path: '/civilian/report/breeding',
          builder: (_, __) => const ReportBreedingScreen(),
        ),
        GoRoute(
          path: '/civilian/report/history',
          builder: (_, __) => const ReportHistoryScreen(),
        ),
        GoRoute(
          path: '/civilian/assistant',
          builder: (_, __) => const AiChatScreen(),
        ),
        GoRoute(
          path: '/civilian/community',
          builder: (_, __) => const CommunityScreen(),
        ),
        GoRoute(
          path: '/civilian/appointments',
          builder: (_, __) => const AppointmentsScreen(),
        ),
        GoRoute(
          path: '/civilian/map',
          builder: (_, __) => const HotspotMapScreen(),
        ),
        GoRoute(
          path: '/civilian/waste',
          builder: (_, __) => const WasteCollectionScreen(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (_, __) => const RequestWasteScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/civilian/advisories',
          builder: (_, __) => const AdvisoriesScreen(),
        ),
        GoRoute(
          path: '/civilian/profile',
          builder: (_, __) => const ProfileScreen(),
        ),
      ],
    ),

    ShellRoute(
      builder: (_, __, child) => RoleShell(
        navItems: doctorNavItems,
        extraNavItems: doctorExtraNavItems,
        roleLabel: 'Barangay Health Center',
        child: child,
      ),
      routes: [
        GoRoute(
          path: '/doctor',
          builder: (_, __) => const HealthWorkerDashboard(),
        ),
        GoRoute(
          path: '/doctor/verification',
          builder: (_, __) => const VerificationQueueScreen(),
        ),
        GoRoute(
          path: '/doctor/appointments',
          builder: (_, __) => const StaffAppointmentsScreen(),
        ),
        GoRoute(
          path: '/doctor/hotspots',
          builder: (_, __) => const HotspotMapScreen(),
        ),
        GoRoute(
          path: '/doctor/advisories',
          builder: (_, __) => const AdvisoriesScreen(),
        ),
        GoRoute(
          path: '/doctor/profile',
          builder: (_, __) => const ProfileScreen(),
        ),
      ],
    ),

    ShellRoute(
      builder: (_, __, child) => RoleShell(
        navItems: wasteNavItems,
        extraNavItems: wasteExtraNavItems,
        roleLabel: 'Waste Personnel',
        child: child,
      ),
      routes: [
        GoRoute(
          path: '/waste-management',
          builder: (_, __) => const WasteManagementDashboard(),
        ),
        GoRoute(
          path: '/waste-management/collection-map',
          builder: (_, __) => const WasteCollectionMapScreen(),
        ),
        GoRoute(
          path: '/waste-management/advisories',
          builder: (_, __) => const AdvisoriesScreen(),
        ),
        GoRoute(
          path: '/waste-management/account',
          builder: (_, __) => const WastePersonnelAccountScreen(),
        ),
        GoRoute(
          path: '/waste-management/profile',
          redirect: (_, __) => '/waste-management/account',
        ),
      ],
    ),

    ShellRoute(
      builder: (_, __, child) => RoleShell(
        navItems: adminNavItems,
        extraNavItems: adminExtraNavItems,
        roleLabel: 'Administrator',
        child: child,
      ),
      routes: [
        GoRoute(path: '/admin', builder: (_, __) => const AdminDashboard()),
        GoRoute(
          path: '/admin/users',
          builder: (_, __) => const UserManagementScreen(),
        ),
        GoRoute(
          path: '/admin/verification',
          builder: (_, __) => const VerificationQueueScreen(),
        ),
        GoRoute(
          path: '/admin/hotspots',
          builder: (_, __) => const HotspotMapScreen(),
        ),
        GoRoute(
          path: '/admin/waste',
          builder: (_, __) => const AdminWasteOverviewScreen(),
        ),
        GoRoute(
          path: '/admin/community',
          builder: (_, __) => const CommunityScreen(),
        ),
        GoRoute(
          path: '/admin/announcements',
          builder: (_, __) => const AnnouncementsScreen(),
        ),
        GoRoute(
          path: '/admin/advisories',
          builder: (_, __) => const AdvisoriesScreen(),
        ),
        GoRoute(
          path: '/admin/profile',
          builder: (_, __) => const ProfileScreen(),
        ),
      ],
    ),
  ],
);
