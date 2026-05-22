// lib/services/company_letter_service.dart
//
// CRUD + send pipeline for `company_letters/{id}` documents.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/company_letter.dart';

class CompanyLetterService {
  final FirebaseFirestore _db;
  CompanyLetterService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('company_letters');

  /// Creates a new letter doc. Marks it as sent immediately (since the
  /// HR flow saves + sends in one step) and writes a `task_notifications`
  /// entry routed to the employee's emp_id so the existing FCM trigger
  /// pushes it to their device.
  Future<String> createAndSend(CompanyLetter letter) async {
    final now = DateTime.now();
    final payload = letter.toMap();
    payload['sentAt'] = Timestamp.fromDate(now);
    final ref = await _col.add(payload);
    // Notify the employee.
    if (letter.employeeEmpId.isNotEmpty) {
      await _db.collection('task_notifications').add({
        'lead_id': letter.employeeEmpId,
        'title': '📄 ${letter.kind.label}',
        'body': '${letter.subject} — issued by ${letter.hrName}.',
        'type': 'company_letter',
        'referenceId': ref.id,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    }
    return ref.id;
  }

  Future<void> update(CompanyLetter letter) async {
    await _col.doc(letter.id).set(letter.toMap(), SetOptions(merge: true));
  }

  Future<void> delete(String letterId) async {
    await _col.doc(letterId).delete();
  }

  Stream<List<CompanyLetter>> streamForEmployee(String employeeUid) {
    return _col
        .where('employeeUid', isEqualTo: employeeUid)
        .snapshots()
        .map((s) {
      final list = s.docs
          .map((d) => CompanyLetter.fromMap(d.data(), id: d.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<List<CompanyLetter>> streamAll() {
    return _col.orderBy('createdAt', descending: true).snapshots().map(
          (s) => s.docs
              .map((d) => CompanyLetter.fromMap(d.data(), id: d.id))
              .toList(),
        );
  }

  Future<CompanyLetter?> getById(String id) async {
    final snap = await _col.doc(id).get();
    if (!snap.exists || snap.data() == null) return null;
    return CompanyLetter.fromMap(snap.data()!, id: snap.id);
  }
}
