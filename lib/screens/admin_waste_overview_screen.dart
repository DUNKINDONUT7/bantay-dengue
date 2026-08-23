import 'dart:math';

import 'package:flutter/material.dart';

import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../utils/ui_helpers.dart';
import '../widgets/section_header.dart';
import '../widgets/shared_widgets.dart';

/// Read-only audit view of waste-collection requests for the admin role.
///
/// The operational workflow — schedule, self-assign, mark collected, cancel
/// — belongs to Waste Personnel only (see waste_management_dashboard.dart
/// and BantayDengue_FINAL.sql's `protect_waste_personnel_update` trigger,
/// which assigns `handled_by` to whichever account performs the update).
/// Letting admin drive that same workflow would silently attribute
/// collections to an admin account instead of the personnel actually doing
/// the work, so this screen only ever reads: it exists so admin retains
/// visibility into the queue (matching their existing Users/Verify
/// oversight cards) without duplicating the personnel-only feature.
class AdminWasteOverviewScreen extends StatefulWidget {
  const AdminWasteOverviewScreen({super.key});

  @override
  State<AdminWasteOverviewScreen> createState() =>
      _AdminWasteOverviewScreenState();
}

class _AdminWasteOverviewScreenState extends State<AdminWasteOverviewScreen> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _personnel = [];
  Object? _error;
  bool _loading = true;
  String _filter = 'active';

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
        DatabaseService.instance.fetchWasteRequests(),
        DatabaseService.instance.fetchProfiles(),
      ]);
      _items = values[0];
      _personnel = values[1]
          .where((p) => p['role'] == 'waste_personnel')
          .toList();
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Read-only roster over the existing free-text `barangay` field on
  /// profiles — a formal zone-assignment table is a later escalation, not
  /// needed for admin to just see who covers what today. Counts are
  /// computed from `_items` already in state (handled_by), no new query.
  Future<void> _showRoster() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.7;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Waste personnel roster',
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Assigned barangay is self-reported by each account — '
                    'not an enforced coverage zone.',
                    style: Theme.of(sheetContext).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: _personnel.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              'No waste personnel accounts yet.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: _personnel.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final person = _personnel[index];
                              final id = '${person['id']}';
                              final active = person['is_active'] as bool? ?? true;
                              final collected = _items
                                  .where(
                                    (i) =>
                                        i['handled_by'] == id &&
                                        i['status'] == 'collected',
                                  )
                                  .length;
                              final inProgress = _items
                                  .where(
                                    (i) =>
                                        i['handled_by'] == id &&
                                        i['status'] == 'scheduled',
                                  )
                                  .length;
                              return ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.badge_outlined),
                                ),
                                title: Text('${person['full_name'] ?? 'Personnel'}'),
                                subtitle: Text(
                                  '${person['barangay'] ?? 'No barangay set'}'
                                  '${active ? '' : ' · Suspended'}',
                                ),
                                trailing: Text(
                                  '$collected done · $inProgress active',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEvidence(Map<String, dynamic> item) async {
    final path = item['photo_url'] as String?;
    final signedUrl = await DatabaseService.instance.createEvidenceUrl(
      bucket: 'waste-evidence',
      path: path,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Waste request evidence'),
        content: SizedBox(
          width: min(560, MediaQuery.sizeOf(context).width - 48),
          child: signedUrl == null
              ? Text(
                  path == null
                      ? 'No photo evidence was attached.'
                      : 'The private preview could not be created.',
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

  List<Map<String, dynamic>> get _filtered {
    switch (_filter) {
      case 'all':
        return _items;
      case 'active':
        return _items
            .where((item) => ['pending', 'scheduled'].contains(item['status']))
            .toList();
      case 'unassigned':
        return _items
            .where(
              (item) =>
                  item['handled_by'] == null &&
                  ['pending', 'scheduled'].contains(item['status']),
            )
            .toList();
      default:
        return _items.where((item) => item['status'] == _filter).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final pending = _items.where((i) => i['status'] == 'pending').length;
    final scheduled = _items.where((i) => i['status'] == 'scheduled').length;
    final unassigned = _items
        .where(
          (i) =>
              i['handled_by'] == null &&
              ['pending', 'scheduled'].contains(i['status']),
        )
        .length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: 'Waste requests',
              subtitle:
                  'Read-only oversight — scheduling and collection are handled by Waste Personnel.',
              action: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: _showRoster,
                    icon: const Icon(Icons.badge_outlined),
                    tooltip: 'Personnel roster',
                  ),
                  IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final count = constraints.maxWidth >= 520 ? 3 : 1;
                  return GridView.count(
                    crossAxisCount: count,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: count == 3 ? 1.6 : 3.2,
                    children: [
                      StatCard(
                        value: '$pending',
                        label: 'Pending',
                        icon: Icons.pending_actions_outlined,
                        color: AppColors.warning,
                      ),
                      StatCard(
                        value: '$scheduled',
                        label: 'Scheduled',
                        icon: Icons.event_available_outlined,
                        color: AppColors.info,
                      ),
                      StatCard(
                        value: '$unassigned',
                        label: 'Unassigned',
                        icon: Icons.person_off_outlined,
                        color: AppColors.textMuted,
                      ),
                    ],
                  );
                },
              ),
            ),
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final value in const [
                    'active',
                    'unassigned',
                    'pending',
                    'scheduled',
                    'collected',
                    'cancelled',
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
                emptyTitle: 'No matching requests',
                emptyMessage: 'Waste requests that match this filter will appear here.',
                onRetry: _load,
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 9),
                    itemBuilder: (context, index) => _ReadOnlyRequestCard(
                      item: filtered[index],
                      onEvidence: () => _showEvidence(filtered[index]),
                    ),
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

class _ReadOnlyRequestCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onEvidence;

  const _ReadOnlyRequestCard({required this.item, required this.onEvidence});

  @override
  Widget build(BuildContext context) {
    final resident = item['profiles'] as Map<String, dynamic>?;
    final status = '${item['status']}';
    final assigned = item['handled_by'] != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  child: Icon(Icons.delete_sweep_outlined, size: 20),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item['location_text'] ?? 'Pickup location'}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Requested by ${resident?['full_name'] ?? 'Resident'} · ${formatDateTime(item['created_at'])}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusChip(status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${item['description'] ?? 'No additional waste details.'}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 7,
              children: [
                _MetaChip(
                  icon: Icons.event_outlined,
                  text: 'Preferred ${formatDateTime(item['scheduled_at'])}',
                ),
                _MetaChip(
                  icon: assigned
                      ? Icons.assignment_ind_outlined
                      : Icons.person_off_outlined,
                  text: assigned ? 'Assigned' : 'Unassigned',
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onEvidence,
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: Text(
                item['photo_url'] == null ? 'Evidence details' : 'View evidence',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 10.5)),
        ],
      ),
    );
  }
}
