import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../utils/ui_helpers.dart';
import '../widgets/notifications_panel.dart';
import '../widgets/section_header.dart';

/// Dedicated account workspace for the waste-personnel role.
///
/// This intentionally does not reuse the resident activity page: personnel
/// receive operational shortcuts and never inherit resident-only navigation.
class WastePersonnelAccountScreen extends StatefulWidget {
  const WastePersonnelAccountScreen({super.key});

  @override
  State<WastePersonnelAccountScreen> createState() =>
      _WastePersonnelAccountScreenState();
}

class _WastePersonnelAccountScreenState
    extends State<WastePersonnelAccountScreen> {
  bool _saving = false;

  Future<void> _editProfile() async {
    final user = authService.currentUser;
    if (user == null || _saving) return;

    final name = TextEditingController(text: user.fullName);
    final phone = TextEditingController(text: user.phone ?? '');
    final barangay = TextEditingController(text: user.barangay ?? '');
    final formKey = GlobalKey<FormState>();

    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit personnel account'),
        content: SizedBox(
          width: min(440, MediaQuery.sizeOf(context).width - 48),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) => (value?.trim().length ?? 0) < 2
                        ? 'Enter your full name'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: barangay,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Assigned barangay',
                      prefixIcon: Icon(Icons.location_city_outlined),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Save changes'),
          ),
        ],
      ),
    );

    if (save == true) {
      setState(() => _saving = true);
      try {
        await DatabaseService.instance.updateOwnProfile(
          fullName: name.text.trim(),
          phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
          barangay: barangay.text.trim().isEmpty ? null : barangay.text.trim(),
        );
        if (mounted) showMessage(context, 'Personnel account updated.');
      } catch (error) {
        if (mounted) showMessage(context, errorMessage(error), error: true);
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }

    name.dispose();
    phone.dispose();
    barangay.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: authService,
      builder: (context, _) {
        final user = authService.currentUser;
        final initial = user?.fullName.trim().isNotEmpty == true
            ? user!.fullName.trim()[0].toUpperCase()
            : 'W';

        return Scaffold(
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: authService.refreshProfile,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  SectionHeader(
                    title: 'Personnel account',
                    subtitle:
                        'A separate operational identity for collection work and authorized waste records.',
                    action: IconButton(
                      tooltip: 'Edit account',
                      onPressed: _saving ? null : _editProfile,
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.edit_outlined),
                    ),
                  ),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(22),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final compact = constraints.maxWidth < 520;
                                    final identity = Column(
                                      crossAxisAlignment: compact
                                          ? CrossAxisAlignment.center
                                          : CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user?.fullName.isNotEmpty == true
                                              ? user!.fullName
                                              : 'Waste Personnel',
                                          textAlign: compact
                                              ? TextAlign.center
                                              : TextAlign.start,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.headlineSmall,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          user?.email ?? '',
                                          textAlign: compact
                                              ? TextAlign.center
                                              : TextAlign.start,
                                        ),
                                        const SizedBox(height: 10),
                                        const _RoleBadge(),
                                      ],
                                    );
                                    if (compact) {
                                      return Column(
                                        children: [
                                          CircleAvatar(
                                            radius: 38,
                                            child: Text(
                                              initial,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.headlineSmall,
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                          identity,
                                        ],
                                      );
                                    }
                                    return Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 38,
                                          child: Text(
                                            initial,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.headlineSmall,
                                          ),
                                        ),
                                        const SizedBox(width: 18),
                                        Expanded(child: identity),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Card(
                              child: Column(
                                children: [
                                  _AccountDetail(
                                    icon: Icons.phone_outlined,
                                    title: 'Contact number',
                                    value: user?.phone ?? 'Not provided',
                                  ),
                                  const Divider(),
                                  _AccountDetail(
                                    icon: Icons.location_city_outlined,
                                    title: 'Assigned barangay',
                                    value: user?.barangay ?? 'Not provided',
                                  ),
                                  const Divider(),
                                  const _AccountDetail(
                                    icon: Icons.verified_user_outlined,
                                    title: 'Access level',
                                    value: 'Waste operations only',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Card(
                              child: Column(
                                children: [
                                  ListTile(
                                    leading: const Icon(
                                      Icons.dashboard_outlined,
                                    ),
                                    title: const Text('Operations dashboard'),
                                    subtitle: const Text(
                                      'Open resident collection requests and assignments.',
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () =>
                                        context.go('/waste-management'),
                                  ),
                                  const Divider(),
                                  ListTile(
                                    leading: const Icon(
                                      Icons.notifications_outlined,
                                    ),
                                    title: const Text('Notifications'),
                                    subtitle: const Text(
                                      'Review collection and system updates.',
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => openNotificationsPanel(context),
                                  ),
                                  const Divider(),
                                  const ListTile(
                                    leading: Icon(Icons.lock_outline),
                                    title: Text('Protected account'),
                                    subtitle: Text(
                                      'Role and access changes require administrator authorization and are enforced by Supabase RLS.',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            OutlinedButton.icon(
                              onPressed: authService.signOut,
                              icon: Icon(
                                Icons.logout,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              label: Text(
                                'Sign out',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: const Text(
        'WASTE PERSONNEL',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _AccountDetail extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _AccountDetail({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value),
    );
  }
}
