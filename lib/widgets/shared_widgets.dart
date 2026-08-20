import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../screens/admin_dashboard.dart';
import '../screens/health_worker_dashboard.dart';
import '../screens/dashboard_screen.dart';
import '../screens/user_management_screen.dart';
import '../screens/waste_management_dashboard.dart';
import '../screens/civilian/hotspot_map_screen.dart';
import '../screens/civilian/ai_chat_screen.dart';

// ─── Responsive Container ──────────────────────────────────────────────────
// Centers and caps page content on wide/web screens so cards and text don't
// stretch edge-to-edge on a desktop monitor. Wrap a screen's scrollable body
// content in this; it's a no-op (full width) below the breakpoint.
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = AppSpacing.maxContentWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────
class StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;
  /// Optional short status line under the label — e.g. "3 today". Only pass
  /// values derived from real fetched data; never a fabricated trend.
  final String? caption;

  const StatCard({
    super.key,
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
    this.onTap,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 17),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: AppTypography.statNumber(context, color: AppColors.ink),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (caption != null) ...[
                const SizedBox(height: 4),
                Text(
                  caption!,
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Alert Banner ─────────────────────────────────────────────────────────────
class AlertBanner extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onViewDetails;

  const AlertBanner({
    super.key,
    required this.title,
    required this.message,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(Icons.campaign, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
                if (onViewDetails != null) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: onViewDetails,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View advisory',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Note: this file intentionally does NOT define its own SectionHeader.
// The single, real implementation (title/subtitle/action) lives in
// widgets/section_header.dart and is used by every screen. An older,
// differently-shaped SectionHeader (title/actionLabel/onAction) used to
// live here too — it was dead code (nothing referenced it), but Dart
// throws an ambiguous-import error the moment a file imports both this
// file and section_header.dart, which is exactly what broke the build.
// Removed rather than renamed, since nothing used it.

// ─── Quick Action Button ──────────────────────────────────────────────────────
class QuickActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const QuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<QuickActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(widget.icon, color: widget.color, size: 26),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 70,
              child: Text(
                widget.label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Fly Action Button ──────────────────────────────────────────────────────
/// Pill-shaped quick-action button with a playful icon "liftoff" flourish on
/// hover/press instead of a static icon — for dashboard quick-action rows.
/// Adapted from the classic animated "Send" button pattern, but the label
/// never slides away on hover: unlike a single-purpose send button, each of
/// these means something different and has to stay legible while browsing.
class FlyActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  const FlyActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  State<FlyActionButton> createState() => _FlyActionButtonState();
}

class _FlyActionButtonState extends State<FlyActionButton> {
  bool _hovering = false;
  bool _pressed = false;

  bool get _active => _hovering || _pressed;

  @override
  Widget build(BuildContext context) {
    final fg = widget.filled ? AppColors.onPrimary : AppColors.primary;
    final bg = widget.filled
        ? AppColors.primary
        : (_active ? AppColors.primaryGlow : Colors.transparent);
    final border = widget.filled
        ? Colors.transparent
        : AppColors.primary.withValues(alpha: _active ? 0.6 : 0.35);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.95 : (_hovering ? 1.03 : 1.0),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: border),
              boxShadow: _active && widget.filled
                  ? AppGlow.soft(AppColors.primary)
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: _active ? 1.0 : 0.0),
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  builder: (context, t, child) => Transform.translate(
                    offset: Offset(t * 3, -t * 3),
                    child: Transform.rotate(angle: t * 0.35, child: child),
                  ),
                  child: Icon(widget.icon, color: fg, size: 18),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── BantayDengue Logo ─────────────────────────────────────────────────────────
class BantayDengueLogo extends StatelessWidget {
  final double fontSize;
  const BantayDengueLogo({super.key, this.fontSize = 18});

  @override
  Widget build(BuildContext context) {
    final base = AppTypography.heading(context).copyWith(fontSize: fontSize);
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(text: 'Bantay', style: base.copyWith(color: AppColors.ink)),
          TextSpan(
            text: 'Dengue',
            style: base.copyWith(color: AppColors.danger),
          ),
        ],
      ),
    );
  }
}

// ─── BantayDengue App Bar ─────────────────────────────────────────────────────
class BantayDengueAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String title;
  final bool showLogo;
  final List<Widget>? actions;
  final bool showBack;

  const BantayDengueAppBar({
    super.key,
    this.title = '',
    this.showLogo = false,
    this.actions,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
            )
          : null,
      title: showLogo
          ? const BantayDengueLogo(fontSize: 18)
          : Text(title, style: AppTypography.subheading(context)),
      actions: actions,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Theme.of(context).dividerColor),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);
}

// ─── Risk Badge ───────────────────────────────────────────────────────────────
class RiskBadge extends StatelessWidget {
  final String risk;
  const RiskBadge({super.key, required this.risk});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (risk.toLowerCase()) {
      case 'high':
        color = AppColors.riskHigh;
        break;
      case 'medium':
      case 'moderate':
        color = AppColors.riskMedium;
        break;
      default:
        color = AppColors.riskLow;
    }
    return _DotPill(label: risk, color: color);
  }
}

// ─── Status Pill (generic — used for report/appointment/waste statuses) ──────
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const StatusPill({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return _DotPill(label: label, color: color);
  }
}

/// Shared minimal treatment for both badge types: cream fill, thin border,
/// a colored dot instead of a heavy tinted background.
class _DotPill extends StatelessWidget {
  final String label;
  final Color color;
  const _DotPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty State ────────────────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: AppColors.surfaceElevated,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.textMuted, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}

// ─── Input Field ──────────────────────────────────────────────────────────────
class BDTextField extends StatelessWidget {
  final String hint;
  final String? label;
  final TextEditingController? controller;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  const BDTextField({
    super.key,
    required this.hint,
    this.label,
    this.controller,
    this.suffixIcon,
    this.prefixIcon,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      validator: validator,
      onChanged: onChanged,
      enabled: enabled,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffixIcon,
        prefixIcon: prefixIcon,
        counterText: maxLength != null ? null : '',
      ),
    );
  }
}

// ─── Demo Access Button ─────────────────────────────────────────────────────
/// Small popup menu used during testing/grading to quickly preview other
/// role dashboards without logging out. Add to app bars or sidebars.
///
/// This intentionally does NOT use `context.go(...)`. GoRouter's redirect
/// guard sends any signed-in user back to their own role's home the moment
/// the URL changes to a route that doesn't match their role — so a resident
/// tapping "Admin Dashboard" would briefly flash the page and immediately
/// bounce back, which looks exactly like a dead/unresponsive button. Pushing
/// the target screen directly on the root navigator previews it without
/// touching the URL, so the guard never fires.
class DemoAccessButton extends StatelessWidget {
  const DemoAccessButton({super.key});

  void _open(BuildContext context, String label, WidgetBuilder builder) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) => _DemoPreviewScaffold(label: label, builder: builder),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Demo access',
      icon: const Icon(Icons.flash_on_outlined),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'admin', child: Text('Admin Dashboard')),
        PopupMenuItem(value: 'admin_users', child: Text('Admin → Users')),
        PopupMenuItem(value: 'doctor', child: Text('Health Worker Dashboard')),
        PopupMenuItem(value: 'waste', child: Text('Waste Personnel Dashboard')),
        PopupMenuItem(value: 'civilian', child: Text('Civilian Dashboard')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'map', child: Text('Map / Hotspots')),
        PopupMenuItem(value: 'assistant', child: Text('AI Assistant')),
      ],
      onSelected: (key) {
        switch (key) {
          case 'admin':
            _open(context, 'Admin Dashboard', (_) => const AdminDashboard());
            break;
          case 'admin_users':
            _open(
              context,
              'Admin → Users',
              (_) => const UserManagementScreen(),
            );
            break;
          case 'doctor':
            _open(
              context,
              'Health Worker Dashboard',
              (_) => const HealthWorkerDashboard(),
            );
            break;
          case 'waste':
            _open(
              context,
              'Waste Personnel Dashboard',
              (_) => const WasteManagementDashboard(),
            );
            break;
          case 'civilian':
            _open(
              context,
              'Civilian Dashboard',
              (_) => const DashboardScreen(),
            );
            break;
          case 'map':
            _open(context, 'Map / Hotspots', (_) => const HotspotMapScreen());
            break;
          case 'assistant':
            _open(context, 'AI Assistant', (_) => const AiChatScreen());
            break;
        }
      },
    );
  }
}

/// Wraps a previewed screen with a floating exit affordance, since the
/// previewed screen may not carry its own back button (it's not being
/// reached through its normal nav shell).
class _DemoPreviewScaffold extends StatelessWidget {
  final String label;
  final WidgetBuilder builder;

  const _DemoPreviewScaffold({required this.label, required this.builder});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: builder(context)),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: SafeArea(
              bottom: false,
              child: Material(
                color: AppColors.surface.withValues(alpha: 0.95),
                shape: const StadiumBorder(
                  side: BorderSide(color: AppColors.border),
                ),
                elevation: 4,
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => Navigator.of(context).pop(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.arrow_back,
                          size: 16,
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Exit demo · $label',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Photo Picker Field ─────────────────────────────────────────────────────
/// Reusable "tap to add a photo" field used on report-style forms. Lets the
/// user pick from the camera or gallery, shows a preview once picked, and
/// exposes a remove (x) button. Works on mobile, desktop, and web (reads
/// bytes instead of relying on File, which is unavailable on web).
class PhotoPickerField extends StatelessWidget {
  final Uint8List? imageBytes;
  final ValueChanged<XFile?> onPicked;
  final double height;
  final String label;

  const PhotoPickerField({
    super.key,
    required this.imageBytes,
    required this.onPicked,
    this.height = 140,
    this.label = 'Tap to add a photo',
  });

  Future<void> _showPickerSheet(BuildContext context) async {
    final picker = ImagePicker();
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_camera_outlined,
                color: AppColors.primary,
              ),
              title: const Text('Take a photo'),
              onTap: () async {
                Navigator.pop(ctx);
                final file = await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 80,
                );
                if (file != null) onPicked(file);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.primary,
              ),
              title: const Text('Choose from gallery'),
              onTap: () async {
                Navigator.pop(ctx);
                final file = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 80,
                );
                if (file != null) onPicked(file);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (imageBytes != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              imageBytes!,
              height: height,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => onPicked(null),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => _showPickerSheet(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit,
                  color: AppColors.onPrimary,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () => _showPickerSheet(context),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_a_photo_outlined,
              color: AppColors.textMuted,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// Note: this file used to also define its own GlassPanel, duplicating
// widgets/glass_panel.dart (the one actually used, by dengue_stats_card.dart).
// Same dead-code/ambiguous-import risk as SectionHeader above — removed.
