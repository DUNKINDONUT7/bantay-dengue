import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/entry_sync_view.dart';

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
                      _LandingHeader(wide: wide),
                      SizedBox(height: wide ? 76 : 52),
                      if (wide)
                        const Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(flex: 11, child: _HeroCopy(wide: true)),
                            SizedBox(width: 64),
                            Expanded(flex: 9, child: _ResponsePreview()),
                          ],
                        )
                      else
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _HeroCopy(wide: false),
                            SizedBox(height: 36),
                            _ResponsePreview(),
                          ],
                        ),
                      SizedBox(height: wide ? 80 : 48),
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
  final bool wide;

  const _LandingHeader({required this.wide});

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
          child: const Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.shield, color: AppColors.onPrimary, size: 25),
              Icon(Icons.pest_control, color: AppColors.primary, size: 11),
            ],
          ),
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
        if (wide) ...[
          const _HeaderTag(icon: Icons.shield_outlined, text: 'Role protected'),
          const SizedBox(width: 9),
          const _HeaderTag(icon: Icons.phone_iphone, text: 'Mobile first'),
          const SizedBox(width: 16),
        ],
        OutlinedButton(
          onPressed: () => context.go('/login'),
          child: Text(wide ? 'Sign in' : 'Login'),
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
        Text(
          'Report sooner.\nRespond smarter.',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: wide ? 55 : 40,
            height: 0.98,
            letterSpacing: wide ? -2.2 : -1.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 570),
          child: Text(
            'A secure, role-based dengue surveillance app that connects residents, barangay health workers, waste personnel, and administrators in one coordinated system.',
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
            final create = FilledButton.icon(
              onPressed: () => context.go('/signup'),
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('Create resident account'),
            );
            final signIn = OutlinedButton(
              onPressed: () => context.go('/login'),
              child: const Text('Open my workspace'),
            );
            if (stack) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [create, const SizedBox(height: 10), signIn],
              );
            }
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [create, signIn],
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

class _ResponsePreview extends StatelessWidget {
  const _ResponsePreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.grid_view_rounded,
                  color: AppColors.onPrimary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Community response',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Role-specific workspaces',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _WorkspaceRow(
            icon: Icons.home_outlined,
            title: 'Resident',
            detail: 'Reports, appointments, and waste requests',
          ),
          const SizedBox(height: 8),
          const _WorkspaceRow(
            icon: Icons.health_and_safety_outlined,
            title: 'Health Center',
            detail: 'Verification and clinical coordination',
          ),
          const SizedBox(height: 8),
          const _WorkspaceRow(
            icon: Icons.delete_sweep_outlined,
            title: 'Waste Personnel',
            detail: 'Separate collection operations dashboard',
          ),
          const SizedBox(height: 8),
          const _WorkspaceRow(
            icon: Icons.admin_panel_settings_outlined,
            title: 'Administrator',
            detail: 'Users, access, analytics, and advisories',
          ),
        ],
      ),
    );
  }
}

class _WorkspaceRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;

  const _WorkspaceRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ],
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
          _Capability(
            icon: Icons.fact_check_outlined,
            text: 'Verified workflows',
          ),
          _Capability(icon: Icons.map_outlined, text: 'OpenStreetMap hotspots'),
          _Capability(
            icon: Icons.notifications_none,
            text: 'Status notifications',
          ),
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

class _HeaderTag extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HeaderTag({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.textMuted,
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
/// black background.
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
            final t = _controller.value * 2 * 3.14159265;
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
