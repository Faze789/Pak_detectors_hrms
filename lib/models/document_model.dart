// lib/models/document_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Enums ────────────────────────────────────────────────────────────────────

enum DocumentCategory {
  offerLetter,
  contract,
  identity,
  certificate,
  policy,
  other,
}

extension DocumentCategoryX on DocumentCategory {
  String get displayName => switch (this) {
    DocumentCategory.offerLetter => 'Non Disclosure Agreement',
    DocumentCategory.contract => 'Contract',
    DocumentCategory.identity => 'Identity',
    DocumentCategory.certificate => 'Certificate',
    DocumentCategory.policy => 'Policy',
    DocumentCategory.other => 'Other',
  };

  static DocumentCategory fromString(String? s) => switch (s) {
    'offerLetter' => DocumentCategory.offerLetter,
    'contract' => DocumentCategory.contract,
    'identity' => DocumentCategory.identity,
    'certificate' => DocumentCategory.certificate,
    'policy' => DocumentCategory.policy,
    _ => DocumentCategory.other,
  };
}

enum DocumentStatus { pending, verified, expired }

extension DocumentStatusX on DocumentStatus {
  String get displayName => switch (this) {
    DocumentStatus.pending => 'Pending',
    DocumentStatus.verified => 'Verified',
    DocumentStatus.expired => 'Expired',
  };

  static DocumentStatus fromString(String? s) => switch (s) {
    'verified' => DocumentStatus.verified,
    'expired' => DocumentStatus.expired,
    _ => DocumentStatus.pending,
  };
}

// ─── Model ────────────────────────────────────────────────────────────────────

class OfficialDocument {
  final String id;
  final String title;
  final String fileUrl;
  final String storagePath;
  final String fileSize;
  final String fileName;
  final String fileExtension;
  final DocumentCategory category;
  final DocumentStatus status;
  final String uploadedBy;
  final DateTime uploadedAt;
  final String employeeId;
  final String employeeName;

  const OfficialDocument({
    required this.id,
    required this.title,
    required this.fileUrl,
    required this.storagePath,
    required this.fileSize,
    this.fileName = '',
    this.fileExtension = '',
    required this.category,
    required this.status,
    required this.uploadedBy,
    required this.uploadedAt,
    this.employeeId = '',
    this.employeeName = '',
  });

  // ── Firestore → model ─────────────────────────────────────────────────────
  factory OfficialDocument.fromFirestore(
    DocumentSnapshot doc, {
    String? parentEmployeeId,
  }) {
    final d = doc.data() as Map<String, dynamic>;
    final ext = (d['fileExtension'] as String? ?? '').toString();
    return OfficialDocument(
      id: doc.id,
      title: d['title'] as String? ?? 'Untitled',
      fileUrl: d['fileUrl'] as String? ?? '',
      storagePath: d['storagePath'] as String? ?? '',
      fileSize: d['fileSize'] as String? ?? '',
      fileName: d['fileName'] as String? ?? '',
      fileExtension: ext,
      category: DocumentCategoryX.fromString(d['category'] as String?),
      status: DocumentStatusX.fromString(d['status'] as String?),
      uploadedBy: d['uploadedBy'] as String? ?? '',
      uploadedAt: (d['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      employeeId:
          (d['employeeId'] as String?) ??
          parentEmployeeId ??
          doc.reference.parent.parent?.id ??
          '',
      employeeName: d['employeeName'] as String? ?? '',
    );
  }

  bool get isImage {
    final e = fileExtension.toLowerCase();
    return e == 'jpg' || e == 'jpeg' || e == 'png';
  }

  bool get isPdf => fileExtension.toLowerCase() == 'pdf';

  // ── model → Firestore ─────────────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
    'title': title,
    'fileUrl': fileUrl,
    'storagePath': storagePath,
    'fileSize': fileSize,
    'fileName': fileName,
    'fileExtension': fileExtension,
    'category': category.name,
    'status': status.name,
    'uploadedBy': uploadedBy,
    'employeeId': employeeId,
    'employeeName': employeeName,
    'uploadedAt': FieldValue.serverTimestamp(),
  };
}
