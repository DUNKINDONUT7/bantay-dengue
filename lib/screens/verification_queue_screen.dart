import 'package:flutter/material.dart';

import '../services/database_service.dart';
import '../utils/ui_helpers.dart';
import '../widgets/section_header.dart';

class VerificationQueueScreen extends StatefulWidget {
  const VerificationQueueScreen({super.key});

  @override
  State<VerificationQueueScreen> createState() =>
      _VerificationQueueScreenState();
}

class _VerificationQueueScreenState extends State<VerificationQueueScreen> {
  List<Map<String, dynamic>> _reports = [];
  Object? _error;
  bool _loading = true;
  String _filter = 'pending';

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
      _reports = await DatabaseService.instance.fetchReports();
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _update(Map<String, dynamic> report, String status) async {
    try {
      await DatabaseService.instance.updateReportStatus(
        reportId: '${report['id']}',
        status: status,
      );
      if (mounted) {
        showMessage(
          context,
          'Report marked ${humanize(status).toLowerCase()}.',
        );
      }
      await _load();
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error), error: true);
    }
  }

  Future<void> _details(Map<String, dynamic> report) async {
    final signedUrl = await DatabaseService.instance.createEvidenceUrl(
      bucket: 'report-evidence',
      path: report['photo_url'] as String?,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        final reporter = report['profiles'] as Map<String, dynamic>?;
        return AlertDialog(
          title: Text(humanize(report['report_type'] as String?)),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Field('Reporter', '${reporter?['full_name'] ?? 'Resident'}'),
                  _Field(
                    'Location',
                    '${report['location_text'] ?? 'Not supplied'}',
                  ),
                  _Field('Submitted', formatDateTime(report['created_at'])),
                  _Field(
                    'Description',
                    '${report['description'] ?? 'No description'}',
                  ),
                  if (report['latitude'] != null)
                    _Field(
                      'Coordinates',
                      '${report['latitude']}, ${report['longitude']}',
                    ),
                  const SizedBox(height: 10),
                  if (signedUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        signedUrl,
                        height: 260,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(
                          height: 120,
                          child: Center(
                            child: Text(
                              'Private evidence could not be displayed.',
                            ),
                          ),
                        ),
                      ),
                    )
                  else if (report['photo_url'] != null)
                    const Text(
                      'Private evidence exists but a signed preview could not be created.',
                    )
                  else
                    const Text('No photo evidence was attached.'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == 'all'
        ? _reports
        : _filter == 'pending'
        ? _reports
              .where(
                (item) => ['pending', 'under_review'].contains(item['status']),
              )
              .toList()
        : _reports.where((item) => item['status'] == _filter).toList();
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: 'Report verification',
              subtitle:
                  'Review resident submissions before they influence official local hotspot records.',
              action: IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
            ),
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final value in const [
                    'pending',
                    'verified',
                    'rejected',
                    'resolved',
                    'all',
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        selected: _filter == value,
                        label: Text(humanize(value)),
                        onSelected: (_) => setState(() => _filter = value),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: AsyncStateView(
                loading: _loading,
                error: _error,
                empty: filtered.isEmpty,
                emptyTitle: 'No matching reports',
                emptyMessage: 'Incoming resident submissions will appear here.',
                onRetry: _load,
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final report = filtered[index];
                      final reporter =
                          report['profiles'] as Map<String, dynamic>?;
                      final status = '${report['status']}';
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    child: Icon(
                                      report['report_type'] == 'dengue_case'
                                          ? Icons.medical_information_outlined
                                          : Icons.pest_control_outlined,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          humanize(
                                            report['report_type'] as String?,
                                          ),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                        Text(
                                          '${reporter?['full_name'] ?? 'Resident'} · ${formatDateTime(report['created_at'])}',
                                        ),
                                      ],
                                    ),
                                  ),
                                  StatusChip(status),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${report['location_text'] ?? ''}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${report['description'] ?? ''}',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _details(report),
                                    icon: const Icon(Icons.visibility_outlined),
                                    label: const Text('Review details'),
                                  ),
                                  if (status == 'pending')
                                    OutlinedButton(
                                      onPressed: () =>
                                          _update(report, 'under_review'),
                                      child: const Text('Start review'),
                                    ),
                                  if (status == 'pending' ||
                                      status == 'under_review') ...[
                                    OutlinedButton(
                                      onPressed: () =>
                                          _update(report, 'rejected'),
                                      child: const Text('Reject'),
                                    ),
                                    FilledButton.icon(
                                      onPressed: () =>
                                          _update(report, 'verified'),
                                      icon: const Icon(Icons.verified),
                                      label: const Text('Verify'),
                                    ),
                                  ],
                                  if (status == 'verified')
                                    FilledButton.icon(
                                      onPressed: () =>
                                          _update(report, 'resolved'),
                                      icon: const Icon(Icons.task_alt),
                                      label: const Text('Mark resolved'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String value;
  const _Field(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 2),
        SelectableText(value),
      ],
    ),
  );
}
