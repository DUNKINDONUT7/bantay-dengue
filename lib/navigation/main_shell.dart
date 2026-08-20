// lib/navigation/main_shell.dart
//
// One shell per role. Each role gets its own bottom nav / rail / sidebar
// with only the destinations that make sense for it -- a civilian never
// sees "Verification Queue" and an admin never sees "Book Appointment".
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/notifications_panel.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/futuristic_backdrop.dart';

class NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String path;

  const NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.path,
  });
}

// --- Per-role navigation destinations ---------------------------------------

const List<NavItem> civilianNavItems = [
  NavItem(
    label: 'Home',
    icon: Icons.home_outlined,
    activeIcon: Icons.home,
    path: '/civilian/home',
  ),
  NavItem(
    label: 'Report',
    icon: Icons.report_outlined,
    activeIcon: Icons.report,
    path: '/civilian/report',
  ),
  NavItem(
    label: 'Assistant',
    icon: Icons.smart_toy_outlined,
    activeIcon: Icons.smart_toy,
    path: '/civilian/assistant',
  ),
  NavItem(
    label: 'Appointments',
    icon: Icons.calendar_month_outlined,
    activeIcon: Icons.calendar_month,
    path: '/civilian/appointments',
  ),
  NavItem(
    label: 'Profile',
    icon: Icons.person_outlined,
    activeIcon: Icons.person,
    path: '/civilian/profile',
  ),
];

// Extra destinations only shown on the wider web/tablet sidebar for civilians.
const List<NavItem> civilianExtraNavItems = [
  NavItem(
    label: 'Hotspots',
    icon: Icons.map_outlined,
    activeIcon: Icons.map,
    path: '/civilian/map',
  ),
  NavItem(
    label: 'Waste',
    icon: Icons.delete_outline,
    activeIcon: Icons.delete,
    path: '/civilian/waste',
  ),
  NavItem(
    label: 'Advisories',
    icon: Icons.campaign_outlined,
    activeIcon: Icons.campaign,
    path: '/civilian/advisories',
  ),
];

const List<NavItem> doctorNavItems = [
  NavItem(
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    activeIcon: Icons.dashboard,
    path: '/doctor',
  ),
  NavItem(
    label: 'Verify',
    icon: Icons.fact_check_outlined,
    activeIcon: Icons.fact_check,
    path: '/doctor/verification',
  ),
  NavItem(
    label: 'Appointments',
    icon: Icons.calendar_month_outlined,
    activeIcon: Icons.calendar_month,
    path: '/doctor/appointments',
  ),
  NavItem(
    label: 'Hotspots',
    icon: Icons.map_outlined,
    activeIcon: Icons.map,
    path: '/doctor/hotspots',
  ),
  NavItem(
    label: 'Profile',
    icon: Icons.person_outlined,
    activeIcon: Icons.person,
    path: '/doctor/profile',
  ),
];

const List<NavItem> doctorExtraNavItems = [
  NavItem(
    label: 'Waste',
    icon: Icons.delete_outline,
    activeIcon: Icons.delete,
    path: '/doctor/waste',
  ),
  NavItem(
    label: 'Advisories',
    icon: Icons.campaign_outlined,
    activeIcon: Icons.campaign,
    path: '/doctor/advisories',
  ),
];

const List<NavItem> adminNavItems = [
  NavItem(
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    activeIcon: Icons.dashboard,
    path: '/admin',
  ),
  NavItem(
    label: 'Users',
    icon: Icons.people_outline,
    activeIcon: Icons.people,
    path: '/admin/users',
  ),
  NavItem(
    label: 'Verify',
    icon: Icons.fact_check_outlined,
    activeIcon: Icons.fact_check,
    path: '/admin/verification',
  ),
  NavItem(
    label: 'Announce',
    icon: Icons.campaign_outlined,
    activeIcon: Icons.campaign,
    path: '/admin/announcements',
  ),
  NavItem(
    label: 'Profile',
    icon: Icons.person_outlined,
    activeIcon: Icons.person,
    path: '/admin/profile',
  ),
];

const List<NavItem> adminExtraNavItems = [
  NavItem(
    label: 'Hotspots',
    icon: Icons.map_outlined,
    activeIcon: Icons.map,
    path: '/admin/hotspots',
  ),
  NavItem(
    label: 'Waste',
    icon: Icons.delete_sweep_outlined,
    activeIcon: Icons.delete_sweep,
    path: '/admin/waste',
  ),
  NavItem(
    label: 'Advisories',
    icon: Icons.health_and_safety_outlined,
    activeIcon: Icons.health_and_safety,
    path: '/admin/advisories',
  ),
];

const List<NavItem> wasteNavItems = [
  NavItem(
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    activeIcon: Icons.dashboard,
    path: '/waste-management',
  ),
  NavItem(
    label: 'Hotspots',
    icon: Icons.map_outlined,
    activeIcon: Icons.map,
    path: '/waste-management/map',
  ),
  NavItem(
    label: 'Advisories',
    icon: Icons.campaign_outlined,
    activeIcon: Icons.campaign,
    path: '/waste-management/advisories',
  ),
  NavItem(
    label: 'Account',
    icon: Icons.manage_accounts_outlined,
    activeIcon: Icons.manage_accounts,
    path: '/waste-management/account',
  ),
];

const List<NavItem> wasteExtraNavItems = [];

// --- Generic role shell (mobile bottom bar / tablet rail / web sidebar) -----

class RoleShell extends StatelessWidget {
  final Widget child;
  final List<NavItem> navItems;
  final List<NavItem> extraNavItems;
  final String roleLabel;

  const RoleShell({
    super.key,
    required this.child,
    required this.navItems,
    required this.roleLabel,
    this.extraNavItems = const [],
  });

  int _selectedIndex(BuildContext context, List<NavItem> items) {
    final location = GoRouterState.of(context).uri.toString();
    int best = -1;
    int bestLen = -1;
    for (int i = 0; i < items.length; i++) {
      if (location.startsWith(items[i].path) &&
          items[i].path.length > bestLen) {
        best = i;
        bestLen = items[i].path.length;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWeb = width >= 900;
    final isTablet = width >= 600 && width < 900;

    final Widget layout;

    if (isWeb) {
      layout = _WebLayout(
        navItems: navItems,
        extraNavItems: extraNavItems,
        roleLabel: roleLabel,
        selected: _selectedIndex(context, [...navItems, ...extraNavItems]),
        child: child,
      );
    } else if (isTablet) {
      final selectedAcrossAll = _selectedIndex(context, [
        ...navItems,
        ...extraNavItems,
      ]);
      layout = _TabletLayout(
        navItems: navItems,
        moreItems: extraNavItems,
        roleLabel: roleLabel,
        selected: selectedAcrossAll < 0
            ? 0
            : selectedAcrossAll < navItems.length
            ? selectedAcrossAll
            : navItems.length,
        child: child,
      );
    } else {
      // Keep mobile navigation to five compact destinations while still
      // exposing every role-authorized route through a polished More sheet.
      final primaryItems = navItems.length > 4
          ? navItems.take(4).toList(growable: false)
          : navItems;
      final moreItems = [
        if (navItems.length > primaryItems.length)
          ...navItems.skip(primaryItems.length),
        ...extraNavItems,
      ];
      final selectedAcrossAll = _selectedIndex(context, [
        ...primaryItems,
        ...moreItems,
      ]);
      layout = _MobileLayout(
        navItems: primaryItems,
        moreItems: moreItems,
        roleLabel: roleLabel,
        selected: selectedAcrossAll < 0
            ? 0
            : selectedAcrossAll < primaryItems.length
            ? selectedAcrossAll
            : primaryItems.length,
        child: child,
      );
    }

    return FuturisticBackdrop(child: layout);
  }
}

Future<void> _showMoreNavigation(
  BuildContext context,
  List<NavItem> moreItems,
  String roleLabel,
) async {
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('More', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(roleLabel, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: moreItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (_, index) {
                final item = moreItems[index];
                final location = GoRouterState.of(context).uri.toString();
                final active = location.startsWith(item.path);
                return ListTile(
                  minTileHeight: 52,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    side: BorderSide(
                      color: active ? AppColors.textPrimary : AppColors.border,
                    ),
                  ),
                  tileColor: active
                      ? AppColors.surfaceElevated
                      : AppColors.surfaceCard,
                  leading: Icon(active ? item.activeIcon : item.icon),
                  title: Text(item.label),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.go(item.path);
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _MobileLayout extends StatelessWidget {
  final Widget child;
  final List<NavItem> navItems;
  final List<NavItem> moreItems;
  final String roleLabel;
  final int selected;

  const _MobileLayout({
    required this.child,
    required this.navItems,
    required this.moreItems,
    required this.roleLabel,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final destinations = [
      ...navItems.map(
        (item) => BottomNavigationBarItem(
          icon: Icon(item.icon),
          activeIcon: Icon(item.activeIcon),
          label: item.label,
        ),
      ),
      if (moreItems.isNotEmpty)
        const BottomNavigationBarItem(
          icon: Icon(Icons.grid_view_outlined),
          activeIcon: Icon(Icons.grid_view_rounded),
          label: 'More',
        ),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: child,
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          0,
          12,
          12 + MediaQuery.of(context).padding.bottom,
        ),
        child: LiquidGlass(
          padding: EdgeInsets.zero,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            currentIndex: selected.clamp(0, destinations.length - 1),
            type: BottomNavigationBarType.fixed,
            onTap: (index) {
              if (index < navItems.length) {
                context.go(navItems[index].path);
              } else {
                _showMoreNavigation(context, moreItems, roleLabel);
              }
            },
            items: destinations,
          ),
        ),
      ),
    );
  }
}

class _TabletLayout extends StatelessWidget {
  final Widget child;
  final List<NavItem> navItems;
  final List<NavItem> moreItems;
  final String roleLabel;
  final int selected;

  const _TabletLayout({
    required this.child,
    required this.navItems,
    required this.moreItems,
    required this.roleLabel,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(right: BorderSide(color: AppColors.border)),
            ),
            child: NavigationRail(
              selectedIndex: selected,
              onDestinationSelected: (index) {
                if (index < navItems.length) {
                  context.go(navItems[index].path);
                } else {
                  _showMoreNavigation(context, moreItems, roleLabel);
                }
              },
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    const _ShieldBadge(),
                    const SizedBox(height: 14),
                    IconButton(
                      onPressed: () => openNotificationsPanel(context),
                      icon: const Icon(Icons.notifications_outlined),
                      tooltip: 'Notifications',
                    ),
                  ],
                ),
              ),
              destinations: [
                ...navItems.map(
                  (item) => NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.activeIcon),
                    label: Text(item.label),
                  ),
                ),
                if (moreItems.isNotEmpty)
                  const NavigationRailDestination(
                    icon: Icon(Icons.grid_view_outlined),
                    selectedIcon: Icon(Icons.grid_view_rounded),
                    label: Text('More'),
                  ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _WebLayout extends StatelessWidget {
  final Widget child;
  final List<NavItem> navItems;
  final List<NavItem> extraNavItems;
  final String roleLabel;
  final int selected;
  const _WebLayout({
    required this.child,
    required this.navItems,
    required this.extraNavItems,
    required this.roleLabel,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        children: [
          _WebSidebar(
            navItems: navItems,
            extraNavItems: extraNavItems,
            roleLabel: roleLabel,
            selected: selected,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ResponsiveContainer(child: child),
            ),
          ),
        ],
      ),
    );
  }
}

class _WebSidebar extends StatelessWidget {
  final List<NavItem> navItems;
  final List<NavItem> extraNavItems;
  final String roleLabel;
  final int selected;
  const _WebSidebar({
    required this.navItems,
    required this.extraNavItems,
    required this.roleLabel,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final allItems = [...navItems, ...extraNavItems];
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 4),
            child: BantayDengueLogo(fontSize: 17),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    roleLabel,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => openNotificationsPanel(context),
                  icon: const Icon(Icons.notifications_outlined, size: 19),
                  tooltip: 'Notifications',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(color: AppColors.border),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: allItems.length,
              itemBuilder: (context, i) {
                final item = allItems[i];
                final isActive = i == selected;
                return _SidebarNavItem(
                  item: item,
                  isActive: isActive,
                  onTap: () => context.go(item.path),
                );
              },
            ),
          ),
          const Divider(color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                OutlinedButton.icon(
                  onPressed: () async => authService.signOut(),
                  icon: const Icon(
                    Icons.logout,
                    size: 18,
                    color: AppColors.riskHigh,
                  ),
                  label: const Text(
                    'Logout',
                    style: TextStyle(color: AppColors.riskHigh),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 42),
                    side: BorderSide(
                      color: AppColors.riskHigh.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _SidebarNavItem extends StatefulWidget {
  final NavItem item;
  final bool isActive;
  final VoidCallback onTap;
  const _SidebarNavItem({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isActive;
    final highlighted = active || _hovering;
    final fg = active
        ? AppColors.primary
        : (_hovering ? AppColors.textPrimary : AppColors.textSecondary);
    final iconColor = active
        ? AppColors.primary
        : (_hovering ? AppColors.textSecondary : AppColors.textMuted);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(vertical: 2),
        transform: Matrix4.translationValues(highlighted ? 3 : 0, 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: active
              ? AppColors.primaryGlow
              : (_hovering ? AppColors.surfaceElevated : Colors.transparent),
          border: active
              ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 11,
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    width: active ? 3 : 0,
                    height: 16,
                    margin: EdgeInsets.only(right: active ? 9 : 0),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  AnimatedScale(
                    scale: highlighted ? 1.1 : 1.0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    child: Icon(
                      active ? widget.item.activeIcon : widget.item.icon,
                      color: iconColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.item.label,
                      style: TextStyle(
                        color: fg,
                        fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 14,
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
}

class _ShieldBadge extends StatelessWidget {
  const _ShieldBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: const Icon(Icons.shield, color: AppColors.onPrimary, size: 20),
    );
  }
}
