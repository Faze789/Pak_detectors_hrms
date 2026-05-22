// lib/services/document_service.dart

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/document_model.dart';

class DocumentService {
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _auth = FirebaseAuth.instance;

  static const _allowedExtensions = ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'];

  CollectionReference<Map<String, dynamic>> _ref(String employeeId) =>
      _firestore.collection('users').doc(employeeId).collection('documents');

  Stream<List<OfficialDocument>> streamDocuments(String employeeId) =>
      _ref(employeeId)
          .orderBy('uploadedAt', descending: true)
          .snapshots()
          .map(
            (s) => s.docs
                .map((d) => OfficialDocument.fromFirestore(
                      d,
                      parentEmployeeId: employeeId,
                    ))
                .toList(),
          );

  /// All employee documents for HR (collection group).
  Stream<List<OfficialDocument>> streamAllDocuments() {
    return _firestore
        .collectionGroup('documents')
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => OfficialDocument.fromFirestore(d))
              .where((d) => d.employeeId.isNotEmpty)
              .toList(),
        );
  }

  Future<List<OfficialDocument>> getAllDocuments() async {
    try {
      final snap = await _firestore
          .collectionGroup('documents')
          .orderBy('uploadedAt', descending: true)
          .get();
      return snap.docs.map((d) => OfficialDocument.fromFirestore(d)).toList();
    } catch (_) {
      final users = await _firestore.collection('users').get();
      final all = <OfficialDocument>[];
      for (final user in users.docs) {
        final role = (user.data()['role'] ?? '').toString().toLowerCase();
        if (role == 'hr' || role == 'admin') continue;
        final docs = await getDocuments(user.id);
        all.addAll(docs);
      }
      all.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
      return all;
    }
  }

  Future<List<OfficialDocument>> getDocuments(String employeeId) async {
    final snap = await _ref(employeeId)
        .orderBy('uploadedAt', descending: true)
        .get();
    return snap.docs
        .map((d) => OfficialDocument.fromFirestore(
              d,
              parentEmployeeId: employeeId,
            ))
        .toList();
  }

  Future<OfficialDocument?> uploadDocument({
    required String employeeId,
    required String employeeName,
    required String title,
    required DocumentCategory category,
    void Function(double)? onProgress,
  }) async {
    final adminUid = _auth.currentUser?.uid;
    if (adminUid == null) throw Exception('Not authenticated.');

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final picked = result.files.first;
    return _uploadPickedFile(
      picked: picked,
      employeeId: employeeId,
      employeeName: employeeName,
      title: title,
      category: category,
      uploadedBy: adminUid,
      onProgress: onProgress,
    );
  }

  Future<OfficialDocument?> _uploadPickedFile({
    required PlatformFile picked,
    required String employeeId,
    required String employeeName,
    required String title,
    required DocumentCategory category,
    required String uploadedBy,
    void Function(double)? onProgress,
  }) async {
    final ext = _extensionFromName(picked.name);
    if (!_allowedExtensions.contains(ext)) {
      throw Exception('File type .$ext is not allowed.');
    }

    final docRef = _ref(employeeId).doc();
    final docId = docRef.id;
    final storagePath = 'employee_docs/$employeeId/$docId.$ext';

    final metadata = SettableMetadata(
      contentType: _contentType(ext),
      customMetadata: {
        'uploadedBy': uploadedBy,
        'employeeId': employeeId,
        'category': category.name,
      },
    );

    final TaskSnapshot snapshot;
    if (picked.bytes != null) {
      final uploadTask =
          _storage.ref(storagePath).putData(picked.bytes!, metadata);
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((snap) {
          if (snap.totalBytes > 0) {
            onProgress(snap.bytesTransferred / snap.totalBytes);
          }
        });
      }
      snapshot = await uploadTask;
    } else if (picked.path != null) {
      final uploadTask =
          _storage.ref(storagePath).putFile(File(picked.path!), metadata);
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
    final bytes = picked.bytes?.length ?? picked.size;
    final fileSize = bytes < 1024 * 1024
        ? '${(bytes / 1024).toStringAsFixed(1)} KB'
        : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

    final resolvedTitle =
        title.trim().isEmpty ? (picked.name) : title.trim();
    final now = DateTime.now();

    await docRef.set({
      'title': resolvedTitle,
      'fileUrl': fileUrl,
      'storagePath': storagePath,
      'fileSize': fileSize,
      'fileName': picked.name,
      'fileExtension': ext,
      'category': category.name,
      'status': DocumentStatus.pending.name,
      'uploadedBy': uploadedBy,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'uploadedAt': FieldValue.serverTimestamp(),
    });

    return OfficialDocument(
      id: docId,
      title: resolvedTitle,
      fileUrl: fileUrl,
      storagePath: storagePath,
      fileSize: fileSize,
      fileName: picked.name,
      fileExtension: ext,
      category: category,
      status: DocumentStatus.pending,
      uploadedBy: uploadedBy,
      uploadedAt: now,
      employeeId: employeeId,
      employeeName: employeeName,
    );
  }

  static String _extensionFromName(String name) {
    final parts = name.split('.');
    if (parts.length < 2) return 'pdf';
    return parts.last.toLowerCase();
  }

  static String _contentType(String ext) => switch (ext) {
        'pdf' => 'application/pdf',
        'doc' => 'application/msword',
        'docx' =>
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        _ => 'application/octet-stream',
      };

  Future<void> deleteDocument({
    required String employeeId,
    required String docId,
    required String storagePath,
  }) async {
    if (storagePath.isNotEmpty) {
      try {
        await _storage.ref(storagePath).delete();
      } catch (_) {}
    }
    await _ref(employeeId).doc(docId).delete();
  }

  Future<void> verifyDocument({
    required String employeeId,
    required String docId,
  }) async {
    await _ref(employeeId)
        .doc(docId)
        .update({'status': DocumentStatus.verified.name});
  }
}
