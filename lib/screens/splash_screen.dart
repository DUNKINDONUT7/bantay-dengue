import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/entry_sync_view.dart';
import '../widgets/mosquito_hero.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (authService.isAuthenticated) {
      return Scaffold(
        body: EntrySyncView(
          title: 'Syncing your account',
          message:
              "We're loading your latest records and verified workspace.\nThis usually takes a few seconds.",
          onCancel: () async {
            await authService.signOut();
            if (context.mounted) context.go('/login');
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _AnimatedLandingBackground()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 860;
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    constraints.maxWidth < 400 ? 16 : 24,
                    18,
                    constraints.maxWidth < 400 ? 16 : 24,
                    28,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _LandingHeader(),
                          SizedBox(height: wide ? 64 : 40),
                          if (wide)
                            const Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(flex: 11, child: _HeroCopy(wide: true)),
                                SizedBox(width: 48),
                                Expanded(
                                  flex: 9,
                                  child: Center(child: MosquitoHero(size: 260)),
                                ),
                              ],
                            )
                          else
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Center(child: MosquitoHero(size: 190)),
                                SizedBox(height: 12),
                                _HeroCopy(wide: false),
                              ],
                            ),
                          SizedBox(height: wide ? 64 : 40),
                          const _CapabilityStrip(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingHeader extends StatelessWidget {
  const _LandingHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(Icons.shield, color: AppColors.onPrimary, size: 22),
        ),
        const SizedBox(width: 11),
        const Expanded(
          child: Text(
            'BantayDengue',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
        ),
        OutlinedButton(
          onPressed: () => context.go('/login'),
          child: const Text('Sign in'),
        ),
      ],
    );
  }
}

class _HeroCopy extends StatelessWidget {
  final bool wide;

  const _HeroCopy({required this.wide});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.border),
          ),
          child: const Text(
            'COMMUNITY HEALTH · SDG 3',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Report sooner.\n',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: wide ? 58 : 42,
                  height: 0.98,
                  letterSpacing: wide ? -2.4 : -1.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(
                text: 'Respond smarter.',
                style: TextStyle(
                  color: AppColors.danger,
                  fontStyle: FontStyle.italic,
                  fontSize: wide ? 58 : 42,
                  height: 0.98,
                  letterSpacing: wide ? -2.4 : -1.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Text(
            'A secure, role-based dengue surveillance app connecting residents, barangay health workers, waste personnel, and administrators in one coordinated system.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
              fontSize: wide ? 17 : 15.5,
              height: 1.55,
            ),
          ),
        ),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, constraints) {
            final stack = constraints.maxWidth < 390;
            final getStarted = FilledButton.icon(
              onPressed: () => _openRolePicker(context),
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('Get started'),
            );
            final signIn = OutlinedButton(
              onPressed: () => context.go('/login'),
              child: const Text('Sign in'),
            );
            if (stack) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [getStarted, const SizedBox(height: 10), signIn],
              );
            }
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [getStarted, signIn],
            );
          },
        ),
        const SizedBox(height: 22),
        const Row(
          children: [
            Icon(Icons.lock_outline, size: 15),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Secure Supabase authentication · private evidence · role-based access',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One modal for every screen size: a role picker is a short, occasional
/// decision, not something that deserves permanent hero real estate. Reuses
/// the app's existing showModalBottomSheet convention (see
/// notifications_panel.dart / main_shell.dart's "More" sheet).
Future<void> _openRolePicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose your workspace',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            const Text(
              "One secure sign-in — pick where you're headed.",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 18),
            _RoleRow(
              icon: Icons.home_outlined,
              title: 'Resident',
              detail: 'Reports, appointments, and waste requests',
              cta: 'Create account',
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.go('/signup');
              },
            ),
            const SizedBox(height: 8),
            _RoleRow(
              icon: Icons.health_and_safety_outlined,
              title: 'Health Center',
              detail: 'Verification and clinical coordination',
              cta: 'Sign in',
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.go('/login');
              },
            ),
            const SizedBox(height: 8),
            _RoleRow(
              icon: Icons.delete_sweep_outlined,
              title: 'Waste Personnel',
              detail: 'Collection operations dashboard',
              cta: 'Sign in',
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.go('/login');
              },
            ),
            const SizedBox(height: 8),
            _RoleRow(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Administrator',
              detail: 'Users, access, analytics, and advisories',
              cta: 'Sign in',
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.go('/login');
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'New accounts start as Residents. Health Worker, Waste Personnel, '
              'and Administrator access is assigned separately by an administrator.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11.5, height: 1.4),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RoleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final String cta;
  final VoidCallback onTap;

  const _RoleRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.cta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    cta,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CapabilityStrip extends StatelessWidget {
  const _CapabilityStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: const Wrap(
        alignment: WrapAlignment.spaceAround,
        spacing: 22,
        runSpacing: 12,
        children: [
          _Capability(icon: Icons.fact_check_outlined, text: 'Verified workflows'),
          _Capability(icon: Icons.map_outlined, text: 'OpenStreetMap hotspots'),
          _Capability(icon: Icons.notifications_none, text: 'Status notifications'),
          _Capability(icon: Icons.shield_outlined, text: 'Supabase RLS'),
        ],
      ),
    );
  }
}

class _Capability extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Capability({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 7),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Slow, looping soft-glow background for the landing page. Pure Flutter
/// (a few radial gradients drifting on sine curves), no video/image asset —
/// keeps the landing page lightweight and avoids an extra network fetch on
/// first load, while still giving the page some life instead of a flat
/// background.
class _AnimatedLandingBackground extends StatefulWidget {
  const _AnimatedLandingBackground();

  @override
  State<_AnimatedLandingBackground> createState() =>
      _AnimatedLandingBackgroundState();
}

class _AnimatedLandingBackgroundState
    extends State<_AnimatedLandingBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value * 2 * math.pi;
            return Stack(
              children: [
                _blob(
                  context,
                  color: AppColors.primary,
                  alignX: 0.6 * (0.5 + 0.5 * _sin(t)),
                  alignY: -0.8 + 0.3 * _sin(t * 0.7),
                  size: 420,
                  opacity: 0.10,
                ),
                _blob(
                  context,
                  color: AppColors.success,
                  alignX: -0.7 + 0.3 * _sin(t * 0.5 + 2),
                  alignY: 0.7 * (0.5 + 0.5 * _sin(t * 0.8 + 1)),
                  size: 360,
                  opacity: 0.08,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  double _sin(double v) => math.sin(v);

  Widget _blob(
    BuildContext context, {
    required Color color,
    required double alignX,
    required double alignY,
    required double size,
    required double opacity,
  }) {
    return Align(
      alignment: Alignment(alignX, alignY),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
