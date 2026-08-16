import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/database_service.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/section_header.dart';

class ReportHubScreen extends StatefulWidget {
  const ReportHubScreen({super.key});

  @override
  State<ReportHubScreen> createState() => _ReportHubScreenState();
}

class _ReportHubScreenState extends State<ReportHubScreen> {
  List<Map<String, dynamic>> _recent = [];
  bool _loading = true;
  Object? _error;

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
      _recent = (await DatabaseService.instance.fetchReports(
        ownOnly: true,
      )).take(3).toList();
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 700;
    final actions = [
      _ActionCard(
        title: 'Suspected dengue case',
        message: 'Share symptoms and location for health-center assessment.',
        icon: Icons.medical_information_outlined,
        color: Theme.of(context).colorScheme.error,
        onTap: () => context.go('/civilian/report/case'),
      ),
      _ActionCard(
        title: 'Mosquito breeding site',
        message: 'Flag stagnant water or environmental concerns.',
        icon: Icons.pest_control_outlined,
        color: Colors.orange,
        onTap: () => context.go('/civilian/report/breeding'),
      ),
      _ActionCard(
        title: 'Report history',
        message: 'Track review, verification, rejection, and resolution.',
        icon: Icons.history_outlined,
        color: Theme.of(context).colorScheme.primary,
        onTap: () => context.go('/civilian/report/history'),
      ),
    ];
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const SectionHeader(
                title: 'Community reporting',
                subtitle:
                    'Authenticated reports are privately routed to authorized personnel for verification.',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: wide ? 3 : 1,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: wide ? 1.25 : 2.5,
                  children: actions,
                ),
              ),
              const SectionHeader(
                title: 'Recent reports',
                subtitle: 'Your three most recent submissions.',
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.cloud_off),
                      title: Text(errorMessage(_error!)),
                      trailing: IconButton(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                      ),
                    ),
                  ),
                )
              else if (_recent.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No reports yet. Choose a report type above to help your community.',
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ..._recent.map(
                  (item) => Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: ListTile(
                      leading: Icon(
                        item['report_type'] == 'dengue_case'
                            ? Icons.medical_information_outlined
                            : Icons.pest_control_outlined,
                      ),
                      title: Text(humanize(item['report_type'] as String?)),
                      subtitle: Text(
                        '${item['location_text'] ?? ''} · ${formatDateTime(item['created_at'])}',
                      ),
                      trailing: StatusChip('${item['status']}'),
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

class _ActionCard extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: .15),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
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
}
