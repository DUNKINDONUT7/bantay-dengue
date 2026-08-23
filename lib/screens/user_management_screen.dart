import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../utils/ui_helpers.dart';
import '../widgets/section_header.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<Map<String, dynamic>> _users = [];
  final Set<String> _busyIds = {};
  Map<String, int> _reportCounts = {};
  Map<String, int> _appointmentCounts = {};
  Map<String, int> _wasteCounts = {};
  Object? _error;
  bool _loading = true;
  String _query = '';

  Map<String, int> _countBy(List<Map<String, dynamic>> items, String idKey) {
    final counts = <String, int>{};
    for (final item in items) {
      final id = item[idKey] as String?;
      if (id == null) continue;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  String _canonicalRole(Object? value) {
    final role = '$value';
    if (role == 'waste_staff' || role == 'waste_management') {
      return 'waste_personnel';
    }
    return role;
  }

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
        DatabaseService.instance.fetchAppointments(),
        DatabaseService.instance.fetchWasteRequests(),
      ]);
      _users = values[0];
      _reportCounts = _countBy(values[1], 'reporter_id');
      _appointmentCounts = _countBy(values[2], 'patient_id');
      _wasteCounts = _countBy(values[3], 'requester_id');
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeRole(Map<String, dynamic> user, String role) async {
    final id = '${user['id']}';
    if (_busyIds.contains(id)) return;
    final old = _canonicalRole(user['role']);
    if (old == role) return;
    if (old == 'admin' && role != 'admin') {
      final adminCount = _users
          .where((u) => _canonicalRole(u['role']) == 'admin')
          .length;
      if (adminCount <= 1) {
        showMessage(
          context,
          'Cannot change this role — at least one administrator must remain.',
          error: true,
        );
        return;
      }
    }
    setState(() => _busyIds.add(id));
    try {
      await DatabaseService.instance.updateUserRole(id, role);
      if (!mounted) return;
      setState(() => user['role'] = role);
      showMessage(context, 'Role updated to ${humanize(role)}.');
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> user, bool active) async {
    final id = '${user['id']}';
    if (_busyIds.contains(id)) return;
    if (id == authService.currentUser?.id && !active) {
      showMessage(
        context,
        'You cannot suspend your own administrator account.',
        error: true,
      );
      return;
    }
    setState(() => _busyIds.add(id));
    try {
      await DatabaseService.instance.setUserActive(id, active);
      if (!mounted) return;
      setState(() => user['is_active'] = active);
      showMessage(
        context,
        active ? 'Account reactivated.' : 'Account suspended.',
      );
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _users.where((user) {
      final text = '${user['full_name']} ${user['email']} ${user['role']}'
          .toLowerCase();
      return text.contains(_query.toLowerCase());
    }).toList();
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: 'User administration',
              subtitle:
                  'Assign least-privilege roles and manage application access.',
              action: IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search name, email, or role',
                ),
              ),
            ),
            Expanded(
              child: AsyncStateView(
                loading: _loading,
                error: _error,
                empty: filtered.isEmpty,
                emptyTitle: 'No users found',
                emptyMessage: 'Try a different search.',
                onRetry: _load,
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final user = filtered[index];
                      final active = user['is_active'] as bool? ?? true;
                      final userId = '${user['id']}';
                      final reportCount = _reportCounts[userId] ?? 0;
                      final appointmentCount =
                          _appointmentCounts[userId] ?? 0;
                      final wasteCount = _wasteCounts[userId] ?? 0;
                      final activityParts = [
                        if (reportCount > 0)
                          '$reportCount report${reportCount == 1 ? '' : 's'}',
                        if (appointmentCount > 0)
                          '$appointmentCount appointment${appointmentCount == 1 ? '' : 's'}',
                        if (wasteCount > 0)
                          '$wasteCount waste request${wasteCount == 1 ? '' : 's'}',
                      ];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final info = Row(
                                children: [
                                  CircleAvatar(
                                    child: Text(
                                      ('${user['full_name']}'.isNotEmpty
                                              ? '${user['full_name']}'[0]
                                              : '?')
                                          .toUpperCase(),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${user['full_name']}',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                        Text('${user['email']}'),
                                        if (activityParts.isNotEmpty)
                                          Text(
                                            activityParts.join(' · '),
                                            style: const TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 11,
                                            ),
                                          ),
                                        if (!active)
                                          Text(
                                            'Suspended',
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.error,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                              final busy = _busyIds.contains(userId);
                              final controls = Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 190,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _canonicalRole(
                                        user['role'],
                                      ),
                                      decoration: const InputDecoration(
                                        labelText: 'Role',
                                        isDense: true,
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'resident',
                                          child: Text('Resident'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'health_worker',
                                          child: Text('Health worker'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'waste_personnel',
                                          child: Text('Waste personnel'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'admin',
                                          child: Text('Administrator'),
                                        ),
                                      ],
                                      onChanged: busy
                                          ? null
                                          : (value) {
                                              if (value != null) {
                                                _changeRole(user, value);
                                              }
                                            },
                                    ),
                                  ),
                                  if (busy)
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  else
                                    Tooltip(
                                      message: active
                                          ? 'Suspend account'
                                          : 'Reactivate account',
                                      child: Switch(
                                        value: active,
                                        onChanged: (value) =>
                                            _toggleActive(user, value),
                                      ),
                                    ),
                                ],
                              );
                              if (constraints.maxWidth < 650) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    info,
                                    const SizedBox(height: 12),
                                    controls,
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(child: info),
                                  controls,
                                ],
                              );
                            },
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
