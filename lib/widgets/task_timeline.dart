import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Reusable chronological timeline for a v2 task.
///
/// Subscribe to either [TaskService.streamEvents] (HR / lead full chain) or
/// [TaskService.streamEventsForMember] (member-only filter) and pass the
/// resulting stream in. Events are grouped under "Task" (no `weekNumber`)
/// and "Week N" sections, with role-coloured chips and tappable attachment
/// chips.
class TaskTimeline extends StatefulWidget {
  const TaskTimeline({
    super.key,
    required this.eventsStream,
    this.highlightedEventId,
    this.totalWeeks,
  });

  final Stream<List<Map<String, dynamic>>> eventsStream;

  /// If non-null and present in the stream, the matching event is rendered
  /// with a highlighted border and is auto-scrolled into view on first build.
  final String? highlightedEventId;

  /// Optional — when provided, empty week sections render a "no events yet"
  /// placeholder so the lead/HR can see which weeks have nothing logged.
  final int? totalWeeks;

  @override
  State<TaskTimeline> createState() => _TaskTimelineState();
}

class _TaskTimelineState extends State<TaskTimeline> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _highlightKey = GlobalKey();
  bool _scrolledOnce = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _maybeScrollToHighlight() {
    if (_scrolledOnce || widget.highlightedEventId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _highlightKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 350),
          alignment: 0.2,
        );
        _scrolledOnce = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: widget.eventsStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final events = snap.data ?? const <Map<String, dynamic>>[];
        if (events.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text(
                'No timeline events yet.',
                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              ),
            ),
          );
        }

        // Group: -1 sentinel for task-level (no weekNumber).
        final groups = <int, List<Map<String, dynamic>>>{};
        for (final e in events) {
          final w = e['weekNumber'] as int? ?? -1;
          groups.putIfAbsent(w, () => []).add(e);
        }
        final keys = groups.keys.toList()
          ..sort((a, b) {
            // Task-level first, then weeks ascending
            if (a == -1 && b != -1) return -1;
            if (b == -1 && a != -1) return 1;
            return a.compareTo(b);
          });

        // If totalWeeks supplied, ensure each week 1..N appears
        if (widget.totalWeeks != null) {
          for (int w = 1; w <= widget.totalWeeks!; w++) {
            groups.putIfAbsent(w, () => []);
            if (!keys.contains(w)) keys.add(w);
          }
          keys.sort((a, b) {
            if (a == -1 && b != -1) return -1;
            if (b == -1 && a != -1) return 1;
            return a.compareTo(b);
          });
        }

        _maybeScrollToHighlight();

        return ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: keys.length,
          itemBuilder: (_, i) {
            final w = keys[i];
            final list = groups[w] ?? const <Map<String, dynamic>>[];
            return _Section(
              title: w == -1 ? 'Task' : 'Week $w',
              events: list,
              highlightedEventId: widget.highlightedEventId,
              highlightKey: _highlightKey,
            );
          },
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.events,
    required this.highlightedEventId,
    required this.highlightKey,
  });

  final String title;
  final List<Map<String, dynamic>> events;
  final String? highlightedEventId;
  final GlobalKey highlightKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1D4ED8),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (events.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'No events yet.',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            )
          else
            ...events.map((e) {
              final id = (e['id'] ?? '').toString();
              final isHl = id.isNotEmpty && id == highlightedEventId;
              return _EventTile(
                event: e,
                highlighted: isHl,
                tileKey: isHl ? highlightKey : null,
              );
            }),
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.highlighted,
    this.tileKey,
  });

  final Map<String, dynamic> event;
  final bool highlighted;
  final Key? tileKey;

  @override
  Widget build(BuildContext context) {
    final type = (event['type'] ?? '').toString();
    final actor = (event['actorName'] ?? '').toString();
    final role = (event['actorRole'] ?? '').toString();
    final ts = event['createdAt'] as Timestamp?;
    final payload = event['payload'] as Map<String, dynamic>? ?? const {};
    final attachments =
        (event['attachments'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    return Container(
      key: tileKey,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlighted
              ? const Color(0xFF2563EB)
              : const Color(0xFFE2E8F0),
          width: highlighted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _roleChip(role),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _typeLabel(type),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              if (ts != null)
                Text(
                  _shortTs(ts.toDate()),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF94A3B8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            actor.isEmpty ? '—' : actor,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_subtitle(type, payload).isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _subtitle(type, payload),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF1E293B),
                height: 1.3,
              ),
            ),
          ],
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: attachments
                  .map(
                    (a) => GestureDetector(
                      onTap: () {
                        final url = (a['url'] ?? '').toString();
                        if (url.isNotEmpty) launchUrl(Uri.parse(url));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.picture_as_pdf,
                              size: 11,
                              color: Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 3),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 160),
                              child: Text(
                                (a['name'] ?? 'pdf').toString(),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1D4ED8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _roleChip(String role) {
    final (label, fg, bg) = switch (role.toLowerCase()) {
      'hr' => ('HR', Color(0xFF7C2D12), Color(0xFFFFEDD5)),
      'lead' => ('Lead', Color(0xFF1D4ED8), Color(0xFFDBEAFE)),
      'member' => ('Member', Color(0xFF065F46), Color(0xFFDCFCE7)),
      _ => (role.isEmpty ? '?' : role, Color(0xFF64748B), Color(0xFFE2E8F0)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }

  static String _typeLabel(String type) => switch (type) {
    'hr_create' => 'Task created',
    'hr_edit' => 'HR edited task',
    'hr_attach' => 'HR added attachments',
    'hr_accept' => 'HR accepted submission',
    'hr_reject' => 'HR rejected submission',
    'lead_accept_as_is' => 'Lead accepted as-is',
    'lead_edit_and_accept' => 'Lead edited & accepted',
    'lead_team_change' => 'Lead changed team',
    'lead_breakdown' => 'Lead set week instruction',
    'lead_breakdown_edit' => 'Lead edited week instruction',
    'lead_accept_member' => 'Lead accepted submission',
    'lead_reject_member' => 'Lead rejected submission',
    'lead_submit_to_hr' => 'Lead submitted to HR',
    'lead_activate_week' => 'Lead activated next week',
    'member_submit' => 'Member submitted work',
    'member_resubmit' => 'Member resubmitted',
    'member_barrier' => 'Barrier raised',
    _ => type,
  };

  static String _subtitle(String type, Map<String, dynamic> payload) {
    switch (type) {
      case 'hr_create':
        return [
          if ((payload['title'] ?? '').toString().isNotEmpty)
            '"${payload['title']}"',
          if ((payload['totalWeeks'] ?? 0) is int)
            '${payload['totalWeeks']} week${payload['totalWeeks'] == 1 ? '' : 's'}',
          if ((payload['memberCount'] ?? 0) > 0)
            '${payload['memberCount']} members',
        ].join(' · ');
      case 'lead_breakdown':
        return (payload['instruction'] ?? '').toString();
      case 'lead_reject_member':
        final r = (payload['rejectReason'] ?? '').toString();
        return r.isEmpty ? '' : 'Reason: $r';
      case 'member_submit':
      case 'member_resubmit':
        final t = (payload['text'] ?? '').toString();
        return t.length > 240 ? '${t.substring(0, 240)}…' : t;
      case 'member_barrier':
        return 'Reason: ${payload['reason'] ?? ''}';
      case 'lead_team_change':
        return 'Members: ${payload['previousCount'] ?? '?'} → ${payload['newCount'] ?? '?'}';
      case 'lead_edit_and_accept':
        return [
          if ((payload['title'] ?? '').toString().isNotEmpty)
            'Title: "${payload['title']}"',
          if ((payload['attachmentCount'] ?? 0) > 0)
            '${payload['attachmentCount']} attachments',
        ].join(' · ');
      case 'lead_submit_to_hr':
        final s = (payload['summary'] ?? '').toString();
        return s.isEmpty ? '' : 'Summary: $s';
      case 'lead_activate_week':
        final prev = payload['previousWeek'];
        return prev == null
            ? ''
            : 'Closed Week $prev and started this week early.';
      default:
        return '';
    }
  }

  static String _shortTs(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
