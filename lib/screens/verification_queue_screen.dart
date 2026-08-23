import 'dart:math';

import 'package:flutter/material.dart';

import '../services/ai_service.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
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
      // Both report types need staff review — dengue_case and breeding_site
      // are equally part of the verification workflow.
      _reports = await DatabaseService.instance.fetchReports();
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Count of OTHER reports (any status, any type) already filed by the same
  /// resident, from the full report set already loaded for this screen — no
  /// new query. Gives a reviewer repeat-reporter context (a resident who's
  /// filed several reports this month reads differently than a first-timer)
  /// without exposing anything beyond a count.
  int _priorReportCount(Map<String, dynamic> report) {
    final reporterId = report['reporter_id'];
    if (reporterId == null) return 0;
    return _reports
        .where(
          (r) => r['reporter_id'] == reporterId && r['id'] != report['id'],
        )
        .length;
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

  void _openPhotoFullscreen(String url) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (routeContext, animation, __) => FadeTransition(
          opacity: animation,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4,
                      child: Image.network(url, fit: BoxFit.contain),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      onPressed: () => Navigator.of(routeContext).pop(),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 28,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _details(Map<String, dynamic> report) async {
    final signedUrl = await DatabaseService.instance.createEvidenceUrl(
      bucket: 'report-evidence',
      path: report['photo_url'] as String?,
    );
    if (!mounted) return;
    final reporter = report['profiles'] as Map<String, dynamic>?;
    final priorReports = _priorReportCount(report);
    final status = '${report['status']}';
    final isDengueCase = report['report_type'] == 'dengue_case';
    final accent = isDengueCase
        ? Theme.of(context).colorScheme.error
        : AppColors.warning;
    final latitude = report['latitude'] as num?;
    final longitude = report['longitude'] as num?;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: min(560, MediaQuery.sizeOf(dialogContext).width - 40),
            maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.lg),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        isDengueCase
                            ? Icons.medical_information_outlined
                            : Icons.pest_control_outlined,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            humanize(report['report_type'] as String?),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          StatusChip(status),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailRow(
                        icon: Icons.person_outline,
                        label: 'Reporter',
                        value: '${reporter?['full_name'] ?? 'Resident'}',
                        trailing: priorReports > 0
                            ? _PriorReportsBadge(count: priorReports)
                            : null,
                      ),
                      const SizedBox(height: 14),
                      _DetailRow(
                        icon: Icons.schedule_outlined,
                        label: 'Submitted',
                        value: formatDateTime(report['created_at']),
                      ),
                      const SizedBox(height: 14),
                      _DetailRow(
                        icon: Icons.location_on_outlined,
                        label: 'Location',
                        value: '${report['location_text'] ?? 'Not supplied'}'
                            '${latitude != null ? '\n${latitude.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}' : ''}',
                        trailing: latitude != null
                            ? TextButton.icon(
                                onPressed: () =>
                                    openLocationInMaps(latitude, longitude!),
                                icon: const Icon(Icons.map_outlined, size: 16),
                                label: const Text('Open in maps'),
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(
                            Icons.notes_outlined,
                            size: 16,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Description',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: SelectableText(
                          '${report['description'] ?? 'No description provided.'}',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(
                            Icons.photo_camera_outlined,
                            size: 16,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Photo evidence',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (signedUrl != null)
                        GestureDetector(
                          onTap: () => _openPhotoFullscreen(signedUrl),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: Stack(
                              children: [
                                Image.network(
                                  signedUrl,
                                  height: 220,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const _EvidenceMessage(
                                        'Private evidence could not be displayed.',
                                      ),
                                ),
                                Positioned(
                                  right: 8,
                                  bottom: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Colors.black45,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.zoom_in,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (report['photo_url'] != null)
                        const _EvidenceMessage(
                          'Private evidence exists but a signed preview could not be created.',
                        )
                      else
                        const _EvidenceMessage(
                          'No photo evidence was attached — not required for self-reported symptoms.',
                        ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Close'),
                    ),
                    const Spacer(),
                    if (status == 'pending')
                      OutlinedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _update(report, 'under_review');
                        },
                        child: const Text('Start review'),
                      ),
                    if (status == 'pending' || status == 'under_review') ...[
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _update(report, 'rejected');
                        },
                        child: const Text('Reject'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _update(report, 'verified');
                        },
                        icon: const Icon(Icons.verified, size: 18),
                        label: const Text('Verify'),
                      ),
                    ],
                    if (status == 'verified')
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _update(report, 'resolved');
                        },
                        icon: const Icon(Icons.task_alt, size: 18),
                        label: const Text('Mark resolved'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Same danger-sign phrase list report_form.dart short-circuits to an
  /// emergency banner on — reused here to surface it to the reviewer too,
  /// since a health worker deciding review order should see the same
  /// signal the resident already saw while typing.
  bool _isFlagged(Map<String, dynamic> report) =>
      AiService.instance.hasDangerSigns(
        '${report['description'] ?? ''}'.toLowerCase(),
      );

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
    // Flagged reports first, then newest first within each group — an
    // explicit comparator instead of relying on List.sort's stability, so
    // the created_at-desc ordering fetchReports() already provides isn't
    // left to chance as a secondary sort.
    filtered.sort((a, b) {
      final aFlagged = _isFlagged(a);
      final bFlagged = _isFlagged(b);
      if (aFlagged != bFlagged) return aFlagged ? -1 : 1;
      final aDate = DateTime.tryParse('${a['created_at']}') ?? DateTime(0);
      final bDate = DateTime.tryParse('${b['created_at']}') ?? DateTime(0);
      return bDate.compareTo(aDate);
    });
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
                tooltip: 'Refresh',
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
                      final flagged = _isFlagged(report);
                      return Card(
                        shape: flagged
                            ? RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                side: BorderSide(
                                  color: AppColors.danger.withValues(
                                    alpha: 0.5,
                                  ),
                                  width: 1.5,
                                ),
                              )
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (flagged)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.emergency_outlined,
                                        size: 14,
                                        color: AppColors.danger,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Warning sign flagged — review first',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: AppColors.danger,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
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

/// Icon + label header with the value underneath, and an optional trailing
/// action (e.g. "Open in maps") on the header line. Replaces the old
/// `_Field` label-over-value pair with something that reads more like a
/// reviewed record than a raw debug dump.
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AppColors.textMuted),
          ),
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
      const SizedBox(height: 4),
      Padding(
        padding: const EdgeInsets.only(left: 22),
        child: SelectableText(
          value,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    ],
  );
}

/// Small pill next to the reporter's name when they have other reports on
/// file — a quiet signal, not a judgment call either way (a repeat reporter
/// could mean a persistent hotspot they keep flagging, or could warrant a
/// closer look; the reviewer decides, this just surfaces the fact).
class _PriorReportsBadge extends StatelessWidget {
  final int count;
  const _PriorReportsBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        '$count prior report${count == 1 ? '' : 's'}',
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

/// Muted placeholder line used wherever the photo-evidence slot has nothing
/// (or nothing displayable) to show — keeps the empty state from reading
/// like an error.
class _EvidenceMessage extends StatelessWidget {
  final String message;
  const _EvidenceMessage(this.message);

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.image_not_supported_outlined,
          size: 18,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
          ),
        ),
      ],
    ),
  );
}
