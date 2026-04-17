// lib/services/document_service.dart

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/document_model.dart';

class DocumentService {
  final _firestore = FirebaseFirestore.instance;
  final _storage   = FirebaseStorage.instance;
  final _auth      = FirebaseAuth.instance;

  // ── Firestore reference ───────────────────────────────────────────────────
  // users/{employeeId}/documents/{docId}
  CollectionReference<Map<String, dynamic>> _ref(String employeeId) =>
      _firestore.collection('users').doc(employeeId).collection('documents');

  // ── Stream (real-time) ────────────────────────────────────────────────────
  Stream<List<OfficialDocument>> streamDocuments(String employeeId) =>
      _ref(employeeId)
          .orderBy('uploadedAt', descending: true)
          .snapshots()
          .map((s) => s.docs.map(OfficialDocument.fromFirestore).toList());

  // ── One-shot fetch ────────────────────────────────────────────────────────
  Future<List<OfficialDocument>> getDocuments(String employeeId) async {
    final snap = await _ref(employeeId)
        .orderBy('uploadedAt', descending: true)
        .get();
    return snap.docs.map(OfficialDocument.fromFirestore).toList();
  }

  Future<OfficialDocument?> getDocumentById(
      String employeeId, String docId) async {
    final snap = await _ref(employeeId).doc(docId).get();
    return snap.exists ? OfficialDocument.fromFirestore(snap) : null;
  }

  // ── Upload PDF ────────────────────────────────────────────────────────────
  /// Opens the system file picker (PDF only), uploads to Firebase Storage,
  /// writes a Firestore record, and returns the created [OfficialDocument].
  ///
  /// [onProgress] receives 0.0 – 1.0 as the upload progresses.
  Future<OfficialDocument?> uploadDocument({
    required String           employeeId,
    required String           title,
    required DocumentCategory category,
    void Function(double)? onProgress,
  }) async {
    final adminUid = _auth.currentUser?.uid;
    if (adminUid == null) throw Exception('Not authenticated.');

    // ── Pick file — withData: true required on web (path is unavailable) ──
    final result = await FilePicker.platform.pickFiles(
      type:              FileType.custom,
      allowedExtensions: ['pdf'],
      withData:          true,   // loads bytes for web compatibility
    );
    if (result == null || result.files.isEmpty) return null; // user cancelled

    final picked = result.files.first;

    // ── Storage path: employee_docs/{employeeId}/{docId}.pdf ──────────────
    final docRef      = _ref(employeeId).doc();
    final docId       = docRef.id;
    final storagePath = 'employee_docs/$employeeId/$docId.pdf';

    final metadata = SettableMetadata(
      contentType: 'application/pdf',
      customMetadata: {
        'uploadedBy': adminUid,
        'employeeId': employeeId,
        'category':   category.name,
      },
    );

    // ── Use bytes on web, file path on mobile/desktop ─────────────────────
    final TaskSnapshot snapshot;
    if (picked.bytes != null) {
      // Web (and any platform where path is unavailable)
      final uploadTask = _storage.ref(storagePath).putData(
        picked.bytes!,
        metadata,
      );
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((snap) {
          if (snap.totalBytes > 0) {
            onProgress(snap.bytesTransferred / snap.totalBytes);
          }
        });
      }
      snapshot = await uploadTask;
    } else if (picked.path != null) {
      // Mobile / desktop
      final uploadTask = _storage.ref(storagePath).putFile(
        File(picked.path!),
        metadata,
      );
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((snap) {
          if (snap.totalBytes > 0) {
            onProgress(snap.bytesTransferred / snap.totalBytes);
          }
        });
      }
      snapshot = await uploadTask;
    } else {
      throw Exception('Could not read file: no bytes or path available.');
    }

    final fileUrl = await snapshot.ref.getDownloadURL();

    // ── Format size ───────────────────────────────────────────────────────
    final bytes    = picked.bytes?.length ?? picked.size;
    final fileSize = bytes < 1024 * 1024
        ? '${(bytes / 1024).toStringAsFixed(1)} KB'
        : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

    // ── Firestore record ──────────────────────────────────────────────────
    final now = DateTime.now();
    await docRef.set({
      'title':       title.trim().isEmpty ? picked.name : title.trim(),
      'fileUrl':     fileUrl,
      'storagePath': storagePath,
      'fileSize':    fileSize,
      'category':    category.name,
      'status':      DocumentStatus.pending.name,
      'uploadedBy':  adminUid,
      'uploadedAt':  FieldValue.serverTimestamp(),
    });

    return OfficialDocument(
      id:          docId,
      title:       title.trim().isEmpty ? picked.name : title.trim(),
      fileUrl:     fileUrl,
      storagePath: storagePath,
      fileSize:    fileSize,
      category:    category,
      status:      DocumentStatus.pending,
      uploadedBy:  adminUid,
      uploadedAt:  now,
    );
  }

  // ── Delete ────────────────────────────────────────────────────────────────
  Future<void> deleteDocument({
    required String employeeId,
    required String docId,
    required String storagePath,
  }) async {
    // Remove from Storage first (ignore if already gone)
    if (storagePath.isNotEmpty) {
      try {
        await _storage.ref(storagePath).delete();
      } catch (_) {}
    }
    await _ref(employeeId).doc(docId).delete();
  }

  // ── Verify ────────────────────────────────────────────────────────────────
  Future<void> verifyDocument({
    required String employeeId,
    required String docId,
  }) async {
    await _ref(employeeId)
        .doc(docId)
        .update({'status': DocumentStatus.verified.name});
  }

  // ── Filter helpers ────────────────────────────────────────────────────────
  Future<List<OfficialDocument>> getDocumentsByCategory({
    required String           employeeId,
    required DocumentCategory category,
  }) async {
    final snap = await _ref(employeeId)
        .where('category', isEqualTo: category.name)
        .orderBy('uploadedAt', descending: true)
        .get();
    return snap.docs.map(OfficialDocument.fromFirestore).toList();
  }

  Future<List<OfficialDocument>> getPendingDocuments(String employeeId) async {
    final snap = await _ref(employeeId)
        .where('status', isEqualTo: DocumentStatus.pending.name)
        .get();
    return snap.docs.map(OfficialDocument.fromFirestore).toList();
  }
}