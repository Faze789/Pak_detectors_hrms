import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/meeting_model.dart';
import '../../services/meeting_service.dart';
import '../../widgets/meeting_form_sheet.dart';
import '../../widgets/meeting_widgets.dart'
    show
        MeetingTheme,
        MeetingCard,
        EmptyState,
        DateBox,
        MeetingTypeBadge,
        MeetingInfoRow;
import 'meeting_detail_screen.dart';
import 'notification_screen.dart';

class HRMeetingsScreen extends StatefulWidget {
  final String hrUserId;
  final String hrUserName;

  const HRMeetingsScreen({
    super.key,
    required this.hrUserId,
    required this.hrUserName,
  });

  @override
  State<HRMeetingsScreen> createState() => _HRMeetingsScreenState();
}

class _HRMeetingsScreenState extends State<HRMeetingsScreen>
    with SingleTickerProviderStateMixin {
  final _service = MeetingService();
  late final TabController _tabController;
  String _searchQuery = '';
  String _filterStatus = 'All';
  final String _filterType = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // DEBUG - delete after fixing
    FirebaseFirestore.instance.collection('meetings').get().then((snap) {
      print('=== ALL MEETINGS: ${snap.size} ===');
      for (final doc in snap.docs) {
        print('  status="${doc['status']}"  title="${doc['title']}"');
      }
    });

    FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: widget.hrUserId)
        .get()
        .then((snap) {
          print('=== NOTIFICATIONS for ${widget.hrUserId}: ${snap.size} ===');
          for (final doc in snap.docs) {
            print('  isRead=${doc['isRead']}  title="${doc['title']}"');
          }
        });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<MeetingModel> _applyFilters(List<MeetingModel> meetings) {
    return meetings.where((m) {
      final matchSearch =
          _searchQuery.isEmpty ||
          m.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.organizerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.attendeeNames
              .join(' ')
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());
      final matchStatus =
          _filterStatus == 'All' ||
          m.status.name == _filterStatus.toLowerCase();
      final matchType =
          _filterType == 'All' || MeetingTheme.typeLabel(m.type) == _filterType;
      return matchSearch && matchStatus && matchType;
    }).toList();
  }

  Future<void> _showRejectDialog(
    MeetingModel meeting,
    List<UserModel> allUsers,
  ) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Meeting Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rejecting: "${meeting.title}"',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Reason for rejection (optional)',
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
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _service.rejectMeeting(
        meeting: meeting,
        reason: reasonCtrl.text.trim(),
        allUsers: allUsers,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meeting request rejected'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxScrolled) => [
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF1D4ED8),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Meeting Management',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'HR Dashboard',
                        style: TextStyle(fontSize: 11, color: Colors.white60),
                      ),
                    ],
                  ),
                  // Notification bell
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: StreamBuilder<int>(
                      stream: _service.streamUnreadCount(widget.hrUserId),
                      builder: (context, snap) {
                        final count = snap.data ?? 0;
                        return GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  NotificationsScreen(userId: widget.hrUserId),
                            ),
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.notifications_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              if (count > 0)
                                Positioned(
                                  top: -4, // ✅ was 0
                                  right: -4, // ✅ was 0

                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFEF4444),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '$count',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFF1D4ED8),
                  unselectedLabelColor: Colors.grey.shade500,
                  indicatorColor: const Color(0xFF1D4ED8),
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  tabs: [
                    const Tab(text: 'All Meetings'),
                    StreamBuilder<List<MeetingModel>>(
                      stream: _service.streamPendingMeetings(),
                      builder: (context, snap) {
                        final count = snap.data?.length ?? 0;
                        return Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Pending'),
                              if (count > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$count',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [_buildAllMeetingsTab(), _buildPendingTab()],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => MeetingFormSheet(
            currentUserId: widget.hrUserId,
            currentUserName: widget.hrUserName,
            isHR: true,
          ),
        ),
        backgroundColor: const Color(0xFF1D4ED8),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Schedule',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildAllMeetingsTab() {
    return Column(
      children: [
        // Stats bar
        StreamBuilder<List<MeetingModel>>(
          stream: _service.streamAllMeetings(),
          builder: (context, snap) {
            final meetings = snap.data ?? [];
            return _buildStatsRow(meetings);
          },
        ),
        // Filters
        _buildFiltersBar(),
        // List
        Expanded(
          child: StreamBuilder<List<MeetingModel>>(
            stream: _service.streamAllMeetings(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final filtered = _applyFilters(snap.data ?? []);
              if (filtered.isEmpty) {
                return EmptyState(
                  icon: Icons.calendar_month_rounded,
                  title: 'No meetings found',
                  subtitle:
                      'Try adjusting your filters or schedule a new meeting',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                itemBuilder: (_, i) => MeetingCard(
                  meeting: filtered[i],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MeetingDetailScreen(
                        meeting: filtered[i],
                        isHR: true,
                        currentUserId: widget.hrUserId,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPendingTab() {
    return StreamBuilder<List<MeetingModel>>(
      stream: _service.streamPendingMeetings(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final pending = snap.data ?? [];
        if (pending.isEmpty) {
          return EmptyState(
            icon: Icons.check_circle_rounded,
            title: 'All caught up!',
            subtitle: 'No pending meeting requests at the moment',
            color: const Color(0xFF10B981),
          );
        }
        return FutureBuilder<List<UserModel>>(
          future: _service.getAllUsers(),
          builder: (context, userSnap) {
            final allUsers = userSnap.data ?? [];
            return Column(
              children: [
                // Banner
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.pending_actions_rounded,
                        color: Color(0xFFF59E0B),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${pending.length} request${pending.length == 1 ? '' : 's'} awaiting your decision',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: pending.length,
                    itemBuilder: (_, i) =>
                        _buildPendingCard(pending[i], allUsers),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPendingCard(MeetingModel meeting, List<UserModel> allUsers) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(color: Color(0xFFF59E0B), width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DateBox(
                  dateTime: meeting.dateTime,
                  color: const Color(0xFF3B82F6),
                ),
                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meeting.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          MeetingTypeBadge(type: meeting.type),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFFCD34D),
                              ),
                            ),
                            child: const Text(
                              'Pending',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFFF59E0B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ✅ FORCE VISIBLE DELETE BUTTON
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Meeting'),
                            content: const Text(
                              'Are you sure you want to delete this meeting?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          // await _service.deleteMeeting(meeting.id);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            MeetingInfoRow(
              icon: Icons.access_time_rounded,
              iconColor: const Color(0xFF7C3AED),
              label: 'Time',
              value:
                  '${meeting.dateTime.hour.toString().padLeft(2, '0')}:${meeting.dateTime.minute.toString().padLeft(2, '0')} (${meeting.duration})',
            ),
            const SizedBox(height: 8),
            MeetingInfoRow(
              icon: Icons.person_rounded,
              iconColor: const Color(0xFF3B82F6),
              label: 'Requested by',
              value: meeting.organizerName,
            ),
            const SizedBox(height: 8),
            MeetingInfoRow(
              icon: Icons.people_rounded,
              iconColor: const Color(0xFF10B981),
              label: 'Attendees',
              value: meeting.isAllEmployees
                  ? 'All Employees'
                  : meeting.attendeeNames.join(', '),
            ),
            if (meeting.location.isNotEmpty) ...[
              const SizedBox(height: 8),
              MeetingInfoRow(
                icon: meeting.format == MeetingFormat.virtual
                    ? Icons.videocam_rounded
                    : Icons.location_on_rounded,
                iconColor: const Color(0xFFF59E0B),
                label: 'Location',
                value: meeting.location,
              ),
            ],
            if (meeting.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AGENDA',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meeting.description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRejectDialog(meeting, allUsers),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Color(0xFFEF4444),
                    ),
                    label: const Text(
                      'Reject',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await _service.approveMeeting(
                        meeting: meeting,
                        allUsers: allUsers,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Meeting approved!'),
                            backgroundColor: Color(0xFF10B981),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text(
                      'Approve',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(List<MeetingModel> meetings) {
    final approved = meetings
        .where((m) => m.status == MeetingStatus.approved)
        .length;
    final pending = meetings
        .where((m) => m.status == MeetingStatus.pending)
        .length;
    final completed = meetings
        .where((m) => m.status == MeetingStatus.completed)
        .length;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _statChip(
            'Total',
            meetings.length.toString(),
            const Color(0xFF3B82F6),
            Icons.calendar_month_rounded,
          ),
          const SizedBox(width: 8),
          _statChip(
            'Approved',
            approved.toString(),
            const Color(0xFF10B981),
            Icons.check_circle_rounded,
          ),
          const SizedBox(width: 8),
          _statChip(
            'Pending',
            pending.toString(),
            const Color(0xFFF59E0B),
            Icons.schedule_rounded,
          ),
          const SizedBox(width: 8),
          _statChip(
            'Done',
            completed.toString(),
            const Color(0xFF6366F1),
            Icons.task_alt_rounded,
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search meetings...',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Colors.grey,
                      size: 20,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _filterDropdown(
                value: _filterStatus,
                items: ['All', 'Approved', 'Pending', 'Rejected', 'Completed'],
                onChanged: (v) => setState(() => _filterStatus = v!),
                hint: 'Status',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterDropdown({
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
    required String hint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
        color: Colors.grey.shade50,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
          items: items
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
        ),
      ),
    );
  }
}
