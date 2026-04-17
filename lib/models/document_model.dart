// lib/models/document_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Enums ────────────────────────────────────────────────────────────────────

enum DocumentCategory { contract, identity, certificate, policy, other }

extension DocumentCategoryX on DocumentCategory {
  String get displayName => switch (this) {
    DocumentCategory.contract    => 'Contract',
    DocumentCategory.identity    => 'Identity',
    DocumentCategory.certificate => 'Certificate',
    DocumentCategory.policy      => 'Policy',
    DocumentCategory.other       => 'Other',
  };

  static DocumentCategory fromString(String? s) => switch (s) {
    'contract'    => DocumentCategory.contract,
    'identity'    => DocumentCategory.identity,
    'certificate' => DocumentCategory.certificate,
    'policy'      => DocumentCategory.policy,
    _             => DocumentCategory.other,
  };
}

enum DocumentStatus { pending, verified, expired }

extension DocumentStatusX on DocumentStatus {
  String get displayName => switch (this) {
    DocumentStatus.pending  => 'Pending',
    DocumentStatus.verified => 'Verified',
    DocumentStatus.expired  => 'Expired',
  };

  static DocumentStatus fromString(String? s) => switch (s) {
    'verified' => DocumentStatus.verified,
    'expired'  => DocumentStatus.expired,
    _          => DocumentStatus.pending,
  };
}

// ─── Model ────────────────────────────────────────────────────────────────────

class OfficialDocument {
  final String           id;
  final String           title;
  final String           fileUrl;
  final String           storagePath;
  final String           fileSize;       // e.g. "204 KB"
  final DocumentCategory category;
  final DocumentStatus   status;
  final String           uploadedBy;     // admin UID
  final DateTime         uploadedAt;

  const OfficialDocument({
    required this.id,
    required this.title,
    required this.fileUrl,
    required this.storagePath,
    required this.fileSize,
    required this.category,
    required this.status,
    required this.uploadedBy,
    required this.uploadedAt,
  });

  // ── Firestore → model ─────────────────────────────────────────────────────
  factory OfficialDocument.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return OfficialDocument(
      id:          doc.id,
      title:       d['title']       as String? ?? 'Untitled',
      fileUrl:     d['fileUrl']     as String? ?? '',
      storagePath: d['storagePath'] as String? ?? '',
      fileSize:    d['fileSize']    as String? ?? '',
      category:    DocumentCategoryX.fromString(d['category'] as String?),
      status:      DocumentStatusX.fromString(d['status']   as String?),
      uploadedBy:  d['uploadedBy']  as String? ?? '',
      uploadedAt:  (d['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // ── model → Firestore ─────────────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
    'title':       title,
    'fileUrl':     fileUrl,
    'storagePath': storagePath,
    'fileSize':    fileSize,
    'category':    category.name,
    'status':      status.name,
    'uploadedBy':  uploadedBy,
    'uploadedAt':  FieldValue.serverTimestamp(),
  };
}