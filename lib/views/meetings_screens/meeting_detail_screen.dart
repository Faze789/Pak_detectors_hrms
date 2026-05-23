// meeting_detail_screen.dart
import 'package:flutter/material.dart';

import '../../models/meeting_model.dart';
import '../../services/meeting_service.dart';
import '../../widgets/meeting_widgets.dart';

class MeetingDetailScreen extends StatefulWidget {
  final MeetingModel meeting;
  final bool isHR;
  final String currentUserId;

  const MeetingDetailScreen({
    super.key,
    required this.meeting,
    required this.isHR,
    required this.currentUserId,
  });

  @override
  State<MeetingDetailScreen> createState() => _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends State<MeetingDetailScreen> {
  final _service = MeetingService();
  late MeetingModel meeting;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    meeting = widget.meeting;
  }

  Future<void> _cancelMeeting() async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Cancel Meeting?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cancelling: "${meeting.title}". All attendees will be notified.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Reason for cancellation',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Meeting'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Meeting'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final reason = reasonCtrl.text.trim();
    if (reason.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a cancellation reason'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final allUsers = await _service.getAllUsers();
      await _service.cancelMeeting(
        meeting: meeting,
        reason: reason,
        allUsers: allUsers,
      );
      if (!mounted) return;
      setState(() {
        meeting = meeting.copyWith(
          status: MeetingStatus.cancelled,
          cancelledAt: DateTime.now(),
          cancellationReason: reason,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meeting cancelled. All attendees notified.'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addOrEditConclusion() async {
    final ctrl = TextEditingController(text: meeting.conclusion ?? '');
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          meeting.conclusion == null
              ? 'Add Meeting Summary'
              : 'Edit Meeting Summary',
        ),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: ctrl,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: 'Key decisions, action items, follow-ups…',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save Summary'),
          ),
        ],
      ),
    );
    if (saved == null || saved.isEmpty) return;

    setState(() => _busy = true);
    try {
      final allUsers = await _service.getAllUsers();
      await _service.setMeetingConclusion(
        meeting: meeting,
        conclusion: saved,
        allUsers: allUsers,
      );
      if (!mounted) return;
      setState(() {
        meeting = meeting.copyWith(
          conclusion: saved,
          status: meeting.status == MeetingStatus.cancelled
              ? meeting.status
              : MeetingStatus.completed,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Summary saved & shared with attendees'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = MeetingTheme.statusColor(meeting.status);
    final canCancel = widget.isHR && meeting.status == MeetingStatus.approved;
    final canAddConclusion =
        widget.isHR &&
        (meeting.status == MeetingStatus.approved ||
            meeting.status == MeetingStatus.completed);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: statusColor,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [statusColor, statusColor.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MeetingStatusBadge(status: meeting.status),
                        const SizedBox(height: 10),
                        Text(
                          meeting.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        DateBox(dateTime: meeting.dateTime, color: statusColor),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                MeetingTheme.formatDateTime(meeting.dateTime),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.timer_outlined,
                                    size: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Duration: ${meeting.duration}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              MeetingTypeBadge(type: meeting.type),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Meeting Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 14),
                        MeetingInfoRow(
                          icon: meeting.format == MeetingFormat.virtual
                              ? Icons.videocam_rounded
                              : Icons.location_on_rounded,
                          iconColor: meeting.format == MeetingFormat.virtual
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFF10B981),
                          label: meeting.format == MeetingFormat.virtual
                              ? 'Virtual Link'
                              : 'Location',
                          value: meeting.location.isEmpty
                              ? 'Not specified'
                              : meeting.location,
                        ),
                        const Divider(height: 20),
                        MeetingInfoRow(
                          icon: Icons.person_rounded,
                          iconColor: const Color(0xFF7C3AED),
                          label: 'Organized By',
                          value: meeting.organizerName,
                        ),
                        const Divider(height: 20),
                        MeetingInfoRow(
                          icon: Icons.people_rounded,
                          iconColor: const Color(0xFF3B82F6),
                          label: 'Attendees',
                          value: meeting.isAllEmployees
                              ? 'All Employees'
                              : meeting.attendeeNames.join(', '),
                        ),
                      ],
                    ),
                  ),

                  if (meeting.description.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _infoCard(
                      title: 'Agenda / Description',
                      body: meeting.description,
                    ),
                  ],

                  if (meeting.status == MeetingStatus.rejected &&
                      (meeting.rejectionReason ?? '').isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _statusCard(
                      icon: Icons.cancel_rounded,
                      title: 'Rejection Reason',
                      body: meeting.rejectionReason!,
                      bg: const Color(0xFFFEF2F2),
                      border: const Color(0xFFFECACA),
                      fg: const Color(0xFF991B1B),
                    ),
                  ],

                  if (meeting.status == MeetingStatus.cancelled &&
                      (meeting.cancellationReason ?? '').isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _statusCard(
                      icon: Icons.event_busy_rounded,
                      title: 'Meeting Cancelled',
                      body: meeting.cancellationReason!,
                      bg: const Color(0xFFFEF2F2),
                      border: const Color(0xFFFECACA),
                      fg: const Color(0xFF991B1B),
                    ),
                  ],

                  if ((meeting.conclusion ?? '').isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _statusCard(
                      icon: Icons.summarize_rounded,
                      title: 'Meeting Summary',
                      body: meeting.conclusion!,
                      bg: const Color(0xFFEFF6FF),
                      border: const Color(0xFFBFDBFE),
                      fg: const Color(0xFF1E40AF),
                    ),
                  ],

                  if (canCancel || canAddConclusion) ...[
                    const SizedBox(height: 24),
                    if (canCancel)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _cancelMeeting,
                          icon: _busy
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFDC2626),
                                  ),
                                )
                              : const Icon(
                                  Icons.event_busy_rounded,
                                  size: 18,
                                  color: Color(0xFFDC2626),
                                ),
                          label: const Text(
                            'Cancel Meeting',
                            style: TextStyle(
                              color: Color(0xFFDC2626),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: Color(0xFFDC2626)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    if (canCancel && canAddConclusion)
                      const SizedBox(height: 10),
                    if (canAddConclusion)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _busy ? null : _addOrEditConclusion,
                          icon: const Icon(
                            Icons.summarize_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          label: Text(
                            meeting.conclusion == null
                                ? 'Add Meeting Summary'
                                : 'Edit Summary',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({required String title, required String body}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusCard({
    required IconData icon,
    required String title,
    required String body,
    required Color bg,
    required Color border,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: fg),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(fontSize: 13, color: fg, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
