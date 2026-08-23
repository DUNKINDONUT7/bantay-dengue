import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../utils/ui_helpers.dart';
import '../widgets/analytics_widgets.dart';
import '../widgets/dengue_stats_card.dart';
import '../widgets/section_header.dart';
import '../widgets/shared_widgets.dart';

class HealthWorkerDashboard extends StatefulWidget {
  const HealthWorkerDashboard({super.key});

  @override
  State<HealthWorkerDashboard> createState() => _HealthWorkerDashboardState();
}

class _HealthWorkerDashboardState extends State<HealthWorkerDashboard> {
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _appointments = [];
  List<Map<String, dynamic>> _hotspots = [];
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait([
        // Both report types need review — dengue_case and breeding_site.
        DatabaseService.instance.fetchReports(),
        DatabaseService.instance.fetchAppointments(),
        DatabaseService.instance.fetchHotspots(),
      ]);
      _reports = values[0];
      _appointments = values[1];
      _hotspots = values[2];
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static const _monthAbbrev = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Buckets already-fetched verified/resolved reports into [weeks] weekly
  /// counts, oldest first — a display gap fix (WeeklyTrendChart), not a new
  /// data source. No new query: `_reports` is already loaded for the status
  /// donut above.
  ({List<int> counts, List<String> labels}) _weeklyVerifiedTrend(
    List<Map<String, dynamic>> reports, {
    int weeks = 8,
  }) {
    final today = DateTime.now();
    final startOfThisWeek = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: today.weekday - 1));
    final weekStarts = [
      for (var i = weeks - 1; i >= 0; i--)
        startOfThisWeek.subtract(Duration(days: i * 7)),
    ];
    final counts = List<int>.filled(weeks, 0);
    for (final report in reports) {
      if (!['verified', 'resolved'].contains(report['status'])) continue;
      final created = DateTime.tryParse('${report['created_at']}');
      if (created == null) continue;
      for (var i = 0; i < weekStarts.length; i++) {
        final start = weekStarts[i];
        final end = start.add(const Duration(days: 7));
        if (!created.isBefore(start) && created.isBefore(end)) {
          counts[i]++;
          break;
        }
      }
    }
    final labels = [
      for (final start in weekStarts)
        '${_monthAbbrev[start.month - 1]} ${start.day}',
    ];
    return (counts: counts, labels: labels);
  }

  @override
  Widget build(BuildContext context) {
    final pending = _reports
        .where((item) => ['pending', 'under_review'].contains(item['status']))
        .length;
    final appointments = _appointments
        .where((item) => ['pending', 'approved'].contains(item['status']))
        .length;
    final high = _hotspots.where((item) => item['risk_level'] == 'high').length;

    final statusCounts = <String, int>{};
    for (final report in _reports) {
      final status = '${report['status'] ?? 'pending'}';
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }
    final weeklyTrend = _weeklyVerifiedTrend(_reports);
    final topHotspots = _hotspots
        .take(5)
        .map(
          (h) => (
            label: '${h['barangay'] ?? 'Unmapped area'}',
            value: (h['case_count'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              SectionHeader(
                title: 'Health Center dashboard',
                subtitle:
                    'Welcome, ${authService.currentUser?.fullName ?? 'health worker'}. Operational data below is loaded from Supabase.',
                action: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
              ),
              if (_loading) const LinearProgressIndicator(),
              if (_error != null)
                Card(
                  margin: const EdgeInsets.all(16),
                  child: ListTile(
                    leading: const Icon(Icons.cloud_off),
                    title: Text(errorMessage(_error!)),
                    trailing: TextButton(
                      onPressed: _load,
                      child: const Text('Retry'),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final count = constraints.maxWidth >= 800
                        ? 3
                        : (constraints.maxWidth >= 480 ? 2 : 1);
                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: count,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: count == 1 ? 2.6 : 1.3,
                      children: [
                        StatCard(
                          value: '$pending',
                          label: 'Reports to review',
                          icon: Icons.fact_check_outlined,
                          color: AppColors.warning,
                          onTap: () => context.go('/doctor/verification'),
                        ),
                        StatCard(
                          value: '$appointments',
                          label: 'Active appointments',
                          icon: Icons.event_outlined,
                          color: AppColors.info,
                          onTap: () => context.go('/doctor/appointments'),
                        ),
                        StatCard(
                          value: '$high',
                          label: 'High-risk areas',
                          icon: Icons.location_on_outlined,
                          color: AppColors.danger,
                          onTap: () => context.go('/doctor/hotspots'),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SectionHeader(title: 'Verification & hotspots'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final statusPanel = AnalyticsPanel(
                      title: 'Reports by status',
                      child: StatusDonut(
                        counts: statusCounts,
                        colors: const {
                          'verified': AppColors.success,
                          'resolved': AppColors.success,
                          'pending': AppColors.warning,
                          'under_review': AppColors.warning,
                          'rejected': AppColors.danger,
                        },
                      ),
                    );
                    final hotspotsPanel = AnalyticsPanel(
                      title: 'Hotspots by barangay',
                      subtitle: 'verified case count',
                      child: RankedList(
                        items: topHotspots,
                        barColor: AppColors.danger,
                      ),
                    );
                    if (constraints.maxWidth >= 720) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: statusPanel),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: hotspotsPanel),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        statusPanel,
                        const SizedBox(height: 12),
                        hotspotsPanel,
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AnalyticsPanel(
                  title: 'Verified cases — last 8 weeks',
                  subtitle: 'local, not WHO figures',
                  child: WeeklyTrendChart(
                    counts: weeklyTrend.counts,
                    labels: weeklyTrend.labels,
                  ),
                ),
              ),
              const SectionHeader(
                title: 'Philippines dengue surveillance',
                subtitle:
                    'Official WHO xMart records; national figures are not local case counts.',
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: DengueStatsCard(),
              ),
              const SectionHeader(title: 'Recent reports'),
              if (!_loading && _reports.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No reports are currently available.',
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ..._reports
                    .take(5)
                    .map(
                      (item) => Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.report_outlined),
                          title: Text(humanize(item['report_type'] as String?)),
                          subtitle: Text(
                            '${item['location_text'] ?? ''} · ${formatDateTime(item['created_at'])}',
                          ),
                          trailing: StatusChip('${item['status']}'),
                          onTap: () => context.go('/doctor/verification'),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
