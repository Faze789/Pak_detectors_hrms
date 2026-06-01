import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/loan_advance_request.dart';

/// Firestore CRUD for `loan_advance_requests`.
///
/// Notifications reuse the existing `task_notifications` collection
/// (`lead_id` = recipient emp_id, `type` = 'loan_advance'). That way the
/// already-running listeners in both sidebar wrappers light up without any
/// new plumbing.
class LoanAdvanceService {
  final FirebaseFirestore _db;
  LoanAdvanceService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('loan_advance_requests');

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _db.collection('task_notifications');

  /// Stream all requests for a single employee, newest first.
  Stream<List<LoanAdvanceRequest>> streamForEmployee(String employeeUid) {
    return _col.where('employeeUid', isEqualTo: employeeUid).snapshots().map((
      snap,
    ) {
      final list = snap.docs
          .map((d) => LoanAdvanceRequest.fromMap(d.data(), id: d.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Stream all requests, optionally filtered by status. Newest first.
  Stream<List<LoanAdvanceRequest>> streamAll({LoanAdvanceStatus? status}) {
    Query<Map<String, dynamic>> q = _col;
    if (status != null) {
      q = q.where('status', isEqualTo: status.value);
    }
    return q.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => LoanAdvanceRequest.fromMap(d.data(), id: d.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Employee submits a new request and notifies every HR user.
  Future<String> createRequest({
    required String employeeUid,
    required String employeeEmpId,
    required String employeeName,
    required LoanAdvanceKind kind,
    required double amount,
    required String message,
  }) async {
    final ref = await _col.add({
      'employeeUid': employeeUid,
      'employeeEmpId': employeeEmpId,
      'employeeName': employeeName,
      'kind': kind.value,
      'amount': amount,
      'initialMessage': message,
      'status': LoanAdvanceStatus.pending.value,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _notifyAllHr(
      title: 'New ${kind.label} Request',
      body:
          '$employeeName ($employeeEmpId) requested a ${kind.label.toLowerCase()} '
          'of Rs. ${amount.toStringAsFixed(0)}',
      referenceId: ref.id,
    );

    return ref.id;
  }

  /// HR accepts or rejects a request. Notifies the employee.
  Future<void> updateStatus({
    required String requestId,
    required LoanAdvanceStatus status,
    required String hrEmpId,
    required String employeeEmpId,
    required LoanAdvanceKind kind,
    required double amount,
    String? reason,
  }) async {
    await _col.doc(requestId).update({
      'status': status.value,
      'respondedBy': hrEmpId,
      'respondedAt': FieldValue.serverTimestamp(),
      if (reason != null && reason.trim().isNotEmpty)
        'responseReason': reason.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final verb = status == LoanAdvanceStatus.accepted ? 'Accepted' : 'Rejected';
    await _notifications.add({
      'lead_id': employeeEmpId,
      'title': '${kind.label} Request $verb',
      'body':
          'Your ${kind.label.toLowerCase()} request of Rs. ${amount.toStringAsFixed(0)} '
          'was ${verb.toLowerCase()} by HR'
          '${reason != null && reason.trim().isNotEmpty ? ' — ${reason.trim()}' : ''}',
      'type': 'loan_advance',
      'referenceId': requestId,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  Future<void> _notifyAllHr({
    required String title,
    required String body,
    required String referenceId,
  }) async {
    final hrUsers = await _db
        .collection('users')
        .where('role', isEqualTo: 'hr')
        .get();
    for (final doc in hrUsers.docs) {
      final hrEmpId = (doc.data()['emp_id'] ?? doc.id).toString();
      await _notifications.add({
        'lead_id': hrEmpId,
        'title': title,
        'body': body,
        'type': 'loan_advance',
        'referenceId': referenceId,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    }
  }
}
