import 'dart:math';

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/image_picker_stub.dart';
import '../../theme/app_theme.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/section_header.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loadingStats = true;
  bool _uploadingPhoto = false;
  int _reportCount = 0;
  int _appointmentCount = 0;
  int _wasteCount = 0;
  List<_ActivityItem> _recentActivity = const [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    try {
      final values = await Future.wait([
        DatabaseService.instance.fetchReports(ownOnly: true),
        DatabaseService.instance.fetchAppointments(ownOnly: true),
        DatabaseService.instance.fetchWasteRequests(ownOnly: true),
      ]);
      final reports = values[0];
      final appointments = values[1];
      final waste = values[2];
      _reportCount = reports.length;
      _appointmentCount = appointments.length;
      _wasteCount = waste.length;

      final combined = <_ActivityItem>[
        ...reports.map(
          (r) => _ActivityItem(
            icon: r['report_type'] == 'dengue_case'
                ? Icons.medical_information_outlined
                : Icons.pest_control_outlined,
            title: humanize(r['report_type'] as String?),
            subtitle: '${r['location_text'] ?? 'No location noted'}',
            status: '${r['status'] ?? 'pending'}',
            date: DateTime.tryParse('${r['created_at']}'),
          ),
        ),
        ...appointments.map(
          (a) => _ActivityItem(
            icon: Icons.event_outlined,
            title: 'Health center appointment',
            subtitle: '${a['reason'] ?? 'No reason noted'}',
            status: '${a['status'] ?? 'pending'}',
            date: DateTime.tryParse('${a['created_at']}'),
          ),
        ),
        ...waste.map(
          (w) => _ActivityItem(
            icon: Icons.delete_sweep_outlined,
            title: 'Waste collection request',
            subtitle: '${w['location_text'] ?? 'No location noted'}',
            status: '${w['status'] ?? 'pending'}',
            date: DateTime.tryParse('${w['created_at']}'),
          ),
        ),
      ]..sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));
      _recentActivity = combined.take(3).toList();
    } catch (_) {
      // Real activity counts only — leave at 0 rather than guess on failure.
    } finally {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  Future<void> _changePhoto() async {
    final bytes = await pickEvidenceImage(context);
    if (bytes == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      await DatabaseService.instance.updateProfilePhoto(bytes);
      if (mounted) {
        setState(() {});
        showMessage(context, 'Profile photo updated.');
      }
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) await authService.signOut();
  }

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
          width: min(440, MediaQuery.sizeOf(context).width - 48),
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
    final initial = (user?.fullName.isNotEmpty ?? false)
        ? user!.fullName[0].toUpperCase()
        : '?';
    final memberSince = user?.createdAt == null
        ? null
        : formatDateTime(user!.createdAt).split(' ·').first;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadStats,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Builder(
                  builder: (context) {
                    final heroCard = Card(
                      child: Column(
                        children: [
                          // Cover band — the same ink used for primary
                          // CTAs elsewhere, here as a small identity
                          // accent instead of a plain white settings
                          // card.
                          Container(height: 48, color: AppColors.ink),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                            child: Column(
                              children: [
                                Transform.translate(
                                  offset: const Offset(0, -28),
                                  child: _Avatar(
                                    initial: initial,
                                    photoUrl: user?.photoUrl,
                                    busy: _uploadingPhoto,
                                    onTap:
                                        _uploadingPhoto ? null : _changePhoto,
                                  ),
                                ),
                                Text(
                                  user?.fullName ?? 'User',
                                  style:
                                      Theme.of(context).textTheme.headlineSmall,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceElevated,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.pill),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Text(
                                    (user?.roleLabel ?? '').toUpperCase(),
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                if (memberSince != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Member since $memberSince',
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _StatStripItem(
                                        value: _reportCount,
                                        label: 'Reports',
                                        loading: _loadingStats,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 30,
                                      child: VerticalDivider(width: 1),
                                    ),
                                    Expanded(
                                      child: _StatStripItem(
                                        value: _appointmentCount,
                                        label: 'Appointments',
                                        loading: _loadingStats,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 30,
                                      child: VerticalDivider(width: 1),
                                    ),
                                    Expanded(
                                      child: _StatStripItem(
                                        value: _wasteCount,
                                        label: 'Waste',
                                        loading: _loadingStats,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                const Divider(height: 1),
                                _InfoRow(
                                  icon: Icons.email_outlined,
                                  label: 'Email',
                                  value: user?.email ?? '',
                                ),
                                _InfoRow(
                                  icon: Icons.phone_outlined,
                                  label: 'Phone',
                                  value: user?.phone,
                                ),
                                _InfoRow(
                                  icon: Icons.location_city_outlined,
                                  label: 'Barangay',
                                  value: user?.barangay,
                                  showDivider: false,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );

                    final activityCard = _recentActivity.isEmpty
                        ? null
                        : Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Recent activity',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  for (final item in _recentActivity)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceElevated,
                                              borderRadius:
                                                  BorderRadius.circular(9),
                                            ),
                                            child: Icon(
                                              item.icon,
                                              size: 15,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.title,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12.5,
                                                  ),
                                                ),
                                                Text(
                                                  item.subtitle,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: AppColors.textMuted,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          StatusChip(item.status),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );

                    final settingsCard = Card(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(
                                      alpha: 0.12,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.lock_outline,
                                    size: 17,
                                    color: AppColors.success,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Privacy protection',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Operational records and private evidence are protected '
                                        'by Supabase authentication and row-level security.',
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 11.5,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _confirmSignOut(context),
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(AppRadius.lg),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.logout,
                                      size: 18,
                                      color: AppColors.danger,
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Sign out',
                                      style: TextStyle(
                                        color: AppColors.danger,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        // Wide viewports (web/tablet, past the sidebar) put
                        // identity and activity/settings side by side so the
                        // page uses the full width instead of one narrow
                        // stacked column with dead space on either side.
                        final isWide = constraints.maxWidth >= 860;
                        if (!isWide) {
                          return Column(
                            children: [
                              heroCard,
                              if (activityCard != null) ...[
                                const SizedBox(height: 16),
                                activityCard,
                              ],
                              const SizedBox(height: 16),
                              settingsCard,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 360, child: heroCard),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                children: [
                                  if (activityCard != null) ...[
                                    activityCard,
                                    const SizedBox(height: 16),
                                  ],
                                  settingsCard,
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final DateTime? date;

  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.date,
  });
}

class _Avatar extends StatelessWidget {
  final String initial;
  final String? photoUrl;
  final bool busy;
  final VoidCallback? onTap;

  const _Avatar({
    required this.initial,
    required this.photoUrl,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.trim().isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              color: AppColors.ink,
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: busy
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onPrimary,
                      ),
                    ),
                  )
                : hasPhoto
                ? Image.network(
                    DatabaseService.instance.avatarPublicUrl(photoUrl!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Center(
                      child: Text(
                        initial,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(color: AppColors.onPrimary),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      initial,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(color: AppColors.onPrimary),
                    ),
                  ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: const Icon(
                Icons.photo_camera_outlined,
                size: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatStripItem extends StatelessWidget {
  final int value;
  final String label;
  final bool loading;

  const _StatStripItem({
    required this.value,
    required this.label,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        loading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                '$value',
                style: AppTypography.statNumber(context, size: 18),
              ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final bool showDivider;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.trim().isNotEmpty;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasValue ? value! : 'Not provided',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
                        color: hasValue ? AppColors.textPrimary : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }
}
