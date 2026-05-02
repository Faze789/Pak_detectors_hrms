import 'package:flutter/material.dart';
import '../models/meeting_model.dart';

// ─── Color & Config Helpers ──────────────────────────────────────────

class MeetingTheme {
  static Color statusColor(MeetingStatus status) {
    switch (status) {
      case MeetingStatus.approved: return const Color(0xFF10B981);
      case MeetingStatus.pending:  return const Color(0xFFF59E0B);
      case MeetingStatus.rejected: return const Color(0xFFEF4444);
      case MeetingStatus.completed: return const Color(0xFF3B82F6);
      case MeetingStatus.cancelled: return const Color(0xFF94A3B8);
    }
  }

  static Color statusBg(MeetingStatus status) {
    switch (status) {
      case MeetingStatus.approved:  return const Color(0xFFECFDF5);
      case MeetingStatus.pending:   return const Color(0xFFFFFBEB);
      case MeetingStatus.rejected:  return const Color(0xFFFEF2F2);
      case MeetingStatus.completed: return const Color(0xFFEFF6FF);
      case MeetingStatus.cancelled: return const Color(0xFFF1F5F9);
    }
  }

  static String statusLabel(MeetingStatus status) {
    switch (status) {
      case MeetingStatus.approved:  return 'Approved';
      case MeetingStatus.pending:   return 'Pending';
      case MeetingStatus.rejected:  return 'Rejected';
      case MeetingStatus.completed: return 'Completed';
      case MeetingStatus.cancelled: return 'Cancelled';
    }
  }

  static IconData statusIcon(MeetingStatus status) {
    switch (status) {
      case MeetingStatus.approved:  return Icons.check_circle_rounded;
      case MeetingStatus.pending:   return Icons.schedule_rounded;
      case MeetingStatus.rejected:  return Icons.cancel_rounded;
      case MeetingStatus.completed: return Icons.task_alt_rounded;
      case MeetingStatus.cancelled: return Icons.event_busy_rounded;
    }
  }

  static String typeLabel(MeetingType type) {
    switch (type) {
      case MeetingType.general:   return 'Meeting';
      case MeetingType.review:    return 'Review';
      case MeetingType.training:  return 'Training';
      case MeetingType.oneOnOne:  return '1-on-1';
      case MeetingType.event:     return 'Event';
    }
  }

  static IconData typeIcon(MeetingType type) {
    switch (type) {
      case MeetingType.general:   return Icons.groups_rounded;
      case MeetingType.review:    return Icons.rate_review_rounded;
      case MeetingType.training:  return Icons.school_rounded;
      case MeetingType.oneOnOne:  return Icons.people_rounded;
      case MeetingType.event:     return Icons.celebration_rounded;
    }
  }

  static String formatDateTime(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const weekdays = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final wd = weekdays[dt.weekday - 1];
    final m = months[dt.month - 1];
    final t = '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    return '$wd, $m ${dt.day} · $t';
  }

  static String formatDateOnly(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  static String formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ─── Shared Widgets ──────────────────────────────────────────────────

class MeetingStatusBadge extends StatelessWidget {
  final MeetingStatus status;
  const MeetingStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: MeetingTheme.statusBg(status),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MeetingTheme.statusColor(status).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              color: MeetingTheme.statusColor(status),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            MeetingTheme.statusLabel(status),
            style: TextStyle(
              color: MeetingTheme.statusColor(status),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class MeetingTypeBadge extends StatelessWidget {
  final MeetingType type;
  const MeetingTypeBadge({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(MeetingTheme.typeIcon(type), size: 12, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            MeetingTheme.typeLabel(type),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class DateBox extends StatelessWidget {
  final DateTime dateTime;
  final Color color;
  const DateBox({super.key, required this.dateTime, required this.color});

  @override
  Widget build(BuildContext context) {
    const months = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];
    const weekdays = ['MON','TUE','WED','THU','FRI','SAT','SUN'];
    return Container(
      width: 60, height: 70,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0,3))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(months[dateTime.month - 1], style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1)),
          Text('${dateTime.day}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, height: 1.1)),
          Text(weekdays[dateTime.weekday - 1], style: const TextStyle(color: Colors.white70, fontSize: 9, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

class MeetingInfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  const MeetingInfoRow({super.key, required this.icon, required this.iconColor, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(), style: TextStyle(fontSize: 10, color: Colors.grey.shade500, letterSpacing: 0.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
            ],
          ),
        ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;
  const SectionHeader({super.key, required this.title, this.trailing, this.onTrailingTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        if (trailing != null)
          GestureDetector(
            onTap: onTrailingTap,
            child: Text(trailing!, style: const TextStyle(fontSize: 13, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color color;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.color = const Color(0xFF3B82F6),
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: color.withOpacity(0.5)),
            ),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey.shade500, height: 1.4)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Meeting Card (used in grid/list views) ──────────────────────────

class MeetingCard extends StatelessWidget {
  final MeetingModel meeting;
  final VoidCallback? onTap;

  const MeetingCard({super.key, required this.meeting, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0,2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top colored bar
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: MeetingTheme.statusColor(meeting.status),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: MeetingStatusBadge(status: meeting.status),
                      ),
                      MeetingTypeBadge(type: meeting.type),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    meeting.title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B), height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF3B82F6)),
                            const SizedBox(width: 4),
                            Text(MeetingTheme.formatDateOnly(meeting.dateTime),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF3B82F6))),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(6)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF7C3AED)),
                            const SizedBox(width: 4),
                            Text(
                              '${meeting.dateTime.hour.toString().padLeft(2,'0')}:${meeting.dateTime.minute.toString().padLeft(2,'0')}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF7C3AED)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, thickness: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        meeting.format == MeetingFormat.virtual ? Icons.videocam_rounded : Icons.location_on_rounded,
                        size: 14,
                        color: meeting.format == MeetingFormat.virtual ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          meeting.location.isEmpty ? 'Not specified' : meeting.location,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.people_rounded, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          meeting.isAllEmployees ? 'All Employees' : meeting.attendeeNames.join(', '),
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}