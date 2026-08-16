import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/theme_controller.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/section_header.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _edit() async {
    final user = authService.currentUser;
    if (user == null) return;
    final name = TextEditingController(text: user.fullName);
    final phone = TextEditingController(text: user.phone ?? '');
    final barangay = TextEditingController(text: user.barangay ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit profile'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: barangay,
                decoration: const InputDecoration(labelText: 'Barangay'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true && name.text.trim().length >= 2) {
      try {
        await DatabaseService.instance.updateOwnProfile(
          fullName: name.text.trim(),
          phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
          barangay: barangay.text.trim().isEmpty ? null : barangay.text.trim(),
        );
        if (mounted) {
          setState(() {});
          showMessage(context, 'Profile updated.');
        }
      } catch (error) {
        if (mounted) showMessage(context, errorMessage(error), error: true);
      }
    }
    name.dispose();
    phone.dispose();
    barangay.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = authService.currentUser;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          children: [
            SectionHeader(
              title: 'Profile & privacy',
              subtitle:
                  'Manage your personal contact information and app settings.',
              action: IconButton(
                onPressed: _edit,
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit profile',
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  children: [
                    Card(
                      margin: const EdgeInsets.all(16),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 44,
                              child: Text(
                                (user?.fullName.isNotEmpty ?? false)
                                    ? user!.fullName[0].toUpperCase()
                                    : '?',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              user?.fullName ?? 'User',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(user?.roleLabel ?? ''),
                            const Divider(height: 32),
                            ListTile(
                              leading: const Icon(Icons.email_outlined),
                              title: const Text('Email'),
                              subtitle: Text(user?.email ?? ''),
                            ),
                            ListTile(
                              leading: const Icon(Icons.phone_outlined),
                              title: const Text('Phone'),
                              subtitle: Text(user?.phone ?? 'Not provided'),
                            ),
                            ListTile(
                              leading: const Icon(Icons.location_city_outlined),
                              title: const Text('Barangay'),
                              subtitle: Text(user?.barangay ?? 'Not provided'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Card(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        children: [
                          ValueListenableBuilder<ThemeMode>(
                            valueListenable: themeController,
                            builder: (context, mode, _) => SwitchListTile(
                              secondary: const Icon(Icons.dark_mode_outlined),
                              title: const Text('Dark mode'),
                              value: mode == ThemeMode.dark,
                              onChanged: (value) => themeController.setMode(
                                value ? ThemeMode.dark : ThemeMode.light,
                              ),
                            ),
                          ),
                          const ListTile(
                            leading: Icon(Icons.lock_outline),
                            title: Text('Privacy protection'),
                            subtitle: Text(
                              'Operational records and private evidence are protected by Supabase authentication and row-level security.',
                            ),
                          ),
                          ListTile(
                            leading: const Icon(Icons.logout),
                            title: const Text('Sign out'),
                            onTap: authService.signOut,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
