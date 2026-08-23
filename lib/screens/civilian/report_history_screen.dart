import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/edit_report_screen.dart';
import '../../widgets/section_header.dart';

class ReportHistoryScreen extends StatefulWidget {
  const ReportHistoryScreen({super.key});

  @override
  State<ReportHistoryScreen> createState() => _ReportHistoryScreenState();
}

class _ReportHistoryScreenState extends State<ReportHistoryScreen> {
  List<Map<String, dynamic>> _reports = [];
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
      _reports = await DatabaseService.instance.fetchReports(ownOnly: true);
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _viewEvidence(Map<String, dynamic> report) async {
    final path = report['photo_url'] as String?;
    final signedUrl = await DatabaseService.instance.createEvidenceUrl(
      bucket: 'report-evidence',
      path: path,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your submitted evidence'),
        content: SizedBox(
          width: min(560, MediaQuery.sizeOf(context).width - 48),
          child: signedUrl == null
              ? Text(
                  path == null
                      ? 'No photo evidence was attached to this report.'
                      : 'The private preview could not be created. Try again shortly.',
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Image.network(
                    signedUrl,
                    height: 320,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const SizedBox(
                      height: 120,
                      child: Center(
                        child: Text('Evidence could not be displayed.'),
                      ),
                    ),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(Map<String, dynamic> report) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditReportScreen(report: report)),
    );
    if (changed == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this report?'),
        content: Text(
          'This withdraws your ${humanize(report['report_type'] as String?).toLowerCase()} '
          'report at "${report['location_text'] ?? 'the reported location'}". '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await DatabaseService.instance.deleteReport(report['id'] as String);
      if (!mounted) return;
      showMessage(context, 'Report deleted.');
      _load();
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: 'My reports',
              subtitle:
                  'Track health-center verification and resolution status. '
                  'Pending reports can still be edited or withdrawn.',
              onBack: () => context.go('/civilian/report'),
              action: IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ),
            Expanded(
              child: AsyncStateView(
                loading: _loading,
                error: _error,
                empty: _reports.isEmpty,
                emptyTitle: 'No reports yet',
                emptyMessage:
                    'Reports you submit will appear here with their verification status.',
                onRetry: _load,
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    itemCount: _reports.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final report = _reports[index];
                      final isPending = report['status'] == null ||
                          report['status'] == 'pending';
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ListTile(
                                isThreeLine: true,
                                leading: CircleAvatar(
                                  child: Icon(
                                    report['report_type'] == 'dengue_case'
                                        ? Icons.medical_information_outlined
                                        : Icons.pest_control_outlined,
                                  ),
                                ),
                                title: Text(
                                  humanize(report['report_type'] as String?),
                                ),
                                subtitle: Text(
                                  '${report['location_text'] ?? 'Location not specified'}\n${formatDateTime(report['created_at'])}',
                                ),
                                trailing: StatusChip(
                                  '${report['status'] ?? 'pending'}',
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  0,
                                  12,
                                  8,
                                ),
                                child: Wrap(
                                  alignment: WrapAlignment.end,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _viewEvidence(report),
                                      icon: const Icon(
                                        Icons.visibility_outlined,
                                        size: 18,
                                      ),
                                      label: Text(
                                        report['photo_url'] == null
                                            ? 'No evidence'
                                            : 'View evidence',
                                      ),
                                    ),
                                    if (isPending) ...[
                                      TextButton.icon(
                                        onPressed: () => _edit(report),
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 18,
                                        ),
                                        label: const Text('Edit'),
                                      ),
                                      TextButton.icon(
                                        onPressed: () => _delete(report),
                                        icon: Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                        ),
                                        label: Text(
                                          'Delete',
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.error,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
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
