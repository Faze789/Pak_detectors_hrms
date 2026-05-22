import 'package:flutter/material.dart';

// Base class for navigation items
abstract class NavigationElement {
  const NavigationElement();
}

// Sidebar Item Model
class SidebarItem extends NavigationElement {
  final String id;
  final String label;
  final IconData icon;
  final String? badge;
  final String? badgeColor;

  const SidebarItem({
    required this.id,
    required this.label,
    required this.icon,
    this.badge,
    this.badgeColor,
  });
}

// Sidebar Section Model
class SidebarSection extends NavigationElement {
  final String title;
  final List<SidebarItem> items;

  const SidebarSection({required this.title, required this.items});
}

class SidebarProvider {
  // HR Navigation Items
  static const List<NavigationElement> hrNavigation = [
    // Overview
    SidebarSection(
      title: 'Overview',
      items: [
        SidebarItem(
          id: 'dashboard',
          label: 'Dashboard',
          icon: Icons.dashboard_outlined,
        ),
      ],
    ),
    // HR Management
    SidebarSection(
      title: 'HR Management',
      items: [
        SidebarItem(
          id: 'employees',
          label: 'Employees',
          icon: Icons.people_outlined,
        ),
        SidebarItem(
          id: 'ex-employees',
          label: 'Ex-Employees',
          icon: Icons.archive_outlined,
        ),
        SidebarItem(
          id: 'assign-task-employee-by-hr',
          label: 'Assign Task',
          icon: Icons.assignment_outlined,
        ),
        SidebarItem(
          id: 'employee-reports',
          label: 'Employee Reports',
          icon: Icons.assessment_outlined,
        ),
        SidebarItem(
          id: 'recruitment',
          label: 'Recruitment',
          icon: Icons.work_outline,
        ),
        SidebarItem(
          id: 'company-letters',
          label: 'Company Letter',
          icon: Icons.description_outlined,
        ),
        SidebarItem(
          id: 'performance',
          label: 'Performance',
          icon: Icons.trending_up_outlined,
        ),
        SidebarItem(
          id: 'payroll',
          label: 'Payroll',
          icon: Icons.credit_card_outlined,
        ),
        SidebarItem(
          id: 'attendance',
          label: 'Attendance',
          icon: Icons.calendar_today_outlined,
        ),
        SidebarItem(
          id: 'meetings',
          label: 'Meetings',
          icon: Icons.event_outlined,
        ),
        SidebarItem(
          id: 'leaves',
          label: 'Leave Management',
          icon: Icons.assignment_turned_in_outlined,
          badge: '3',
          badgeColor: 'amber',
        ),
        // SidebarItem(
        //   id: 'company-letters',
        //   label: 'Company Letter',
        //   icon: Icons.description_outlined,
        // ),
      ],
    ),
    // Reports & Documents
    SidebarSection(
      title: 'Reports & Documents',
      items: [
        SidebarItem(
          id: 'reports',
          label: 'Reports',
          icon: Icons.description_outlined,
        ),
        SidebarItem(
          id: 'documents',
          label: 'Documents',
          icon: Icons.folder_outlined,
        ),
      ],
    ),
    // System
    SidebarSection(
      title: 'System',
      items: [
        SidebarItem(
          id: 'settings',
          label: 'Settings',
          icon: Icons.settings_outlined,
        ),
        SidebarItem(id: 'help', label: 'Help Center', icon: Icons.help_outline),
      ],
    ),
  ];

  // Employee Navigation Items (dynamically includes Team Reports for leads)
  static List<NavigationElement> getEmployeeNavigation({bool isLead = false}) {
    return [
      SidebarSection(
        title: 'Employee Self-Service',
        items: [
          const SidebarItem(
            id: 'employee-dashboard',
            label: 'My Dashboard',
            icon: Icons.home_outlined,
          ),
          const SidebarItem(
            id: 'employee-goals',
            label: 'My Goals',
            icon: Icons.flag_outlined,
          ),
          const SidebarItem(
            id: 'submit-report',
            label: 'Submit Report',
            icon: Icons.assignment_outlined,
          ),
          if (isLead)
            const SidebarItem(
              id: 'team-reports',
              label: 'Team Reports',
              icon: Icons.group_outlined,
            ),
          const SidebarItem(
            id: 'my-letters',
            label: 'My Letters',
            icon: Icons.description_outlined,
          ),
          if (isLead)
            const SidebarItem(
              id: 'lead-leave-approvals',
              label: 'Leave Approvals',
              icon: Icons.fact_check_outlined,
            ),
          const SidebarItem(
            id: 'my-profile',
            label: 'My Profile',
            icon: Icons.person_outline,
          ),

          const SidebarItem(
            id: 'my-meetings',
            label: 'My Meetings',
            icon: Icons.event_outlined,
          ),
          const SidebarItem(
            id: 'my-performance',
            label: 'My Performance',
            icon: Icons.bar_chart,
          ),
          const SidebarItem(
            id: 'attendance-clock',
            label: 'My Attendance',
            icon: Icons.schedule_outlined,
          ),
          const SidebarItem(
            id: 'my-payslips',
            label: 'My Payslips',
            icon: Icons.credit_card_outlined,
          ),
          // const SidebarItem(
          //   id: 'my-letters',
          //   label: 'My Letters',
          //   icon: Icons.description_outlined,
          // ),
        ],
      ),
      const SidebarSection(
        title: 'System',
        items: [
          SidebarItem(
            id: 'settings',
            label: 'Settings',
            icon: Icons.settings_outlined,
          ),
          SidebarItem(
            id: 'help',
            label: 'Help Center',
            icon: Icons.help_outline,
          ),
        ],
      ),
    ];
  }

  // Get navigation based on role
  static List<NavigationElement> getNavigationForRole(String role) {
    if (role == 'hr' || role == 'admin') {
      return hrNavigation;
    } else {
      final isLead = role.toLowerCase().contains('project lead');
      return getEmployeeNavigation(isLead: isLead);
    }
  }
}
