// lib/models/loan_advance_request.dart
//
// Employee → HR loan/advance request. Lives in `loan_advance_requests/{id}`.
// A subcollection `messages/{messageId}` holds the chat thread between the
// employee and HR. The parent doc tracks the current status (pending /
// accepted / rejected).

import 'package:cloud_firestore/cloud_firestore.dart';

enum LoanAdvanceKind { loan, advance }

extension LoanAdvanceKindX on LoanAdvanceKind {
  String get value => name;
  String get label => switch (this) {
        LoanAdvanceKind.loan => 'Loan',
        LoanAdvanceKind.advance => 'Advance',
      };
  static LoanAdvanceKind parse(String? v) {
    switch (v) {
      case 'advance':
        return LoanAdvanceKind.advance;
      default:
        return LoanAdvanceKind.loan;
    }
  }
}

enum LoanAdvanceStatus { pending, accepted, rejected }

extension LoanAdvanceStatusX on LoanAdvanceStatus {
  String get value => name;
  String get label => switch (this) {
        LoanAdvanceStatus.pending => 'Pending',
        LoanAdvanceStatus.accepted => 'Accepted',
        LoanAdvanceStatus.rejected => 'Rejected',
      };
  static LoanAdvanceStatus parse(String? v) {
    switch (v) {
      case 'accepted':
        return LoanAdvanceStatus.accepted;
      case 'rejected':
        return LoanAdvanceStatus.rejected;
      default:
        return LoanAdvanceStatus.pending;
    }
  }
}

class LoanAdvanceRequest {
  final String id;
  final String employeeUid;
  final String employeeEmpId;
  final String employeeName;
  final LoanAdvanceKind kind;
  final double? amount;
  final String initialMessage;
  final LoanAdvanceStatus status;
  final String? respondedBy;
  final DateTime? respondedAt;
  final String? responseReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LoanAdvanceRequest({
    required this.id,
    required this.employeeUid,
    required this.employeeEmpId,
    required this.employeeName,
    required this.kind,
    this.amount,
    required this.initialMessage,
    required this.status,
    this.respondedBy,
    this.respondedAt,
    this.responseReason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LoanAdvanceRequest.fromMap(Map<String, dynamic> m,
      {required String id}) {
    DateTime ts(dynamic v) =>
        v is Timestamp ? v.toDate() : DateTime.now();
    return LoanAdvanceRequest(
      id: id,
      employeeUid: (m['employeeUid'] ?? '').toString(),
      employeeEmpId: (m['employeeEmpId'] ?? '').toString(),
      employeeName: (m['employeeName'] ?? '').toString(),
      kind: LoanAdvanceKindX.parse((m['kind'] ?? '').toString()),
      amount: (m['amount'] as num?)?.toDouble(),
      initialMessage: (m['initialMessage'] ?? '').toString(),
      status: LoanAdvanceStatusX.parse((m['status'] ?? '').toString()),
      respondedBy: m['respondedBy']?.toString(),
      respondedAt:
          m['respondedAt'] is Timestamp ? (m['respondedAt'] as Timestamp).toDate() : null,
      responseReason: m['responseReason']?.toString(),
      createdAt: ts(m['createdAt']),
      updatedAt: ts(m['updatedAt']),
    );
  }
}

class LoanAdvanceMessage {
  final String id;
  final String text;
  final String senderUid;
  // 'employee' | 'hr' | 'system'
  final String senderRole;
  final String senderName;
  final DateTime createdAt;

  const LoanAdvanceMessage({
    required this.id,
    required this.text,
    required this.senderUid,
    required this.senderRole,
    required this.senderName,
    required this.createdAt,
  });

  factory LoanAdvanceMessage.fromMap(Map<String, dynamic> m,
      {required String id}) {
    return LoanAdvanceMessage(
      id: id,
      text: (m['text'] ?? '').toString(),
      senderUid: (m['senderUid'] ?? '').toString(),
      senderRole: (m['senderRole'] ?? 'employee').toString(),
      senderName: (m['senderName'] ?? '').toString(),
      createdAt: m['createdAt'] is Timestamp
          ? (m['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
