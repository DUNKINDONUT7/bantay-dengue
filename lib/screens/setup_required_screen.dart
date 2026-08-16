import 'package:flutter/material.dart';
import '../config/supabase_config.dart';
import '../theme/app_theme.dart';

/// Shown instead of crashing when the app is launched without Supabase
/// credentials. See lib/config/supabase_config.dart and env.json.example.
class SetupRequiredScreen extends StatelessWidget {
  const SetupRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reason =
        SupabaseConfig.invalidReason ??
        'Copy env.json.example to env.json, fill in your Supabase URL and anon key, then run the app with:\n\nflutter run --dart-define-from-file=env.json';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, color: AppColors.warning, size: 56),
              const SizedBox(height: 20),
              const Text(
                'Supabase is not configured',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                reason,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
