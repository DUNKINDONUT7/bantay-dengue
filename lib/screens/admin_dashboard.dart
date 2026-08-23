import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../utils/analytics_export.dart';
import '../utils/ui_helpers.dart';
import '../widgets/analytics_widgets.dart';
import '../widgets/section_header.dart';
import '../widgets/shared_widgets.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<Map<String, dynamic>> _profiles = [];
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _activity = [];
  List<Map<String, dynamic>> _waste = [];
  List<Map<String, dynamic>> _hotspots = [];
  List<Map<String, dynamic>> _appointments = [];
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
        DatabaseService.instance.fetchProfiles(),
        DatabaseService.instance.fetchReports(),
        DatabaseService.instance.fetchSystemActivity(),
        DatabaseService.instance.fetchWasteRequests(),
        DatabaseService.instance.fetchHotspots(),
        DatabaseService.instance.fetchAppointments(),
      ]);
      _profiles = values[0];
      _reports = values[1];
      _activity = values[2];
      _waste = values[3];
      _hotspots = values[4];
      _appointments = values[5];
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Renders the `details` jsonb payload already fetched on every
  /// system_activity row but never shown before. The status-change trigger
  /// (capture_status_change in BantayDengue_FINAL.sql) always writes
  /// old_status/new_status, so that's rendered specially; anything else
  /// (or a future trigger with a different shape) falls back to a compact
  /// key:value join instead of being silently dropped.
  String? _activityDetail(dynamic raw) {
    if (raw is! Map) return null;
    final details = Map<String, dynamic>.from(raw);
    if (details.isEmpty) return null;
    final oldStatus = details['old_status'];
    final newStatus = details['new_status'];
    if (oldStatus != null && newStatus != null) {
      return '${humanize('$oldStatus')} → ${humanize('$newStatus')}';
    }
    return details.entries.map((e) => '${e.key}: ${e.value}').join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final verified = _reports
        .where(
          (item) =>
              item['status'] == 'verified' || item['status'] == 'resolved',
        )
        .length;
    final pending = _reports
        .where((item) => item['status'] == 'pending')
        .length;
    final activeWaste = _waste
        .where((item) => ['pending', 'scheduled'].contains(item['status']))
        .length;

    final statusCounts = <String, int>{};
    for (final report in _reports) {
      final status = '${report['status'] ?? 'pending'}';
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }
    final caseCount = _reports
        .where((r) => r['report_type'] == 'dengue_case')
        .length;
    final breedingCount = _reports
        .where((r) => r['report_type'] == 'breeding_site')
        .length;

    final now = DateTime.now();
    final verifiedThisMonth = _reports.where((r) {
      if (r['status'] != 'verified' && r['status'] != 'resolved') return false;
      final created = DateTime.tryParse('${r['created_at']}');
      return created != null &&
          created.year == now.year &&
          created.month == now.month;
    }).length;

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
                title: 'Administration & analytics',
                subtitle:
                    'Live RLS-protected operational totals. Only verified reports should inform official local analysis.',
                action: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.ios_share),
                      tooltip: 'Export',
                      onSelected: (format) {
                        switch (format) {
                          case 'csv_reports':
                            exportReportsCsv(context, _reports);
                          case 'csv_users':
                            exportUsersCsv(context, _profiles);
                          case 'csv_waste':
                            exportWasteCsv(context, _waste);
                          case 'csv_appointments':
                            exportAppointmentsCsv(context, _appointments);
                          case 'pdf':
                            exportAnalyticsPdf(
                              context,
                              totalUsers: _profiles.length,
                              pendingReports: pending,
                              verifiedReports: verified,
                              activeWaste: activeWaste,
                              statusCounts: statusCounts,
                              topHotspots: topHotspots,
                            );
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'csv_reports',
                          child: ListTile(
                            leading: Icon(Icons.table_chart_outlined),
                            title: Text('Export reports (CSV)'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'csv_users',
                          child: ListTile(
                            leading: Icon(Icons.people_outline),
                            title: Text('Export users (CSV)'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'csv_waste',
                          child: ListTile(
                            leading: Icon(Icons.delete_sweep_outlined),
                            title: Text('Export waste requests (CSV)'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'csv_appointments',
                          child: ListTile(
                            leading: Icon(Icons.event_outlined),
                            title: Text('Export appointments (CSV)'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'pdf',
                          child: ListTile(
                            leading: Icon(Icons.picture_as_pdf_outlined),
                            title: Text('Export summary (PDF)'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
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
                    final count = constraints.maxWidth >= 900
                        ? 4
                        : constraints.maxWidth >= 540
                        ? 2
                        : 2;
                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: count,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: count == 4 ? 1.15 : 1.25,
                      children: [
                        StatCard(
                          value: '${_profiles.length}',
                          label: 'Users',
                          icon: Icons.people_outline,
                          color: AppColors.info,
                          onTap: () => context.go('/admin/users'),
                        ),
                        StatCard(
                          value: '$pending',
                          label: 'Pending reports',
                          icon: Icons.pending_actions,
                          color: AppColors.warning,
                          onTap: () => context.go('/admin/verification'),
                        ),
                        StatCard(
                          value: '$verified',
                          label: 'Verified reports',
                          icon: Icons.verified_outlined,
                          color: AppColors.success,
                          onTap: () => context.go('/admin/verification'),
                        ),
                        StatCard(
                          value: '$activeWaste',
                          label: 'Active waste requests',
                          icon: Icons.delete_sweep_outlined,
                          color: AppColors.primary,
                          onTap: () => context.go('/admin/waste'),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SectionHeader(
                title: 'Verification & reporting mix',
                subtitle: 'Breakdown of everything currently in the reports table.',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final panels = [
                      AnalyticsPanel(
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
                      ),
                      AnalyticsPanel(
                        title: 'Cases vs. breeding sites',
                        child: ComparisonBars(
                          items: [
                            ComparisonBarItem(
                              label: 'Dengue cases',
                              value: caseCount,
                              color: AppColors.ink,
                            ),
                            ComparisonBarItem(
                              label: 'Breeding sites',
                              value: breedingCount,
                              color: AppColors.warning,
                            ),
                          ],
                        ),
                      ),
                    ];
                    if (constraints.maxWidth >= 720) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: panels[0]),
                          const SizedBox(width: 12),
                          Expanded(child: panels[1]),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        panels[0],
                        const SizedBox(height: 12),
                        panels[1],
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final hotspotsPanel = AnalyticsPanel(
                      title: 'Hotspots by barangay',
                      subtitle: 'verified case count',
                      child: RankedList(items: topHotspots),
                    );
                    final highlight = HighlightMetricCard(
                      value: '$verifiedThisMonth reports',
                      label: 'Verified this month',
                      sublabel: '$verified verified in total',
                    );
                    if (constraints.maxWidth >= 720) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 2, child: hotspotsPanel),
                            const SizedBox(width: 12),
                            Expanded(child: highlight),
                          ],
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        children: [
                          hotspotsPanel,
                          const SizedBox(height: 12),
                          highlight,
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SectionHeader(title: 'Recent audited activity'),
              if (!_loading && _activity.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No audited workflow activity has been recorded yet.',
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ..._activity
                    .take(10)
                    .map((item) {
                      final detail = _activityDetail(item['details']);
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.history),
                          ),
                          title: Text(humanize(item['action'] as String?)),
                          subtitle: Text(
                            detail == null
                                ? formatDateTime(item['created_at'])
                                : '${formatDateTime(item['created_at'])}\n$detail',
                          ),
                          isThreeLine: detail != null,
                        ),
                      );
                    }),
            ],
          ),
        ),
      ),
    );
  }
}
