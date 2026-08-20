// lib/widgets/dengue_stats_card.dart
// Displays official WHO dengue data for a country the user can pick from a
// filter row. Pulls from two independent WHO endpoints:
//   1. Weekly surveillance counts (ARBOV) — cases, severe cases, deaths.
//   2. Long-term mortality trend (Global Health Estimates) — annual death
//      rate per 100,000 population.
// Both refresh together when the country filter changes, and each has its
// own refresh button and error/retry handling.

import 'package:flutter/material.dart';

import '../models/dengue_stat_model.dart';
import '../services/dengue_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_panel.dart';

class _CountryOption {
  final String iso3;
  final String label;
  const _CountryOption(this.iso3, this.label);
}

const _countryOptions = [
  _CountryOption('PHL', 'Philippines'),
  _CountryOption('IDN', 'Indonesia'),
  _CountryOption('VNM', 'Vietnam'),
  _CountryOption('THA', 'Thailand'),
  _CountryOption('BRA', 'Brazil'),
  _CountryOption('IND', 'India'),
];

class DengueStatsCard extends StatefulWidget {
  final String iso3;

  const DengueStatsCard({super.key, this.iso3 = 'PHL'});

  @override
  State<DengueStatsCard> createState() => _DengueStatsCardState();
}

class _DengueStatsCardState extends State<DengueStatsCard> {
  late String _selectedIso3;
  late Future<List<DengueStat>> _statsFuture;
  late Future<List<DengueMortalityPoint>> _mortalityFuture;

  @override
  void initState() {
    super.initState();
    _selectedIso3 = widget.iso3;
    _statsFuture = _loadStats();
    _mortalityFuture = _loadMortality();
  }

  Future<List<DengueStat>> _loadStats() {
    return DengueApiService.fetchRecentStats(iso3: _selectedIso3, weeks: 12);
  }

  Future<List<DengueMortalityPoint>> _loadMortality() {
    return DengueApiService.fetchMortalityTrend(iso3: _selectedIso3, years: 6);
  }

  void _onCountryChanged(String iso3) {
    if (iso3 == _selectedIso3) return;
    setState(() {
      _selectedIso3 = iso3;
      _statsFuture = _loadStats();
      _mortalityFuture = _loadMortality();
    });
  }

  void _refreshStats() => setState(() => _statsFuture = _loadStats());
  void _refreshMortality() =>
      setState(() => _mortalityFuture = _loadMortality());

  String get _countryLabel =>
      _countryOptions.firstWhere((c) => c.iso3 == _selectedIso3).label;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.public, size: 14, color: AppColors.textSecondary),
              SizedBox(width: 4),
              Text(
                'WHO Dengue Watch',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // ── Country filter (search/filter feature) ──────────────────
          SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _countryOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final option = _countryOptions[i];
                final isSelected = option.iso3 == _selectedIso3;
                return GestureDetector(
                  onTap: () => _onCountryChanged(option.iso3),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.ink
                          : AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: isSelected ? AppColors.ink : AppColors.border,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        option.label,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.onPrimary
                              : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          // ── Endpoint 1: weekly surveillance ──────────────────────────
          _WeeklyStatsSection(
            key: ValueKey('stats-$_selectedIso3'),
            future: _statsFuture,
            countryLabel: _countryLabel,
            onRefresh: _refreshStats,
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 16),
          // ── Endpoint 2: long-term mortality trend ────────────────────
          _MortalityTrendSection(
            key: ValueKey('mortality-$_selectedIso3'),
            future: _mortalityFuture,
            countryLabel: _countryLabel,
            onRefresh: _refreshMortality,
          ),
        ],
      ),
    );
  }
}

// ─── Endpoint 1 section: weekly surveillance (ARBOV) ───────────────────

class _WeeklyStatsSection extends StatelessWidget {
  final Future<List<DengueStat>> future;
  final String countryLabel;
  final VoidCallback onRefresh;

  const _WeeklyStatsSection({
    super.key,
    required this.future,
    required this.countryLabel,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DengueStat>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 90,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return _ErrorBlock(
            icon: Icons.cloud_off,
            message: snapshot.error is DengueApiException
                ? (snapshot.error as DengueApiException).message
                : 'Unable to reach the WHO data service.',
            onRetry: onRefresh,
            retryLabel: 'Retry',
          );
        }

        if (snapshot.data?.isEmpty ?? true) {
          // Not every WHO member state has weekly ARBOV surveillance
          // published — confirmed by querying the live endpoint directly:
          // this table simply has zero Philippines rows, while the annual
          // mortality endpoint below does have real PHL data. Retrying
          // won't change that, so say so plainly instead of implying a
          // fixable error, and point at the section that does have data.
          return _ErrorBlock(
            icon: Icons.info_outline,
            message:
                'WHO hasn\'t published weekly surveillance figures for '
                '$countryLabel in this dataset. The long-term annual trend '
                'below still reflects real WHO data for this country.',
            onRetry: onRefresh,
            retryLabel: 'Check again',
          );
        }

        final stats = snapshot.data!;
        final latest = stats.first;
        final previous = stats.length > 1 ? stats[1] : null;
        final trendUp =
            (previous != null && (latest.cases ?? 0) > (previous.cases ?? 0));
        final trendDown =
            (previous != null && (latest.cases ?? 0) < (previous.cases ?? 0));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'This Week — $countryLabel',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(
                    Icons.refresh,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: 'Refresh weekly data',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${latest.cases ?? 0}',
                            style: AppTypography.heading(context),
                          ),
                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Icon(
                              trendUp
                                  ? Icons.trending_up
                                  : (trendDown
                                        ? Icons.trending_down
                                        : Icons.trending_flat),
                              size: 16,
                              color: trendUp
                                  ? AppColors.riskHigh
                                  : (trendDown
                                        ? AppColors.success
                                        : AppColors.textMuted),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Reported cases — epi-week of '
                        '${latest.startDate.month}/${latest.startDate.day}/${latest.startDate.year}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatChip(
                  label: 'Severe',
                  value: '${latest.severeCases ?? 0}',
                  color: AppColors.warning,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  label: 'Deaths',
                  value: '${latest.deaths ?? 0}',
                  color: AppColors.riskHigh,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 36,
              child: _MiniTrendBars(
                values: stats.reversed
                    .map((s) => (s.cases ?? 0).toDouble())
                    .toList(),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Source: WHO Global Dengue Surveillance — ARBOV/V_DENGUE_GLOBAL_VALIDATED_PUBLIC (weekly)',
              style: TextStyle(color: AppColors.textMuted, fontSize: 10),
            ),
          ],
        );
      },
    );
  }
}

// ─── Endpoint 2 section: long-term mortality (GHE) ─────────────────────

class _MortalityTrendSection extends StatelessWidget {
  final Future<List<DengueMortalityPoint>> future;
  final String countryLabel;
  final VoidCallback onRefresh;

  const _MortalityTrendSection({
    super.key,
    required this.future,
    required this.countryLabel,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DengueMortalityPoint>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 80,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return _ErrorBlock(
            icon: Icons.cloud_off,
            message: snapshot.error is DengueApiException
                ? (snapshot.error as DengueApiException).message
                : 'Unable to reach the WHO data service.',
            onRetry: onRefresh,
          );
        }

        if (snapshot.data?.isEmpty ?? true) {
          return _ErrorBlock(
            icon: Icons.info_outline,
            message:
                'WHO hasn\'t published an annual mortality estimate for '
                '$countryLabel yet.',
            onRetry: onRefresh,
            retryLabel: 'Check again',
          );
        }

        final points = snapshot.data!;
        final latest = points.first;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Long-Term Mortality Trend',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(
                    Icons.refresh,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: 'Refresh mortality data',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  latest.deathRatePer100k.toStringAsFixed(2),
                  style: AppTypography.subheading(context),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    'deaths / 100k pop. (${latest.year})',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 30,
              child: _MiniTrendBars(
                values: points.reversed.map((p) => p.deathRatePer100k).toList(),
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Source: WHO Global Health Estimates — DEX_CMS/GHE_FULL_DD (annual)',
              style: TextStyle(color: AppColors.textMuted, fontSize: 10),
            ),
          ],
        );
      },
    );
  }
}

// ─── Shared bits ─────────────────────────────────────────────────────────

class _ErrorBlock extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final IconData icon;
  final String retryLabel;

  const _ErrorBlock({
    required this.message,
    required this.onRetry,
    this.icon = Icons.cloud_off,
    this.retryLabel = 'Retry',
  });

  @override
  Widget build(BuildContext context) {
    // No fixed height here on purpose: the old SizedBox(height: 80) forced a
    // box shorter than its own content once the app-wide 44px minimum
    // TextButton tap target is accounted for, which overflowed by ~15px on
    // every screen that renders this (both dashboards embed DengueStatsCard).
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textMuted, size: 20),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 2),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(retryLabel),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

/// Small sparkline-style bar row shared by both endpoint sections.
class _MiniTrendBars extends StatelessWidget {
  final List<double> values;
  final Color color;
  const _MiniTrendBars({required this.values, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<double>(1, (max, v) => v > max ? v : max);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: values.map((v) {
        final heightFraction = maxValue == 0 ? 0.0 : v / maxValue;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: FractionallySizedBox(
              heightFactor: heightFraction.clamp(0.05, 1.0),
              alignment: Alignment.bottomCenter,
              child: Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
