import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../utils/ui_helpers.dart';
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

  @override
  Widget build(BuildContext context) {
    final pending = _reports
        .where((item) => ['pending', 'under_review'].contains(item['status']))
        .length;
    final appointments = _appointments
        .where((item) => ['pending', 'approved'].contains(item['status']))
        .length;
    final high = _hotspots.where((item) => item['risk_level'] == 'high').length;
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
                    const DemoAccessButton(),
                    IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
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
                    final count = constraints.maxWidth >= 800 ? 3 : 1;
                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: count,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: count == 1 ? 3.4 : 1.7,
                      children: [
                        _Metric(
                          title: 'Reports to review',
                          value: pending,
                          icon: Icons.fact_check_outlined,
                          onTap: () => context.go('/doctor/verification'),
                        ),
                        _Metric(
                          title: 'Active appointments',
                          value: appointments,
                          icon: Icons.event_outlined,
                          onTap: () => context.go('/doctor/appointments'),
                        ),
                        _Metric(
                          title: 'High-risk areas',
                          value: high,
                          icon: Icons.location_on_outlined,
                          onTap: () => context.go('/doctor/hotspots'),
                        ),
                      ],
                    );
                  },
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

class _Metric extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final VoidCallback onTap;
  const _Metric({
    required this.title,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(child: Icon(icon)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$value',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(title),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    ),
  );
}
