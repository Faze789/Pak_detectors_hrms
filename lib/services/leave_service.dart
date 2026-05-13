// lib/services/leave_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../models/leave_model.dart';
import 'notification_helpers/notification_helper_stub.dart';

class LeaveService {
  final FirebaseFirestore _db;
  final FirebaseMessaging _fcm;

  LeaveService({FirebaseFirestore? db, FirebaseMessaging? fcm})
    : _db = db ?? FirebaseFirestore.instance,
      _fcm = fcm ?? FirebaseMessaging.instance;

  CollectionReference<Map<String, dynamic>> get _leaves =>
      _db.collection('leaves');

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  // ── Save FCM token ────────────────────────────────────────────────────────

  Future<void> saveFcmToken(String userId) async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await _users.doc(userId).update({'fcmToken': token});
      }
    } catch (_) {}
  }

  // ── Find leads of a member ────────────────────────────────────────────────
  /// Returns the emp_ids of all unique leads of approved tasks where the
  /// member is in the `members` map. Used to fan out leave requests to
  /// every project lead this member reports into.
  Future<List<String>> findLeadsOfMember(String memberEmpId) async {
    if (memberEmpId.isEmpty) return [];
    final lower = memberEmpId.toLowerCase();
    final tasksSnap = await _db.collection('tasks').get();
    final leads = <String>{};
    for (final doc in tasksSnap.docs) {
      final data = doc.data();
      final members = data['members'] as Map<String, dynamic>? ?? {};
      bool isMember = false;
      for (final m in members.values) {
        if (m is Map &&
            (m['emp_id'] ?? '').toString().toLowerCase() == lower) {
          isMember = true;
          break;
        }
      }
      if (isMember) {
        final leadId = (data['lead_id'] ?? '').toString();
        if (leadId.isNotEmpty && leadId.toLowerCase() != lower) {
          leads.add(leadId);
        }
      }
    }
    return leads.toList();
  }

  /// Returns the emp_ids of every HR user. The leave-request router falls
  /// back to this set when the employee is not a project member (and not a
  /// lead either), so HR can approve/reject directly.
  Future<List<String>> findAllHrEmpIds() async {
    final snap = await _users.where('role', isEqualTo: 'hr').get();
    final out = <String>{};
    for (final d in snap.docs) {
      final data = d.data();
      final empId = (data['emp_id'] ?? '').toString();
      if (empId.isNotEmpty) out.add(empId);
    }
    return out.toList();
  }

  /// `true` if the user `empId` is the lead of any task (i.e. they manage a
  /// project). Used by the routing rule: employees who are themselves a
  /// lead-of-something do NOT fall back to HR — their own leave still goes
  /// to HR by default since they have no upper-level lead.
  Future<bool> isLeadOfAnyTask(String empId) async {
    if (empId.isEmpty) return false;
    final lower = empId.toLowerCase();
    final snap = await _db
        .collection('tasks')
        .where('lead_id', isEqualTo: empId)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) return true;
    // Fallback: some legacy tasks have lowercase lead_id. Scan one page.
    final all = await _db.collection('tasks').limit(50).get();
    for (final d in all.docs) {
      if ((d.data()['lead_id'] ?? '').toString().toLowerCase() == lower) {
        return true;
      }
    }
    return false;
  }

  // ── Submit leave ──────────────────────────────────────────────────────────

  Future<LeaveModel> submitLeave(LeaveModel leave) async {
    final docRef = _leaves.doc();

    // For half-day leaves, toDate must equal fromDate (same day only)
    final toDate = leave.duration.isHalfDay ? leave.fromDate : leave.toDate;

    // Recalculate deducted days based on duration
    final deductedDays = leave.duration == LeaveDuration.fullDay
        ? toDate.difference(leave.fromDate).inDays + 1.0
        : 0.5;

    // Routing per spec:
    //   * If the requester is a project member → the leads of those
    //     projects are the approvers.
    //   * Otherwise (no project membership, e.g. unassigned employees and
    //     leads themselves) → fall back to all HR users.
    // The chosen approver set lands in `requiredApproverEmpIds`; both
    // routes share the same `approvals[]` audit trail.
    final leadEmpIds = await findLeadsOfMember(leave.emp_id);
    final List<String> approverEmpIds;
    final String approverKind;
    if (leadEmpIds.isNotEmpty) {
      approverEmpIds = leadEmpIds;
      approverKind = 'lead';
    } else {
      approverEmpIds = await findAllHrEmpIds();
      approverKind = 'hr';
    }

    final model = LeaveModel(
      id: docRef.id,
      userId: leave.userId,
      employeeName: leave.employeeName,
      employeeRole: leave.employeeRole,
      emp_id: leave.emp_id,
      type: leave.type,
      duration: leave.duration,
      fromDate: leave.fromDate,
      toDate: toDate,
      days: toDate.difference(leave.fromDate).inDays + 1,
      deductedDays: deductedDays,
      reason: leave.reason,
      status: LeaveStatus.pending,
      submittedAt: DateTime.now(),
      requiredApproverEmpIds: approverEmpIds,
    );

    // Save the leave doc plus a top-level `approverKind` flag so the UI
    // can label the request ("Pending Lead Approval" vs "Pending HR
    // Approval") without recomputing routing.
    final saved = model.toMap();
    saved['approverKind'] = approverKind;
    saved['approvals'] = const <Map<String, dynamic>>[];
    await docRef.set(saved);

    // Audit row: record the initial submission as the first entry on the
    // `approvals[]` array so the history view reads naturally as a
    // chronological log of every decision touching this leave.
    await docRef.update({
      'approvals': FieldValue.arrayUnion([
        {
          'empId': leave.emp_id,
          'name': leave.employeeName,
          'action': 'submitted',
          'decidedAt': Timestamp.now(),
          if (leave.reason.isNotEmpty) 'note': leave.reason,
        },
      ]),
    });

    // Notify every approver (lead or HR) via the existing task_notifications
    // pipeline — that's what FCM + the in-app local notification listener
    // are wired to read.
    for (final approverEmpId in approverEmpIds) {
      await _db.collection('task_notifications').add({
        'lead_id': approverEmpId,
        'title': approverKind == 'hr'
            ? 'Leave Approval Needed (HR)'
            : 'Leave Approval Needed',
        'body':
            '${leave.employeeName} requested ${leave.type.label} '
            '(${leave.duration.label}). Tap to review.',
        'type': 'leave',
        'leaveId': docRef.id,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    }

    final durationLabel = leave.duration == LeaveDuration.fullDay
        ? '${model.days} day${model.days > 1 ? 's' : ''}'
        : leave.duration.label;

    await _notify(
      title: '📋 New Leave Request',
      body:
          '${leave.employeeName} requested ${leave.type.label} ($durationLabel)',
    );

    return model;
  }

  // ── Approve leave (HR path) ───────────────────────────────────────────────
  // Pass `hrEmpId` / `hrName` so the action lands on the shared
  // `approvals[]` audit array — same as the lead path. Old callers that
  // skip these still work; the approval is stamped with empty identity.

  Future<void> approveLeave(
    String leaveId,
    String employeeUserId, {
    String? note,
    String? hrEmpId,
    String? hrName,
  }) async {
    final entry = <String, dynamic>{
      'empId': hrEmpId ?? '',
      'name': hrName ?? 'HR',
      'role': 'hr',
      'action': 'approved',
      'decidedAt': Timestamp.now(),
      if (note != null && note.isNotEmpty) 'note': note,
    };
    await _leaves.doc(leaveId).update({
      'status': LeaveStatus.approved.value,
      if (note != null && note.isNotEmpty) 'hrNote': note,
      'approvals': FieldValue.arrayUnion([entry]),
    });
    // In-app + FCM notification to the requester via task_notifications.
    try {
      final leaveSnap = await _leaves.doc(leaveId).get();
      final reqEmpId =
          (leaveSnap.data()?['emp_id'] ?? '').toString();
      if (reqEmpId.isNotEmpty) {
        await _db.collection('task_notifications').add({
          'lead_id': reqEmpId,
          'title': 'Leave Approved',
          'body': note != null && note.isNotEmpty
              ? 'Your leave has been approved by HR. Note: $note'
              : 'Your leave request has been approved by HR.',
          'type': 'leave',
          'leaveId': leaveId,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
    } catch (_) {}
    await _notify(
      title: '✅ Leave Approved',
      body: note != null && note.isNotEmpty
          ? 'Your leave has been approved. Note: $note'
          : 'Your leave request has been approved by HR.',
    );
  }

  // ── Reject leave (HR path) ────────────────────────────────────────────────

  Future<void> rejectLeave(
    String leaveId,
    String employeeUserId, {
    String? note,
    String? hrEmpId,
    String? hrName,
  }) async {
    final entry = <String, dynamic>{
      'empId': hrEmpId ?? '',
      'name': hrName ?? 'HR',
      'role': 'hr',
      'action': 'rejected',
      'decidedAt': Timestamp.now(),
      if (note != null && note.isNotEmpty) 'note': note,
    };
    await _leaves.doc(leaveId).update({
      'status': LeaveStatus.rejected.value,
      if (note != null && note.isNotEmpty) 'hrNote': note,
      'approvals': FieldValue.arrayUnion([entry]),
    });
    try {
      final leaveSnap = await _leaves.doc(leaveId).get();
      final reqEmpId =
          (leaveSnap.data()?['emp_id'] ?? '').toString();
      if (reqEmpId.isNotEmpty) {
        await _db.collection('task_notifications').add({
          'lead_id': reqEmpId,
          'title': 'Leave Rejected',
          'body': note != null && note.isNotEmpty
              ? 'Your leave was rejected by HR. Reason: $note'
              : 'Your leave request has been rejected by HR.',
          'type': 'leave',
          'leaveId': leaveId,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
    } catch (_) {}
    await _notify(
      title: '❌ Leave Rejected',
      body: note != null && note.isNotEmpty
          ? 'Your leave was rejected: $note'
          : 'Your leave request has been rejected by HR.',
    );
  }

  // ── Cancel leave (employee can cancel their own pending leave) ────────────

  Future<void> cancelLeave(String leaveId) async {
    await _leaves.doc(leaveId).update({'status': LeaveStatus.cancelled.value});
  }

  // ── Multi-lead approval ───────────────────────────────────────────────────
  /// A lead approves their part of a leave. If all required leads have now
  /// approved, the leave's overall status flips to `approved`.
  Future<void> leadApproveLeave({
    required String leaveId,
    required String leadEmpId,
    required String leadName,
    String? note,
  }) async {
    await _db.runTransaction((tx) async {
      final ref = _leaves.doc(leaveId);
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data()!;
      final required = List<String>.from(
        (data['requiredApproverEmpIds'] as List?) ?? const [],
      );
      final approvals = List<Map<String, dynamic>>.from(
        ((data['approvals'] as List?) ?? const []).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );

      // Idempotent: skip if this lead already decided.
      final already = approvals.any(
        (a) => (a['empId'] ?? '').toString().toLowerCase() ==
            leadEmpId.toLowerCase(),
      );
      if (already) return;

      approvals.add({
        'empId': leadEmpId,
        'name': leadName,
        'role': 'lead',
        'action': 'approved',
        'decidedAt': Timestamp.now(),
        if (note != null && note.isNotEmpty) 'note': note,
      });

      // All required leads approved? → status approved.
      final approvedSet = approvals
          .where((a) => a['action'] == 'approved')
          .map((a) => (a['empId'] ?? '').toString().toLowerCase())
          .toSet();
      final allApproved = required
          .every((id) => approvedSet.contains(id.toLowerCase()));

      tx.update(ref, {
        'approvals': approvals,
        if (allApproved) 'status': LeaveStatus.approved.value,
      });
    });

    // Notify the requester via the standard task_notifications collection
    // so they get the same in-app + FCM pipeline as every other channel.
    try {
      final leaveSnap = await _leaves.doc(leaveId).get();
      final reqEmpId =
          (leaveSnap.data()?['emp_id'] ?? '').toString();
      if (reqEmpId.isNotEmpty) {
        await _db.collection('task_notifications').add({
          'lead_id': reqEmpId,
          'title': 'Leave Approved',
          'body': '$leadName approved your leave request.',
          'type': 'leave',
          'leaveId': leaveId,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
    } catch (_) {}
    await _notify(
      title: 'Leave update',
      body: 'A team lead approved your leave. Tap to view status.',
    );
  }

  /// A lead rejects their part of a leave. ANY rejection cancels the
  /// whole request — overall status goes to `rejected`.
  Future<void> leadRejectLeave({
    required String leaveId,
    required String leadEmpId,
    required String leadName,
    required String reason,
  }) async {
    await _db.runTransaction((tx) async {
      final ref = _leaves.doc(leaveId);
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final approvals = List<Map<String, dynamic>>.from(
        ((snap.data()!['approvals'] as List?) ?? const []).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );

      final already = approvals.any(
        (a) => (a['empId'] ?? '').toString().toLowerCase() ==
            leadEmpId.toLowerCase(),
      );
      if (already) return;

      approvals.add({
        'empId': leadEmpId,
        'name': leadName,
        'role': 'lead',
        'action': 'rejected',
        'decidedAt': Timestamp.now(),
        if (reason.isNotEmpty) 'note': reason,
      });

      tx.update(ref, {
        'approvals': approvals,
        'status': LeaveStatus.rejected.value,
        if (reason.isNotEmpty) 'hrNote': reason,
      });
    });

    try {
      final leaveSnap = await _leaves.doc(leaveId).get();
      final reqEmpId =
          (leaveSnap.data()?['emp_id'] ?? '').toString();
      if (reqEmpId.isNotEmpty) {
        await _db.collection('task_notifications').add({
          'lead_id': reqEmpId,
          'title': 'Leave Rejected',
          'body': reason.isNotEmpty
              ? '$leadName rejected your leave: $reason'
              : '$leadName rejected your leave request.',
          'type': 'leave',
          'leaveId': leaveId,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
    } catch (_) {}
    await _notify(
      title: 'Leave rejected',
      body: 'A lead rejected your leave request. Tap to view details.',
    );
  }

  /// Stream pending leaves where this lead's emp_id is in the required-approver
  /// list AND they haven't decided yet. Lead UI uses this to populate their
  /// "Leaves to Review" list.
  Stream<List<LeaveModel>> streamLeavesPendingForLead(String leadEmpId) {
    final lower = leadEmpId.toLowerCase();
    return _leaves
        .where('status', isEqualTo: LeaveStatus.pending.value)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => LeaveModel.fromMap(d.data(), id: d.id))
            .where((l) {
              final inRequired = l.requiredApproverEmpIds
                  .any((id) => id.toLowerCase() == lower);
              if (!inRequired) return false;
              final alreadyDecided = l.approvals.any(
                (a) =>
                    (a['empId'] ?? '').toString().toLowerCase() == lower,
              );
              return !alreadyDecided;
            })
            .toList());
  }

  // ── Streams ───────────────────────────────────────────────────────────────

  Stream<List<LeaveModel>> streamMyLeaves(String userId) {
    return _leaves
        .where('userId', isEqualTo: userId)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => LeaveModel.fromMap(d.data(), id: d.id))
              .toList(),
        );
  }

  Stream<List<LeaveModel>> streamPendingLeaves() {
    return _leaves
        .where('status', isEqualTo: LeaveStatus.pending.value)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => LeaveModel.fromMap(d.data(), id: d.id))
              .toList(),
        );
  }

  Stream<List<LeaveModel>> streamAllLeaves() {
    return _leaves
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => LeaveModel.fromMap(d.data(), id: d.id))
              .toList(),
        );
  }

  Future<List<LeaveModel>> getAllLeaves() async {
    final snap = await _leaves.orderBy('submittedAt', descending: true).get();
    return snap.docs
        .map((d) => LeaveModel.fromMap(d.data(), id: d.id))
        .toList();
  }

  // ── Fetch approved leaves for a specific employee on a given date ─────────
  // Used by attendance service to check if employee is on leave today.

  Future<LeaveModel?> getApprovedLeaveForDate({
    required String userId,
    required DateTime date,
  }) async {
    final dayStart = DateTime(date.year, date.month, date.day);
    final snap = await _leaves
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: LeaveStatus.approved.value)
        .where('startDate', isLessThanOrEqualTo: Timestamp.fromDate(dayStart))
        .where('endDate', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return LeaveModel.fromMap(snap.docs.first.data(), id: snap.docs.first.id);
  }

  // ── Private notify ────────────────────────────────────────────────────────

  Future<void> _notify({required String title, required String body}) async {
    try {
      await showNotification(title: title, body: body);
    } catch (_) {}
  }
}

// ── Extension for convenience ─────────────────────────────────────────────────

extension LeaveDurationBool on LeaveDuration {
  bool get isHalfDay =>
      this == LeaveDuration.firstHalf || this == LeaveDuration.secondHalf;
}
