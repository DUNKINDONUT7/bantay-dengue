import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/location_helper.dart';
import '../services/weather_service.dart';
import '../theme/app_theme.dart';
import '../utils/ui_helpers.dart';
import '../widgets/analytics_widgets.dart';
import '../widgets/dengue_stats_card.dart';
import '../widgets/section_header.dart';
import '../widgets/shared_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

/// Matches WeatherBreedingCard's card language (same container, radius,
/// icon-circle pattern) on purpose — the two sit next to/on top of each
/// other as a pair, so they need to look like a matched set, not two
/// differently-styled widgets that happen to be near each other. The
/// previous version used `colorScheme.primaryContainer`, which this app's
/// custom ink/cream theme never defines a legible value for — it rendered
/// as a near-black filled card with barely-visible text and icon.
class _AdvisoryBanner extends StatelessWidget {
  final String title;
  final String body;
  final VoidCallback onTap;

  const _AdvisoryBanner({
    required this.title,
    required this.body,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.campaign_outlined,
                  color: AppColors.info,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Advisory',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
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

  // Marilao, Bulacan — same regional fallback used by hotspot_map_screen.dart
  // and report_form.dart when GPS isn't available or permission is denied.
  static const _fallbackLat = 14.7575;
  static const _fallbackLng = 120.9480;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Best-effort: the breeding-condition indicator should reflect where
      // the resident actually is, not a fixed point 30+ km away for anyone
      // outside Marilao — but a denied permission or disabled GPS must
      // never block the rest of the dashboard from loading.
      var lat = _fallbackLat;
      var lng = _fallbackLng;
      try {
        final location = await LocationHelper.getCurrentLocation(
          accuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 6),
        );
        lat = location.latitude;
        lng = location.longitude;
      } catch (_) {
        // Keep the fallback — this indicator degrading to a regional
        // estimate is fine, silently failing the whole dashboard isn't.
      }
      final values = await Future.wait<dynamic>([
        DatabaseService.instance.fetchReports(ownOnly: true),
        DatabaseService.instance.fetchAppointments(ownOnly: true),
        DatabaseService.instance.fetchWasteRequests(ownOnly: true),
        DatabaseService.instance.fetchAdvisories(),
        WeatherService.instance.fetchRisk(latitude: lat, longitude: lng),
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

  /// Count of already-fetched rows created in the last 7 days — no new
  /// query, `created_at` is already on every row. Used as a StatCard
  /// caption; that widget's own doc comment already scopes captions to
  /// "values derived from real fetched data," which this is.
  int _sinceLastWeek(List<Map<String, dynamic>> items) {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return items.where((item) {
      final createdAt = DateTime.tryParse('${item['created_at']}');
      return createdAt != null && createdAt.isAfter(cutoff);
    }).length;
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
    final newReports = _sinceLastWeek(_reports);
    final newAppointments = _sinceLastWeek(_appointments);
    final newWaste = _sinceLastWeek(_waste);
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
              if (_advisories.isNotEmpty || _weather != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final advisory = _advisories.isNotEmpty
                          ? _AdvisoryBanner(
                              title: '${_advisories.first['title']}',
                              body: '${_advisories.first['body']}',
                              onTap: () => context.go('/civilian/advisories'),
                            )
                          : null;
                      final weather = _weather != null
                          ? WeatherBreedingCard(
                              label: _weather!.label,
                              summary: _weather!.summary,
                              dailyRainMm: _weather!.dailyRainMm,
                              temperatureC: _weather!.temperatureC,
                            )
                          : null;
                      // Side-by-side once there's room for both to breathe;
                      // stacked (and touching, not floating apart) on
                      // narrow screens where a Row would cramp the text —
                      // either way the two read as one grouped "today"
                      // status pair, not two unrelated floating cards.
                      if (advisory != null &&
                          weather != null &&
                          constraints.maxWidth >= 700) {
                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: advisory),
                              const SizedBox(width: 10),
                              Expanded(child: weather),
                            ],
                          ),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (advisory != null) advisory,
                          if (advisory != null && weather != null)
                            const SizedBox(height: 10),
                          if (weather != null) weather,
                        ],
                      );
                    },
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
                          caption: newReports > 0
                              ? '+$newReports this week'
                              : null,
                        ),
                        StatCard(
                          value: '$upcoming',
                          label: 'Appointments',
                          icon: Icons.event_outlined,
                          color: AppColors.info,
                          onTap: () => context.go('/civilian/appointments'),
                          caption: newAppointments > 0
                              ? '+$newAppointments this week'
                              : null,
                        ),
                        StatCard(
                          value: '$waste',
                          label: 'Waste requests',
                          icon: Icons.delete_sweep_outlined,
                          color: AppColors.success,
                          onTap: () => context.go('/civilian/waste'),
                          caption: newWaste > 0
                              ? '+$newWaste this week'
                              : null,
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
