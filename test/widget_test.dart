import 'package:bantay_dengue/config/supabase_config.dart';
import 'package:bantay_dengue/main.dart';
import 'package:bantay_dengue/models/user_model.dart';
import 'package:bantay_dengue/navigation/main_shell.dart';
import 'package:bantay_dengue/screens/login_screen.dart';
import 'package:bantay_dengue/screens/splash_screen.dart';
import 'package:bantay_dengue/screens/waste_personnel_account_screen.dart';
import 'package:bantay_dengue/services/auth_service.dart';
import 'package:bantay_dengue/theme/app_theme.dart';
import 'package:bantay_dengue/widgets/entry_sync_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
    initializeAuthService();
  });

  testWidgets('App starts on the authenticated router shell', (tester) async {
    await tester.pumpWidget(const BantayDengueApp());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });

  test('backend role values map to fenced homes', () {
    expect(userRoleFromString('resident'), UserRole.civilian);
    expect(userRoleFromString('health_worker'), UserRole.doctor);
    expect(userRoleFromString('waste_personnel'), UserRole.wastePersonnel);
    expect(userRoleFromString('waste_staff'), UserRole.wastePersonnel);
    expect(userRoleFromString('waste_management'), UserRole.wastePersonnel);
    expect(userRoleFromString('admin'), UserRole.admin);
    expect(userRoleToString(UserRole.wastePersonnel), 'waste_personnel');
    expect(roleHomePath(UserRole.wastePersonnel), '/waste-management');
  });

  test('profiles without migration column stay active', () {
    final profile = UserModel.fromProfile({
      'id': '00000000-0000-0000-0000-000000000001',
      'full_name': 'Resident',
      'email': 'resident@example.com',
      'role': 'resident',
    });
    expect(profile.isActive, isTrue);
  });

  testWidgets('entry sync view explains progress and supports cancellation', (
    tester,
  ) async {
    var cancelled = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: EntrySyncView(onCancel: () => cancelled = true),
      ),
    );

    expect(find.text('Syncing your account'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    expect(cancelled, isTrue);
  });

  test('mobile More navigation retains every role-authorized destination', () {
    final roleLists = [
      [...civilianNavItems, ...civilianExtraNavItems],
      [...doctorNavItems, ...doctorExtraNavItems],
      [...wasteNavItems, ...wasteExtraNavItems],
      [...adminNavItems, ...adminExtraNavItems],
    ];

    for (final items in roleLists) {
      expect(items.map((item) => item.path).toSet().length, items.length);
      expect(items.every((item) => item.path.startsWith('/')), isTrue);
    }
  });

  test('dark primary controls use high-contrast monochrome foreground', () {
    final scheme = AppTheme.darkTheme.colorScheme;
    expect(scheme.primary, AppColors.primary);
    expect(scheme.onPrimary, AppColors.onPrimary);
    expect(
      ThemeData.estimateBrightnessForColor(scheme.primary),
      Brightness.light,
    );
    expect(
      ThemeData.estimateBrightnessForColor(scheme.onPrimary),
      Brightness.dark,
    );
  });

  testWidgets('landing and login stay usable at phone width', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.darkTheme, home: const SplashScreen()),
    );
    expect(find.text('Report sooner.\nRespond smarter.'), findsOneWidget);
    expect(find.text('Create resident account'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.darkTheme, home: const LoginScreen()),
    );
    await tester.pump();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in securely'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Waste Personnel receives a dedicated account workspace', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const WastePersonnelAccountScreen(),
      ),
    );
    expect(find.text('Personnel account'), findsOneWidget);
    expect(find.text('Waste operations only'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
