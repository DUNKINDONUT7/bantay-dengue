import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/weather_service.dart';
import '../theme/app_theme.dart';
import '../utils/ui_helpers.dart';
import '../widgets/analytics_widgets.dart';
import '../widgets/dengue_stats_card.dart';
import '../widgets/notifications_panel.dart';
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
                action: IconButton(
                  onPressed: () => openNotificationsPanel(context),
                  icon: const Icon(Icons.notifications_outlined),
                  tooltip: 'Notifications',
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: WeatherBreedingCard(
                    label: _weather!.label,
                    summary: _weather!.summary,
                    dailyRainMm: _weather!.dailyRainMm,
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
                    final count = constraints.maxWidth >= 780 ? 3 : 2;
                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: count,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: count == 3 ? 1.3 : 1.15,
                      children: [
                        StatCard(
                          value: '$openReports',
                          label: 'Open reports',
                          icon: Icons.fact_check_outlined,
                          color: AppColors.warning,
                          onTap: () => context.go('/civilian/report/history'),
                        ),
                        StatCard(
                          value: '$upcoming',
                          label: 'Appointments',
                          icon: Icons.event_outlined,
                          color: AppColors.info,
                          onTap: () => context.go('/civilian/appointments'),
                        ),
                        StatCard(
                          value: '$waste',
                          label: 'Waste requests',
                          icon: Icons.delete_sweep_outlined,
                          color: AppColors.success,
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
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FlyActionButton(
                      icon: Icons.medical_information_outlined,
                      label: 'Report case',
                      filled: true,
                      onTap: () => context.go('/civilian/report/case'),
                    ),
                    FlyActionButton(
                      icon: Icons.pest_control_outlined,
                      label: 'Breeding site',
                      onTap: () => context.go('/civilian/report/breeding'),
                    ),
                    FlyActionButton(
                      icon: Icons.map_outlined,
                      label: 'Hotspot map',
                      onTap: () => context.go('/civilian/map'),
                    ),
                    FlyActionButton(
                      icon: Icons.smart_toy_outlined,
                      label: 'Health guidance',
                      onTap: () => context.go('/civilian/assistant'),
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
