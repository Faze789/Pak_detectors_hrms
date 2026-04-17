// meeting_detail_screen.dart
import 'package:flutter/material.dart';

import '../../models/meeting_model.dart';
import '../../widgets/meeting_widgets.dart';


class MeetingDetailScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final statusColor = MeetingTheme.statusColor(meeting.status);

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
                    colors: [statusColor, statusColor.withOpacity(0.7)],
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
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, height: 1.3),
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
                  // Date & Time card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
                    ),
                    child: Row(
                      children: [
                        DateBox(dateTime: meeting.dateTime, color: statusColor),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(MeetingTheme.formatDateTime(meeting.dateTime),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.timer_outlined, size: 14, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Text('Duration: ${meeting.duration}',
                                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
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

                  // Details card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Meeting Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                        const SizedBox(height: 14),
                        MeetingInfoRow(
                          icon: meeting.format == MeetingFormat.virtual ? Icons.videocam_rounded : Icons.location_on_rounded,
                          iconColor: meeting.format == MeetingFormat.virtual ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                          label: meeting.format == MeetingFormat.virtual ? 'Virtual Link' : 'Location',
                          value: meeting.location.isEmpty ? 'Not specified' : meeting.location,
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
                          value: meeting.isAllEmployees ? 'All Employees' : meeting.attendeeNames.join(', '),
                        ),
                      ],
                    ),
                  ),

                  if (meeting.description.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Agenda / Description', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                          const SizedBox(height: 10),
                          Text(meeting.description, style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5)),
                        ],
                      ),
                    ),
                  ],

                  if (meeting.status == MeetingStatus.rejected && meeting.rejectionReason != null && meeting.rejectionReason!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Rejection Reason', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF991B1B))),
                                const SizedBox(height: 4),
                                Text(meeting.rejectionReason!, style: const TextStyle(fontSize: 13, color: Color(0xFF991B1B))),
                              ],
                            ),
                          ),
                        ],
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
}