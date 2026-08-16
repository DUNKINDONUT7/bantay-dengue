import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/database_service.dart';
import '../utils/ui_helpers.dart';
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
      ]);
      _profiles = values[0];
      _reports = values[1];
      _activity = values[2];
      _waste = values[3];
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                    final count = constraints.maxWidth >= 900
                        ? 4
                        : constraints.maxWidth >= 540
                        ? 2
                        : 1;
                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: count,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: count == 1 ? 3.7 : 1.6,
                      children: [
                        _AdminMetric(
                          label: 'Users',
                          value: _profiles.length,
                          icon: Icons.people_outline,
                          onTap: () => context.go('/admin/users'),
                        ),
                        _AdminMetric(
                          label: 'Pending reports',
                          value: pending,
                          icon: Icons.pending_actions,
                          onTap: () => context.go('/admin/verification'),
                        ),
                        _AdminMetric(
                          label: 'Verified reports',
                          value: verified,
                          icon: Icons.verified_outlined,
                          onTap: () => context.go('/admin/verification'),
                        ),
                        _AdminMetric(
                          label: 'Active waste requests',
                          value: activeWaste,
                          icon: Icons.delete_sweep_outlined,
                          onTap: () => context.go('/admin/waste'),
                        ),
                      ],
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
                    .map(
                      (item) => Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.history),
                          ),
                          title: Text(humanize(item['action'] as String?)),
                          subtitle: Text(formatDateTime(item['created_at'])),
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

class _AdminMetric extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final VoidCallback onTap;
  const _AdminMetric({
    required this.label,
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
                  Text(label),
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
