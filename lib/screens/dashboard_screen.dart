import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/weather_service.dart';
import '../utils/ui_helpers.dart';
import '../widgets/dengue_stats_card.dart';
import '../widgets/section_header.dart';
import '../widgets/shared_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _appointments = [];
  List<Map<String, dynamic>> _waste = [];
  List<Map<String, dynamic>> _advisories = [];
  WeatherRisk? _weather;
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
      final values = await Future.wait<dynamic>([
        DatabaseService.instance.fetchReports(ownOnly: true),
        DatabaseService.instance.fetchAppointments(ownOnly: true),
        DatabaseService.instance.fetchWasteRequests(ownOnly: true),
        DatabaseService.instance.fetchAdvisories(),
        WeatherService.instance.fetchRisk(
          latitude: 14.7575,
          longitude: 120.9480,
        ),
      ]);
      _reports = values[0] as List<Map<String, dynamic>>;
      _appointments = values[1] as List<Map<String, dynamic>>;
      _waste = values[2] as List<Map<String, dynamic>>;
      _advisories = values[3] as List<Map<String, dynamic>>;
      _weather = values[4] as WeatherRisk;
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name =
        authService.currentUser?.fullName.split(' ').first ?? 'Resident';
    final openReports = _reports
        .where((item) => !['resolved', 'rejected'].contains(item['status']))
        .length;
    final upcoming = _appointments
        .where((item) => ['pending', 'approved'].contains(item['status']))
        .length;
    final waste = _waste
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
                title: 'Good day, $name',
                subtitle: 'Your authenticated community dengue dashboard.',
                action: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const DemoAccessButton(),
                    IconButton(
                      onPressed: () => context.go('/civilian/notifications'),
                      icon: const Icon(Icons.notifications_outlined),
                      tooltip: 'Notifications',
                    ),
                  ],
                ),
              ),
              if (_loading) const LinearProgressIndicator(),
              if (_error != null)
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListTile(
                    leading: const Icon(Icons.cloud_off),
                    title: Text(errorMessage(_error!)),
                    subtitle: const Text(
                      'Your dashboard never substitutes made-up values when the server is unavailable.',
                    ),
                    trailing: TextButton(
                      onPressed: _load,
                      child: const Text('Retry'),
                    ),
                  ),
                ),
              if (_advisories.isNotEmpty)
                Card(
                  margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.campaign_outlined),
                    ),
                    title: Text('${_advisories.first['title']}'),
                    subtitle: Text(
                      '${_advisories.first['body']}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/civilian/advisories'),
                  ),
                ),
              if (_weather != null)
                Card(
                  margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.water_drop_outlined),
                    ),
                    title: Text(
                      'Weather breeding conditions: ${_weather!.label}',
                    ),
                    subtitle: Text(_weather!.summary),
                  ),
                ),
              const SectionHeader(
                title: 'My activity',
                subtitle: 'Live records from your Supabase account.',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final count = constraints.maxWidth >= 780 ? 3 : 1;
                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: count,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: count == 1 ? 3.5 : 1.65,
                      children: [
                        _Metric(
                          title: 'Open reports',
                          value: openReports,
                          icon: Icons.fact_check_outlined,
                          onTap: () => context.go('/civilian/report/history'),
                        ),
                        _Metric(
                          title: 'Appointments',
                          value: upcoming,
                          icon: Icons.event_outlined,
                          onTap: () => context.go('/civilian/appointments'),
                        ),
                        _Metric(
                          title: 'Waste requests',
                          value: waste,
                          icon: Icons.delete_sweep_outlined,
                          onTap: () => context.go('/civilian/waste'),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SectionHeader(title: 'Quick actions'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => context.go('/civilian/report/case'),
                      icon: const Icon(Icons.medical_information_outlined),
                      label: const Text('Report case'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => context.go('/civilian/report/breeding'),
                      icon: const Icon(Icons.pest_control_outlined),
                      label: const Text('Breeding site'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => context.go('/civilian/map'),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Hotspot map'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => context.go('/civilian/assistant'),
                      icon: const Icon(Icons.smart_toy_outlined),
                      label: const Text('Health guidance'),
                    ),
                  ],
                ),
              ),
              const SectionHeader(
                title: 'Philippines dengue surveillance',
                subtitle:
                    'Official WHO xMart data. National surveillance figures are not Marilao barangay case counts.',
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: DengueStatsCard(),
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
