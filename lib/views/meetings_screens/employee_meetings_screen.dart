import 'package:flutter/material.dart';

import '../../models/meeting_model.dart';
import '../../services/meeting_service.dart';
import '../../widgets/meeting_form_sheet.dart';
import '../../widgets/meeting_widgets.dart';
import 'meeting_detail_screen.dart';
import 'notification_screen.dart';


class EmployeeMeetingsScreen extends StatefulWidget {
  final String employeeId;
  final String employeeName;

  const EmployeeMeetingsScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
  });

  @override
  State<EmployeeMeetingsScreen> createState() => _EmployeeMeetingsScreenState();
}

class _EmployeeMeetingsScreenState extends State<EmployeeMeetingsScreen>
    with SingleTickerProviderStateMixin {
  final _service = MeetingService();
  late final TabController _tabController;
  String _searchQuery = '';
  String _filterStatus = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<List<MeetingModel>> get _myMeetingsStream {
    // Combines both meetings where user is attendee AND meetings they organized
    return _service.streamEmployeeMeetings(widget.employeeId);
  }

  List<MeetingModel> _applyFilters(List<MeetingModel> meetings) {
    return meetings.where((m) {
      final matchSearch = _searchQuery.isEmpty ||
          m.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.organizerName.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchStatus = _filterStatus == 'All' || m.status.name == _filterStatus.toLowerCase();
      return matchSearch && matchStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxScrolled) => [
          SliverAppBar(
            expandedHeight: 160,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF7C3AED),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Hello, ${widget.employeeName.split(' ').first}! 👋',
                                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                const Text('My Meetings', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            // Notification bell
                            StreamBuilder<int>(
                              stream: _service.streamUnreadCount(widget.employeeId),
                              builder: (context, snap) {
                                final count = snap.data ?? 0;
                                return GestureDetector(
                                  onTap: () => Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => NotificationsScreen(userId: widget.employeeId),
                                  )),
                                  child: Stack(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.notifications_rounded, color: Colors.white, size: 22),
                                      ),
                                      if (count > 0)
                                        Positioned(
                                          top: 0, right: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                                            child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Quick stats
                        StreamBuilder<List<MeetingModel>>(
                          stream: _myMeetingsStream,
                          builder: (context, snap) {
                            final meetings = snap.data ?? [];
                            final upcoming = meetings.where((m) => m.dateTime.isAfter(DateTime.now()) && m.status == MeetingStatus.approved).length;
                            final pending = meetings.where((m) => m.status == MeetingStatus.pending).length;
                            return Row(
                              children: [
                                _quickStat('${meetings.length}', 'Total'),
                                const SizedBox(width: 10),
                                _quickStat('$upcoming', 'Upcoming'),
                                const SizedBox(width: 10),
                                _quickStat('$pending', 'Pending'),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
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
                  labelColor: const Color(0xFF7C3AED),
                  unselectedLabelColor: Colors.grey.shade500,
                  indicatorColor: const Color(0xFF7C3AED),
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  tabs: [
                    const Tab(text: 'All'),
                    StreamBuilder<List<MeetingModel>>(
                      stream: _myMeetingsStream,
                      builder: (context, snap) {
                        final count = snap.data?.where((m) => m.dateTime.isAfter(DateTime.now()) && m.status == MeetingStatus.approved).length ?? 0;
                        return Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Upcoming'),
                              if (count > 0) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(10)),
                                  child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                    StreamBuilder<List<MeetingModel>>(
                      stream: _myMeetingsStream,
                      builder: (context, snap) {
                        final count = snap.data?.where((m) => m.status == MeetingStatus.pending && m.organizerId == widget.employeeId).length ?? 0;
                        return Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('My Requests'),
                              if (count > 0) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(10)),
                                  child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
          children: [
            _buildAllTab(),
            _buildUpcomingTab(),
            _buildMyRequestsTab(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => MeetingFormSheet(
            currentUserId: widget.employeeId,
            currentUserName: widget.employeeName,
            isHR: false,
          ),
        ),
        backgroundColor: const Color(0xFF7C3AED),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Request Meeting', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildAllTab() {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: StreamBuilder<List<MeetingModel>>(
            stream: _myMeetingsStream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final filtered = _applyFilters(snap.data ?? []);
              if (filtered.isEmpty) {
                return EmptyState(
                  icon: Icons.calendar_month_rounded,
                  title: 'No meetings yet',
                  subtitle: 'Request a meeting or check back after HR schedules one',
                  actionLabel: 'Request a Meeting',
                  onAction: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => MeetingFormSheet(
                      currentUserId: widget.employeeId,
                      currentUserName: widget.employeeName,
                      isHR: false,
                    ),
                  ),
                  color: const Color(0xFF7C3AED),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                itemBuilder: (_, i) => MeetingCard(
                  meeting: filtered[i],
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => MeetingDetailScreen(
                      meeting: filtered[i],
                      isHR: false,
                      currentUserId: widget.employeeId,
                    ),
                  )),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingTab() {
    return StreamBuilder<List<MeetingModel>>(
      stream: _myMeetingsStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final upcoming = (snap.data ?? [])
            .where((m) => m.dateTime.isAfter(DateTime.now()) && m.status == MeetingStatus.approved)
            .toList()
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

        if (upcoming.isEmpty) {
          return const EmptyState(
            icon: Icons.event_available_rounded,
            title: 'No upcoming meetings',
            subtitle: 'You don\'t have any approved meetings scheduled. Check back later!',
            color: Color(0xFF10B981),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: upcoming.length,
          itemBuilder: (_, i) => _buildUpcomingCard(upcoming[i]),
        );
      },
    );
  }

  Widget _buildMyRequestsTab() {
    return StreamBuilder<List<MeetingModel>>(
      stream: _service.streamOrganizedMeetings(widget.employeeId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final requests = snap.data ?? [];
        if (requests.isEmpty) {
          return EmptyState(
            icon: Icons.send_rounded,
            title: 'No requests yet',
            subtitle: 'Submit a meeting request and track its status here',
            actionLabel: 'Request a Meeting',
            onAction: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => MeetingFormSheet(
                currentUserId: widget.employeeId,
                currentUserName: widget.employeeName,
                isHR: false,
              ),
            ),
            color: const Color(0xFF7C3AED),
          );
        }

        return Column(
          children: [
            // Pending info banner
            if (requests.any((m) => m.status == MeetingStatus.pending))
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_rounded, color: Color(0xFFF59E0B), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pending requests are being reviewed by HR. You\'ll be notified once approved.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(16, requests.any((m) => m.status == MeetingStatus.pending) ? 0 : 16, 16, 16),
                itemCount: requests.length,
                itemBuilder: (_, i) => _buildRequestCard(requests[i]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUpcomingCard(MeetingModel meeting) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: const Border(left: BorderSide(color: Color(0xFF10B981), width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0,2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            DateBox(dateTime: meeting.dateTime, color: const Color(0xFF10B981)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meeting.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        '${meeting.dateTime.hour.toString().padLeft(2,'0')}:${meeting.dateTime.minute.toString().padLeft(2,'0')} · ${meeting.duration}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        meeting.format == MeetingFormat.virtual ? Icons.videocam_rounded : Icons.location_on_rounded,
                        size: 13,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          meeting.location.isEmpty ? 'Location TBD' : meeting.location,
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
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(MeetingModel meeting) {
    final statusColor = MeetingTheme.statusColor(meeting.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0,2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(meeting.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              ),
              MeetingStatusBadge(status: meeting.status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(MeetingTheme.formatDateTime(meeting.dateTime), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.people_rounded, size: 12, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  meeting.attendeeNames.join(', '),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (meeting.status == MeetingStatus.rejected && meeting.rejectionReason != null && meeting.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_rounded, size: 14, color: Color(0xFFEF4444)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Reason: ${meeting.rejectionReason}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search my meetings...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(10),
              color: Colors.grey.shade50,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filterStatus,
                onChanged: (v) => setState(() => _filterStatus = v!),
                style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
                items: ['All', 'Approved', 'Pending', 'Rejected', 'Completed']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickStat(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}