// lib/widgets/analytics_widgets.dart
//
// Reusable chart/breakdown widgets for the analytics-heavy dashboards
// (admin, health worker). Every widget here renders only real, already
// fetched data passed in by the caller — none of them fabricate trends or
// time-series the backend doesn't provide.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/ui_helpers.dart';

/// Donut breakdown of a status/category count map, e.g. reports by
/// verification status. Entries with a zero count are dropped.
class StatusDonut extends StatelessWidget {
  final Map<String, int> counts;
  final Map<String, Color> colors;
  final String centerLabel;

  const StatusDonut({
    super.key,
    required this.counts,
    required this.colors,
    this.centerLabel = 'Total',
  });

  @override
  Widget build(BuildContext context) {
    final entries = counts.entries.where((e) => e.value > 0).toList();
    final total = entries.fold<int>(0, (sum, e) => sum + e.value);

    if (total == 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text(
          'No data yet.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      );
    }

    return Row(
      children: [
        SizedBox(
          width: 108,
          height: 108,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sections: entries
                      .map(
                        (e) => PieChartSectionData(
                          value: e.value.toDouble(),
                          color: colors[e.key] ?? AppColors.textMuted,
                          radius: 15,
                          showTitle: false,
                        ),
                      )
                      .toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 38,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$total',
                    style: AppTypography.statNumber(context, size: 19),
                  ),
                  Text(
                    centerLabel,
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entries.map((e) {
              final pct = (e.value / total * 100).round();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colors[e.key] ?? AppColors.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        humanize(e.key),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      '$pct%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class ComparisonBarItem {
  final String label;
  final int value;
  final Color color;
  const ComparisonBarItem({
    required this.label,
    required this.value,
    required this.color,
  });
}

/// A small labelled bar comparison — e.g. dengue-case vs. breeding-site
/// report counts. Not a time series; each bar is one category's total.
class ComparisonBars extends StatelessWidget {
  final List<ComparisonBarItem> items;

  const ComparisonBars({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final maxVal = items
        .map((i) => i.value)
        .fold<int>(0, (m, v) => v > m ? v : m);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 120,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: (maxVal == 0 ? 1 : maxVal) * 1.3,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= items.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          items[i].label,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < items.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: items[i].value.toDouble(),
                        color: items[i].color,
                        width: 40,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 16,
          children: items
              .map(
                (i) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${i.label} · ${i.value}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

/// A ranked, bar-filled list — e.g. hotspots by verified case count. The
/// caller is expected to have already sorted [items] descending.
class RankedList extends StatelessWidget {
  final List<({String label, int value})> items;
  final Color barColor;
  final IconData icon;

  const RankedList({
    super.key,
    required this.items,
    this.barColor = AppColors.ink,
    this.icon = Icons.location_on_outlined,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text(
          'No data yet.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      );
    }
    final maxVal = items.map((i) => i.value).reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 13, color: AppColors.textMuted),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: Text(
                    item.label,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: maxVal == 0 ? 0 : item.value / maxVal,
                      minHeight: 5,
                      backgroundColor: AppColors.surfaceElevated,
                      valueColor: AlwaysStoppedAnimation(barColor),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 24,
                  child: Text(
                    '${item.value}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A bold, solid-ink metric card for a single standout number — used
/// sparingly, one per dashboard at most.
class HighlightMetricCard extends StatelessWidget {
  final String value;
  final String label;
  final String? sublabel;

  const HighlightMetricCard({
    super.key,
    required this.value,
    required this.label,
    this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.onPrimary.withValues(alpha: 0.72),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.onPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (sublabel != null) ...[
            const SizedBox(height: 2),
            Text(
              sublabel!,
              style: TextStyle(
                color: AppColors.onPrimary.withValues(alpha: 0.72),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shared card chrome for a chart/breakdown panel, matching [Card]'s theme
/// but with an explicit title/subtitle row above the content.
class AnalyticsPanel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const AnalyticsPanel({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Week-over-week line chart — e.g. verified case counts per week. The app
/// already shows a WHO *global* trend line (dengue_stats_card.dart); this is
/// the same idea for the app's own local data, which existed all along in
/// `reports`/`created_at` but had no chart, only point-in-time counts.
/// [counts] and [labels] must be the same length, oldest first — the caller
/// buckets real fetched rows into them, this widget never fabricates a trend.
class WeeklyTrendChart extends StatelessWidget {
  final List<int> counts;
  final List<String> labels;
  final Color color;

  const WeeklyTrendChart({
    super.key,
    required this.counts,
    required this.labels,
    this.color = AppColors.danger,
  });

  @override
  Widget build(BuildContext context) {
    if (counts.isEmpty || counts.every((c) => c == 0)) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text(
          'No verified cases in this window yet.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      );
    }
    final maxCount = counts.reduce((a, b) => a > b ? a : b);
    // Show at most ~6 labels regardless of window length so they don't
    // overlap — every Nth week rather than every single one.
    final labelStep = (labels.length / 6).ceil().clamp(1, labels.length);

    return SizedBox(
      height: 140,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: (maxCount == 0 ? 1 : maxCount) * 1.25,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.ink,
              getTooltipItems: (spots) => spots.map((s) {
                final index = s.x.toInt();
                final label = index >= 0 && index < labels.length
                    ? labels[index]
                    : '';
                return LineTooltipItem(
                  '${s.y.toInt()} · $label',
                  const TextStyle(color: Colors.white, fontSize: 11),
                );
              }).toList(),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 ||
                      index >= labels.length ||
                      index % labelStep != 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      labels[index],
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.textMuted,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < counts.length; i++)
                  FlSpot(i.toDouble(), counts[i].toDouble()),
              ],
              isCurved: true,
              color: color,
              barWidth: 2.5,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Weather-derived mosquito breeding-condition indicator, with a 7-day
/// rainfall mini chart. Reused by the civilian dashboard and the hotspot
/// map screen — both already fetch a [WeatherRisk] from WeatherService.
class WeatherBreedingCard extends StatelessWidget {
  final String label;
  final String summary;
  final List<double> dailyRainMm;
  final double? temperatureC;

  const WeatherBreedingCard({
    super.key,
    required this.label,
    required this.summary,
    this.dailyRainMm = const [],
    this.temperatureC,
  });

  Color get _color {
    switch (label) {
      case 'high':
        return AppColors.danger;
      case 'moderate':
        return AppColors.warning;
      case 'low':
        return AppColors.success;
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unavailable = label == 'Unavailable';
    final maxRain = dailyRainMm.isEmpty
        ? 1.0
        : dailyRainMm.reduce((a, b) => a > b ? a : b).clamp(1.0, double.infinity);

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
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.water_drop_outlined, color: _color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Breeding-condition indicator',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      unavailable ? 'Unavailable' : humanize(label),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (!unavailable && temperatureC != null) ...[
                Text(
                  '${temperatureC!.round()}°C',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (!unavailable)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            summary,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          if (!unavailable && dailyRainMm.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 44,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final mm in dailyRainMm)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: FractionallySizedBox(
                          heightFactor: (mm / maxRain).clamp(0.04, 1.0),
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            decoration: BoxDecoration(
                              color: _color.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '7-day rainfall forecast',
              style: TextStyle(fontSize: 9.5, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
