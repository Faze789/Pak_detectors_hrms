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

  // ── Submit leave ──────────────────────────────────────────────────────────

  Future<LeaveModel> submitLeave(LeaveModel leave) async {
    final docRef = _leaves.doc();

    // For half-day leaves, toDate must equal fromDate (same day only)
    final toDate = leave.duration.isHalfDay ? leave.fromDate : leave.toDate;

    // Recalculate deducted days based on duration
    final deductedDays = leave.duration == LeaveDuration.fullDay
        ? toDate.difference(leave.fromDate).inDays + 1.0
        : 0.5;

    // Detect this member's leads and fan out for approval.
    final leadEmpIds = await findLeadsOfMember(leave.emp_id);

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
      requiredApproverEmpIds: leadEmpIds,
    );

    await docRef.set(model.toMap());

    // Notify each lead that needs to decide (in-app, via task_notifications
    // so the existing FCM pipeline picks it up).
    for (final leadEmpId in leadEmpIds) {
      await _db.collection('task_notifications').add({
        'lead_id': leadEmpId,
        'title': 'Leave Approval Needed',
        'body': '${leave.employeeName} requested '
            '${leave.type.label} (${leave.duration.label}). '
            'Tap to review.',
        'type': 'task',
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

  // ── Approve leave ─────────────────────────────────────────────────────────

  Future<void> approveLeave(
    String leaveId,
    String employeeUserId, {
    String? note,
  }) async {
    await _leaves.doc(leaveId).update({
      'status': LeaveStatus.approved.value,
      if (note != null && note.isNotEmpty) 'hrNote': note,
    });
    await _notify(
      title: '✅ Leave Approved',
      body: note != null && note.isNotEmpty
          ? 'Your leave has been approved. Note: $note'
          : 'Your leave request has been approved by HR.',
    );
  }

  // ── Reject leave ──────────────────────────────────────────────────────────

  Future<void> rejectLeave(
    String leaveId,
    String employeeUserId, {
    String? note,
  }) async {
    await _leaves.doc(leaveId).update({
      'status': LeaveStatus.rejected.value,
      if (note != null && note.isNotEmpty) 'hrNote': note,
    });
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

    // Notify the employee
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
