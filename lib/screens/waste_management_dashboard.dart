import 'dart:math';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../utils/ui_helpers.dart';
import '../widgets/notifications_panel.dart';
import '../widgets/section_header.dart';
import '../widgets/shared_widgets.dart';

class WasteManagementDashboard extends StatefulWidget {
  const WasteManagementDashboard({super.key});

  @override
  State<WasteManagementDashboard> createState() =>
      _WasteManagementDashboardState();
}

class _WasteManagementDashboardState extends State<WasteManagementDashboard> {
  List<Map<String, dynamic>> _items = [];
  final Set<String> _busyIds = {};
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
      _items = await DatabaseService.instance.fetchWasteRequests();
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _update(String id, String status) async {
    if (_busyIds.contains(id)) return;
    setState(() => _busyIds.add(id));
    try {
      await DatabaseService.instance.updateWasteStatus(id, status);
      if (mounted) {
        showMessage(
          context,
          'Request marked ${humanize(status).toLowerCase()}.',
        );
      }
      await _load();
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
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
        title: const Text('Private request evidence'),
        content: SizedBox(
          width: min(560, MediaQuery.sizeOf(context).width - 48),
          child: signedUrl == null
              ? Text(
                  path == null
                      ? 'No photo evidence was attached.'
                      : 'The private preview could not be created. Check personnel access and try again.',
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
                        child: Text('Private evidence could not be displayed.'),
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
    if (_filter == 'all') return _items;
    if (_filter == 'active') {
      return _items
          .where((item) => ['pending', 'scheduled'].contains(item['status']))
          .toList();
    }
    if (_filter == 'assigned') {
      final userId = authService.currentUser?.id;
      return _items
          .where(
            (item) =>
                userId != null &&
                item['handled_by'] == userId &&
                ['scheduled', 'collected'].contains(item['status']),
          )
          .toList();
    }
    return _items.where((item) => item['status'] == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final pending = _items.where((item) => item['status'] == 'pending').length;
    final scheduled = _items
        .where((item) => item['status'] == 'scheduled')
        .length;
    final collected = _items
        .where((item) => item['status'] == 'collected')
        .length;
    final filtered = _filtered;
    final firstName =
        authService.currentUser?.fullName.trim().split(' ').first ??
        'Personnel';

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: 'Waste personnel dashboard',
              subtitle:
                  'Welcome, $firstName. Prioritize, schedule, and complete resident collection requests.',
              action: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => openNotificationsPanel(context),
                    icon: const Icon(Icons.notifications_outlined),
                    tooltip: 'Notifications',
                  ),
                  IconButton(
                    onPressed: _loading ? null : _load,
                    tooltip: 'Refresh requests',
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Icon(
                        Icons.delete_sweep_outlined,
                        color: AppColors.onPrimary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'OPERATIONS ACTIVE',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.9,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$pending request${pending == 1 ? '' : 's'} awaiting a schedule',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 700
                      ? 3
                      : (constraints.maxWidth >= 430 ? 2 : 1);
                  return GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: constraints.maxWidth < 430 ? 1.1 : 1.3,
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
                        value: '$collected',
                        label: 'Collected',
                        icon: Icons.task_alt_outlined,
                        color: AppColors.success,
                      ),
                    ],
                  );
                },
              ),
            ),
            SizedBox(
              height: 58,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 5),
                children: [
                  for (final value in const [
                    'active',
                    'assigned',
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
                emptyMessage:
                    'Resident collection requests that match this filter will appear here.',
                onRetry: _load,
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 9),
                    itemBuilder: (context, index) => _RequestCard(
                      item: filtered[index],
                      busy: _busyIds.contains('${filtered[index]['id']}'),
                      currentUserId: authService.currentUser?.id,
                      onEvidence: () => _showEvidence(filtered[index]),
                      onUpdate: (status) =>
                          _update('${filtered[index]['id']}', status),
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

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool busy;
  final String? currentUserId;
  final VoidCallback onEvidence;
  final ValueChanged<String> onUpdate;

  const _RequestCard({
    required this.item,
    required this.busy,
    required this.currentUserId,
    required this.onEvidence,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final resident = item['profiles'] as Map<String, dynamic>?;
    final status = '${item['status']}';
    final handledBy = item['handled_by'] as String?;
    final assignedToMe = handledBy != null && handledBy == currentUserId;

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
              maxLines: 4,
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
                if (assignedToMe)
                  const _MetaChip(
                    icon: Icons.person_pin_circle_outlined,
                    text: 'Assigned to you',
                  )
                else if (handledBy != null)
                  const _MetaChip(
                    icon: Icons.assignment_ind_outlined,
                    text: 'Assigned',
                  ),
              ],
            ),
            const SizedBox(height: 13),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : onEvidence,
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: Text(
                    item['photo_url'] == null
                        ? 'Evidence details'
                        : 'View evidence',
                  ),
                ),
                if (status == 'pending') ...[
                  OutlinedButton(
                    onPressed: busy ? null : () => onUpdate('cancelled'),
                    child: const Text('Cancel request'),
                  ),
                  FilledButton.icon(
                    onPressed: busy ? null : () => onUpdate('scheduled'),
                    icon: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: AppColors.onPrimary,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.event_available, size: 18),
                    label: const Text('Schedule & assign'),
                  ),
                ] else if (status == 'scheduled' &&
                    (handledBy == null || assignedToMe))
                  FilledButton.icon(
                    onPressed: busy ? null : () => onUpdate('collected'),
                    icon: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: AppColors.onPrimary,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.task_alt, size: 18),
                    label: Text(
                      handledBy == null
                          ? 'Take & mark collected'
                          : 'Mark collected',
                    ),
                  )
                else if (status == 'scheduled' && !assignedToMe)
                  const Text(
                    'Another team member owns this assignment.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
              ],
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
