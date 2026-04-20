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

  // ── Submit leave ──────────────────────────────────────────────────────────

  Future<LeaveModel> submitLeave(LeaveModel leave) async {
    final docRef = _leaves.doc();

    // For half-day leaves, toDate must equal fromDate (same day only)
    final toDate = leave.duration.isHalfDay ? leave.fromDate : leave.toDate;

    // Recalculate deducted days based on duration
    final deductedDays = leave.duration == LeaveDuration.fullDay
        ? toDate.difference(leave.fromDate).inDays + 1.0
        : 0.5;

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
    );

    await docRef.set(model.toMap());

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
