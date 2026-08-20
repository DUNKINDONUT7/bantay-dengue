import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'navigation/app_router.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';
import 'widgets/entry_sync_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Paint the entry state immediately instead of leaving a blank frame while
  // Supabase restores its local session.
  runApp(const BantayDengueBootstrap());
}

class BantayDengueBootstrap extends StatefulWidget {
  const BantayDengueBootstrap({super.key});

  @override
  State<BantayDengueBootstrap> createState() => _BantayDengueBootstrapState();
}

class _BantayDengueBootstrapState extends State<BantayDengueBootstrap> {
  bool _ready = false;
  Object? _startupError;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      _ready = false;
      _startupError = null;
    });
    try {
      if (SupabaseConfig.isConfigured) {
        await Supabase.initialize(
          url: SupabaseConfig.url,
          publishableKey: SupabaseConfig.publishableKey,
        );
      }
      initializeAuthService();
      if (mounted) setState(() => _ready = true);
    } catch (error) {
      if (mounted) setState(() => _startupError = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const BantayDengueApp();
    return MaterialApp(
      title: 'BantayDengue',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: Scaffold(
        body: _startupError == null
            ? const EntrySyncView(
                title: 'Starting BantayDengue',
                message:
                    'Restoring your secure session and preparing the system.\nThis usually takes a few seconds.',
              )
            : _StartupError(error: _startupError!, onRetry: _initialize),
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _StartupError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 36),
                  const SizedBox(height: 18),
                  Text(
                    'Unable to start the system',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$error',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BantayDengueApp extends StatefulWidget {
  const BantayDengueApp({super.key});

  @override
  State<BantayDengueApp> createState() => _BantayDengueAppState();
}

class _BantayDengueAppState extends State<BantayDengueApp> {
  late final GoRouter _router = createAppRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'BantayDengue',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      routerConfig: _router,
    );
  }
}
