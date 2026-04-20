import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/sidebar_viewmodel.dart';

// ══════════════════════════════════════════════════════════════════════════════
// SidebarContent — pure nav content, no size logic.
// Used both inline (desktop) and inside a Drawer (mobile).
// ══════════════════════════════════════════════════════════════════════════════

class SidebarContent extends StatefulWidget {
  final String activeTab;
  final Function(String) onTabChange;
  final String userRole;
  final bool isCollapsed;
  final VoidCallback? onCollapseTap;

  const SidebarContent({
    super.key,
    required this.activeTab,
    required this.onTabChange,
    required this.userRole,
    this.isCollapsed = false,
    this.onCollapseTap,
  });

  @override
  State<SidebarContent> createState() => _SidebarContentState();
}

class _SidebarContentState extends State<SidebarContent> {
  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<AuthViewModel>().logout().then((_) {
                Navigator.of(context).pushReplacementNamed('/login');
              });
            },
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.isCollapsed;

    return Column(
      children: [
        // ── Header ────────────────────────────────────────────────────────
        Container(
          padding: EdgeInsets.all(c ? 12 : 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFFA855F7)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.business_outlined, color: Colors.white),
              ),
              if (!c) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'HRMS Pro',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Enterprise Edition',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── Search ────────────────────────────────────────────────────────
        if (!c)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search_outlined, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
            ),
          ),

        // ── User Profile ──────────────────────────────────────────────────
        if (!c)
          Consumer<AuthViewModel>(
            builder: (context, authVM, _) {
              final user = authVM.currentUser;
              final displayName = user?.name ?? 'Unknown User';
              final roleLabel = (user?.role ?? widget.userRole).toUpperCase();
              String initials = 'U';
              if (user?.name != null && user!.name.trim().isNotEmpty) {
                final parts = user.name.trim().split(' ');
                initials = parts.length > 1
                    ? '${parts[0][0]}${parts[1][0]}'
                    : user.name[0];
              }
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF0F4FF), Color(0xFFF5F3FF)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFDEBEFE)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: const Color(0xFF3B82F6),
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              roleLabel,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.notifications_outlined),
                        iconSize: 16,
                        color: const Color(0xFF64748B),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

        // ── Navigation ────────────────────────────────────────────────────
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            children: _navSections(),
          ),
        ),

        // ── Footer ────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Column(
            children: [
              if (!c)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.bolt_outlined,
                        size: 16,
                        color: Color(0xFF3B82F6),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Premium Plan',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                            Text(
                              'Unlimited access',
                              style: TextStyle(
                                fontSize: 9,
                                color: Color(0xFF3B82F6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.shield_outlined,
                        size: 16,
                        color: Color(0xFF3B82F6),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),

              // Collapse toggle (desktop only, when callback provided)
              if (widget.onCollapseTap != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: widget.onCollapseTap,
                    icon: Icon(
                      c
                          ? Icons.chevron_right_rounded
                          : Icons.chevron_left_rounded,
                      size: 18,
                    ),
                    label: c ? const SizedBox.shrink() : const Text('Collapse'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _handleLogout,
                  icon: const Icon(Icons.logout_outlined, size: 18),
                  label: c ? const SizedBox.shrink() : const Text('Sign Out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: const Color(0xFFDC2626),
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: c ? 8 : 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _navSections() {
    return SidebarProvider.getNavigationForRole(widget.userRole)
        .map((e) => e is SidebarSection ? _section(e) : const SizedBox.shrink())
        .toList();
  }

  Widget _section(SidebarSection section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.isCollapsed)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Text(
              section.title.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ...section.items.map(_navItem),
      ],
    );
  }

  Widget _navItem(SidebarItem item) {
    final active = widget.activeTab == item.id;
    final c = widget.isCollapsed;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            widget.onTabChange(item.id);
            // Close drawer on mobile after tap
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: active ? const Color(0xFF3B82F6) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: c ? 24 : 20,
                  color: active ? Colors.white : const Color(0xFF475569),
                ),
                if (!c) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: active ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  if (item.badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white.withOpacity(0.3)
                            : _bgBadge(item.badgeColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        item.badge!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: active
                              ? Colors.white
                              : _fgBadge(item.badgeColor),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _bgBadge(String? c) {
    switch (c) {
      case 'emerald':
        return const Color(0xFFD1FAE5);
      case 'amber':
        return const Color(0xFFFEF3C7);
      case 'slate':
        return const Color(0xFFE2E8F0);
      default:
        return const Color(0xFFDBEAFE);
    }
  }

  Color _fgBadge(String? c) {
    switch (c) {
      case 'emerald':
        return const Color(0xFF15803D);
      case 'amber':
        return const Color(0xFFFCD34D);
      case 'slate':
        return const Color(0xFF475569);
      default:
        return const Color(0xFF1E40AF);
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Sidebar widget — drop-in replacement for the old Sidebar.
//
// DESKTOP (≥1024 px): renders an inline AnimatedContainer in the Row.
// MOBILE  (<1024 px): renders SizedBox.shrink() — the wrapper adds the
//   Scaffold.drawer via Sidebar.buildDrawer(...).
// ══════════════════════════════════════════════════════════════════════════════

class Sidebar extends StatefulWidget {
  final String activeTab;
  final Function(String) onTabChange;
  final String userRole;

  const Sidebar({
    super.key,
    required this.activeTab,
    required this.onTabChange,
    required this.userRole,
  });

  @override
  State<Sidebar> createState() => SidebarState();

  /// Returns a Flutter Drawer pre-filled with nav content.
  /// Add this to Scaffold.drawer in your mobile wrapper build.
  static Drawer buildDrawer({
    required String activeTab,
    required Function(String) onTabChange,
    required String userRole,
  }) {
    return Drawer(
      width: 280,
      child: SafeArea(
        child: SidebarContent(
          activeTab: activeTab,
          onTabChange: onTabChange,
          userRole: userRole,
        ),
      ),
    );
  }
}

class SidebarState extends State<Sidebar> {
  bool _collapsed = false;
  static const double _breakpoint = 1024;
  static const double _expanded = 280;
  static const double _slim = 70;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= _breakpoint;

    if (!isDesktop) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: _collapsed ? _slim : _expanded,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SidebarContent(
        activeTab: widget.activeTab,
        onTabChange: widget.onTabChange,
        userRole: widget.userRole,
        isCollapsed: _collapsed,
        onCollapseTap: () => setState(() => _collapsed = !_collapsed),
      ),
    );
  }
}
