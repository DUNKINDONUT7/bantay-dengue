import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    return const _LandingPage();
  }
}

class _LandingPage extends StatefulWidget {
  const _LandingPage();

  @override
  State<_LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<_LandingPage> {
  final _scrollController = ScrollController();
  final _howItWorksKey = GlobalKey();

  void _scrollToHowItWorks() {
    final ctx = _howItWorksKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(
                    constraints.maxWidth < 400 ? 16 : 24,
                    18,
                    constraints.maxWidth < 400 ? 16 : 24,
                    40,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _LandingHeader(
                            wide: wide,
                            onHowItWorks: _scrollToHowItWorks,
                          ),
                          SizedBox(height: wide ? 56 : 36),
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  flex: 11,
                                  child: _HeroCopy(
                                    wide: true,
                                    onHowItWorks: _scrollToHowItWorks,
                                  ),
                                ),
                                const SizedBox(width: 48),
                                const Expanded(
                                  flex: 9,
                                  child: Center(child: _HeroVisual(size: 240)),
                                ),
                              ],
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Center(child: _HeroVisual(size: 170)),
                                const SizedBox(height: 12),
                                _HeroCopy(
                                  wide: false,
                                  onHowItWorks: _scrollToHowItWorks,
                                ),
                              ],
                            ),
                          SizedBox(height: wide ? 56 : 36),
                          _QuickActionsRow(wide: wide),
                          const SizedBox(height: 16),
                          _CapabilityStrip(wide: wide),
                          SizedBox(height: wide ? 72 : 48),
                          _HowItWorksSection(key: _howItWorksKey, wide: wide),
                          SizedBox(height: wide ? 72 : 48),
                          _RoleWorkflowSection(wide: wide),
                          SizedBox(height: wide ? 64 : 40),
                          _FinalCta(wide: wide),
                          SizedBox(height: wide ? 32 : 24),
                          _TrustStatusBar(wide: wide),
                          const SizedBox(height: 20),
                          const _LandingFooter(),
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
  final VoidCallback onHowItWorks;
  const _LandingHeader({required this.wide, required this.onHowItWorks});

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
        // Only real destinations here — no "Community safety"/"About" links,
        // those pages don't exist in this app and a landing page with dead
        // nav links reads as unfinished, not premium.
        if (wide) ...[
          TextButton(
            onPressed: onHowItWorks,
            child: const Text('How it works'),
          ),
          const SizedBox(width: 4),
        ],
        OutlinedButton(
          onPressed: () => context.go('/login'),
          child: const Text('Sign in'),
        ),
        if (wide) ...[
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => context.go('/signup'),
            child: const Text('Report a concern'),
          ),
        ],
      ],
    );
  }
}

class _HeroCopy extends StatelessWidget {
  final bool wide;
  final VoidCallback onHowItWorks;

  const _HeroCopy({required this.wide, required this.onHowItWorks});

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
                text: 'See a risk. Report it.\n',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: wide ? 54 : 40,
                  height: 0.98,
                  letterSpacing: wide ? -2.2 : -1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(
                text: 'Protect your community.',
                style: TextStyle(
                  color: AppColors.danger,
                  fontStyle: FontStyle.italic,
                  fontSize: wide ? 54 : 40,
                  height: 0.98,
                  letterSpacing: wide ? -2.2 : -1.5,
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
            // Renamed from "Get started" — this app has exactly one thing a
            // first-time visitor does, so the button should say that
            // instead of a generic label.
            final reportConcern = FilledButton.icon(
              onPressed: () => context.go('/signup'),
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('Report a concern'),
            );
            final howItWorks = OutlinedButton(
              onPressed: onHowItWorks,
              child: const Text('How it works'),
            );
            if (stack) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  reportConcern,
                  const SizedBox(height: 10),
                  howItWorks,
                ],
              );
            }
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [reportConcern, howItWorks],
            );
          },
        ),
        const SizedBox(height: 10),
        const Text(
          'Report a dengue concern or possible mosquito breeding site.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 18),
        const Row(
          children: [
            Icon(Icons.lock_outline, size: 15),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Your reports are protected and only accessible to authorized personnel.',
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

/// The mosquito plus a light "surveillance" treatment around it — soft
/// radar-style rings and a couple of pulsing location dots, so the hero
/// reads as "monitoring system" rather than a static mascot. Deliberately
/// stops short of a literal dashboard/map in the hero (kept for the
/// Community Intelligence discussion, not built this pass) — a first-time
/// visitor's hero should stay elegant, not busy.
class _HeroVisual extends StatelessWidget {
  final double size;
  const _HeroVisual({required this.size});

  @override
  Widget build(BuildContext context) {
    final stageSize = size + 70;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: stageSize,
          height: stageSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _RadarRings(size: stageSize),
              MosquitoHero(size: size),
              Positioned(
                top: stageSize * 0.08,
                right: stageSize * 0.10,
                child: const _PulseDot(color: AppColors.danger),
              ),
              Positioned(
                bottom: stageSize * 0.16,
                left: stageSize * 0.06,
                child: const _PulseDot(color: AppColors.warning),
              ),
              Positioned(
                top: stageSize * 0.34,
                left: stageSize * 0.0,
                child: const _PulseDot(color: AppColors.info),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              const Text(
                'ACTIVE COMMUNITY MONITORING',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Two expanding, fading rings offset by half a cycle — a subtle radar-ping
/// read without a custom shader or extra package, just two animated
/// Containers with circular borders.
class _RadarRings extends StatefulWidget {
  final double size;
  const _RadarRings({required this.size});

  @override
  State<_RadarRings> createState() => _RadarRingsState();
}

class _RadarRingsState extends State<_RadarRings>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            _ring((t) % 1),
            _ring((t + 0.5) % 1),
          ],
        );
      },
    );
  }

  Widget _ring(double phase) {
    final diameter = widget.size * (0.5 + 0.5 * phase);
    final opacity = (1 - phase) * 0.22;
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.danger.withValues(alpha: opacity),
          width: 1.4,
        ),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final scale = 0.85 + 0.3 * _controller.value;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.5),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Fills the empty space below the fold with something a first-time
/// visitor can actually act on, instead of the page reading as "content
/// only in the top half". All three route to signup — an anonymous visitor
/// can't actually file a report or check status yet, so this previews the
/// capability and funnels toward account creation rather than linking into
/// a protected route the router would just bounce them out of.
class _QuickActionsRow extends StatelessWidget {
  final bool wide;
  const _QuickActionsRow({required this.wide});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _QuickActionCard(
        number: '01',
        icon: Icons.medical_information_outlined,
        pill: 'SECURE REPORTING',
        title: 'Report a Case',
        subtitle:
            'Suspected dengue symptoms or case? Submit a secure report for verification.',
        onTap: () => context.go('/signup'),
      ),
      _QuickActionCard(
        number: '02',
        icon: Icons.pest_control_outlined,
        pill: 'LOCATION-BASED',
        title: 'Report a Breeding Site',
        subtitle:
            'Identify stagnant water or mosquito-prone areas that need attention.',
        onTap: () => context.go('/signup'),
      ),
      _QuickActionCard(
        number: '03',
        icon: Icons.fact_check_outlined,
        pill: 'REAL-TIME STATUS',
        title: 'Track Progress',
        subtitle:
            'Follow your report from submission to verification and response.',
        onTap: () => context.go('/signup'),
      ),
    ];
    if (wide) {
      return Row(
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 14),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }
    return Column(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          cards[i],
        ],
      ],
    );
  }
}

class _QuickActionCard extends StatefulWidget {
  final String number;
  final IconData icon;
  final String pill;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.number,
    required this.icon,
    required this.pill,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: Material(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            transform: Matrix4.translationValues(0, _hovering ? -3 : 0, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: _hovering ? AppColors.primary : AppColors.border,
              ),
              boxShadow: _hovering
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        widget.icon,
                        size: 19,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      widget.number,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.subtitle,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        widget.pill,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    AnimatedOpacity(
                      opacity: _hovering ? 1 : 0,
                      duration: const Duration(milliseconds: 160),
                      child: const Icon(Icons.arrow_forward, size: 15),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CapabilityStrip extends StatelessWidget {
  final bool wide;
  const _CapabilityStrip({required this.wide});

  static const _items = [
    (
      icon: Icons.fact_check_outlined,
      label: 'VERIFIED REPORTS',
      body: 'Reports reviewed by authorized personnel',
    ),
    (
      icon: Icons.location_on_outlined,
      label: 'COMMUNITY HOTSPOTS',
      body: 'Location-based monitoring',
    ),
    (
      icon: Icons.autorenew,
      label: 'REAL-TIME UPDATES',
      body: 'Track report progress',
    ),
    (
      icon: Icons.verified_user_outlined,
      label: 'PROTECTED DATA',
      body: 'Role-based access control',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: wide
          ? Row(
              children: [
                for (int i = 0; i < _items.length; i++) ...[
                  if (i > 0) const SizedBox(width: 16),
                  Expanded(child: _TrustStatusItem(item: _items[i])),
                ],
              ],
            )
          : Column(
              children: [
                for (int i = 0; i < _items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 14),
                  _TrustStatusItem(item: _items[i]),
                ],
              ],
            ),
    );
  }
}

class _TrustStatusItem extends StatelessWidget {
  final ({IconData icon, String label, String body}) item;
  const _TrustStatusItem({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(item.icon, size: 16, color: AppColors.textPrimary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.body,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The 5-stage flow, not 3 — the original 3-step version undersold how
/// many roles actually touch a single report. Kept the short-title-card
/// format instead of the fuller "Resident reports a concern"-style
/// sentence titles from the brief, since those don't fit this card size
/// without wrapping awkwardly; the body text carries that detail instead.
class _HowItWorksSection extends StatelessWidget {
  final bool wide;
  const _HowItWorksSection({super.key, required this.wide});

  static const _steps = [
    (
      number: '01',
      title: 'Report',
      body: 'Submit a case or breeding-site concern with location and details.',
    ),
    (
      number: '02',
      title: 'Verify',
      body: 'Authorized health workers review and validate the report.',
    ),
    (
      number: '03',
      title: 'Coordinate',
      body: 'The appropriate personnel are notified to respond.',
    ),
    (
      number: '04',
      title: 'Track',
      body: 'Your report progresses through clear, traceable status stages.',
    ),
    (
      number: '05',
      title: 'Improve',
      body: 'Verified reports help reveal patterns for better hotspot monitoring.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How it works',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          'From a resident noticing something, to community-wide awareness.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
        ),
        const SizedBox(height: 22),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < _steps.length; i++) ...[
                if (i > 0) const SizedBox(width: 14),
                Expanded(child: _StepCard(step: _steps[i])),
              ],
            ],
          )
        else
          Column(
            children: [
              for (int i = 0; i < _steps.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _StepCard(step: _steps[i]),
              ],
            ],
          ),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  final ({String number, String title, String body}) step;
  const _StepCard({required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step.number,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            step.title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            step.body,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// The system's actual role chain, split into its 4 real roles (was 3,
/// with Admin/Waste combined) — kept out of the hero (that's not where a
/// first-time visitor needs an org chart) but included further down for
/// anyone evaluating the system's design, not just a resident deciding
/// whether to sign up. Describes coordination only, never permissions or
/// account mechanics — this isn't the place to explain RLS or how staff
/// accounts get provisioned.
class _RoleWorkflowSection extends StatelessWidget {
  final bool wide;
  const _RoleWorkflowSection({required this.wide});

  static const _roles = [
    (
      icon: Icons.home_outlined,
      title: 'Residents',
      body: 'Report concerns and track progress.',
    ),
    (
      icon: Icons.health_and_safety_outlined,
      title: 'Health Workers',
      body: 'Review and verify submitted reports.',
    ),
    (
      icon: Icons.recycling_outlined,
      title: 'Waste Personnel',
      body: 'Respond to environmental and breeding-site concerns.',
    ),
    (
      icon: Icons.shield_outlined,
      title: 'Administrators',
      body: 'Monitor activity and coordinate the system.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'One system. Coordinated response.',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          'Each account only sees what its role needs — enforced at the database level.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
        ),
        const SizedBox(height: 22),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < _roles.length; i++) ...[
                if (i > 0) const SizedBox(width: 14),
                Expanded(child: _RoleCard(role: _roles[i])),
              ],
            ],
          )
        else
          Column(
            children: [
              for (int i = 0; i < _roles.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _RoleCard(role: _roles[i]),
              ],
            ],
          ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  final ({IconData icon, String title, String body}) role;
  const _RoleCard({required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              shape: BoxShape.circle,
            ),
            child: Icon(role.icon, size: 18, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          Text(
            role.title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            role.body,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinalCta extends StatelessWidget {
  final bool wide;
  const _FinalCta({required this.wide});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: wide ? 40 : 22,
        vertical: wide ? 44 : 32,
      ),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        children: [
          Text(
            'Your report could help protect your community.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.onPrimary,
              fontSize: wide ? 28 : 21,
              fontWeight: FontWeight.w700,
              height: 1.15,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Text(
              'Submit a concern securely and let authorized personnel take the next step.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.onPrimary.withValues(alpha: 0.7),
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.onPrimary,
                  foregroundColor: AppColors.ink,
                ),
                onPressed: () => context.go('/signup'),
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('Report a concern'),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.onPrimary,
                  side: BorderSide(
                    color: AppColors.onPrimary.withValues(alpha: 0.4),
                  ),
                ),
                onPressed: () => context.go('/login'),
                child: const Text('Sign in to track a report'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrustStatusBar extends StatelessWidget {
  final bool wide;
  const _TrustStatusBar({required this.wide});

  @override
  Widget build(BuildContext context) {
    final trust = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.lock_outline, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 8),
        const Flexible(
          child: Text(
            'Your reports are protected and only accessible to authorized personnel.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
    const status = _SystemStatusIndicator();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: wide
          ? Row(
              children: [
                Expanded(child: trust),
                const SizedBox(width: 16),
                status,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [trust, const SizedBox(height: 10), status],
            ),
    );
  }
}

enum _SystemStatus { checking, online, offline }

/// A REAL connectivity signal, not a decorative "always online" badge — it
/// pings Supabase on mount and only shows "online" once it gets an actual
/// response. Any server response counts (even a permission error), since
/// that alone proves the backend is reachable; only a network-level
/// failure (timeout, no connection) is reported as offline.
class _SystemStatusIndicator extends StatefulWidget {
  const _SystemStatusIndicator();

  @override
  State<_SystemStatusIndicator> createState() =>
      _SystemStatusIndicatorState();
}

class _SystemStatusIndicatorState extends State<_SystemStatusIndicator> {
  _SystemStatus _status = _SystemStatus.checking;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    if (!authService.hasSupabase) {
      if (mounted) setState(() => _status = _SystemStatus.offline);
      return;
    }
    try {
      await Supabase.instance.client
          .from('health_advisories')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 6));
      if (mounted) setState(() => _status = _SystemStatus.online);
    } on PostgrestException {
      // A response — even a rejected one — still means the backend is up.
      if (mounted) setState(() => _status = _SystemStatus.online);
    } catch (_) {
      if (mounted) setState(() => _status = _SystemStatus.offline);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (_status) {
      _SystemStatus.checking => (AppColors.textMuted, 'Checking status…'),
      _SystemStatus.online => (AppColors.success, 'All systems operational'),
      _SystemStatus.offline => (AppColors.danger, 'Connection unavailable'),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _LandingFooter extends StatelessWidget {
  const _LandingFooter();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Text(
          'BantayDengue',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        Spacer(),
        Text(
          'Community Health · SDG 3',
          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
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
