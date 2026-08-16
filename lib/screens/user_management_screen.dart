import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../utils/ui_helpers.dart';
import '../widgets/section_header.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<Map<String, dynamic>> _users = [];
  Object? _error;
  bool _loading = true;
  String _query = '';

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
      _users = await DatabaseService.instance.fetchProfiles();
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeRole(Map<String, dynamic> user, String role) async {
    final old = '${user['role']}';
    if (old == role) return;
    try {
      await DatabaseService.instance.updateUserRole('${user['id']}', role);
      setState(() => user['role'] = role);
      if (mounted) showMessage(context, 'Role updated to ${humanize(role)}.');
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error), error: true);
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> user, bool active) async {
    if ('${user['id']}' == authService.currentUser?.id && !active) {
      showMessage(
        context,
        'You cannot suspend your own administrator account.',
        error: true,
      );
      return;
    }
    try {
      await DatabaseService.instance.setUserActive('${user['id']}', active);
      setState(() => user['is_active'] = active);
      if (mounted) {
        showMessage(
          context,
          active ? 'Account reactivated.' : 'Account suspended.',
        );
      }
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error), error: true);
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
                                      onChanged: (value) {
                                        if (value != null) {
                                          _changeRole(user, value);
                                        }
                                      },
                                    ),
                                  ),
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
