import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Centralised PDF upload utility used across HR/Lead/Member task flows.
///
/// All task-related attachments (HR creation, lead breakdown, member
/// submission, lead/member barriers, etc.) go through this service so we get
/// consistent MIME/size validation and a single attachment-metadata shape:
///
///   { name, url, size, uploadedBy, role, uploadedAt, storagePath, type }
class StorageService {
  StorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  /// 10 MB hard cap.
  static const int maxBytes = 10 * 1024 * 1024;

  /// Throws [StorageValidationException] for non-PDF or oversize files.
  /// Throws [StorageUploadException] if the upload itself fails.
  Future<Map<String, dynamic>> uploadPdf({
    required String storagePath,
    required PlatformFile file,
    required String uploadedBy,
    required String uploaderRole,
  }) async {
    _validatePdf(file);

    final ref = _storage.ref(storagePath);
    final metadata = SettableMetadata(contentType: 'application/pdf');

    try {
      if (file.bytes != null) {
        await ref.putData(file.bytes!, metadata);
      } else if (!kIsWeb && file.path != null) {
        await ref.putFile(File(file.path!), metadata);
      } else {
        throw StorageUploadException(
          'File ${file.name} has neither bytes nor a path — cannot upload.',
        );
      }

      final url = await ref.getDownloadURL();
      return {
        'name': file.name,
        'url': url,
        'size': file.size,
        'type': 'pdf',
        'uploadedBy': uploadedBy,
        'role': uploaderRole,
        'uploadedAt': Timestamp.now(),
        'storagePath': storagePath,
      };
    } on FirebaseException catch (e) {
      throw StorageUploadException('Upload failed: ${e.message}');
    }
  }

  /// Upload many PDFs sequentially and return the metadata list.
  /// Stops on the first failure and rethrows.
  Future<List<Map<String, dynamic>>> uploadManyPdfs({
    required String pathPrefix,
    required List<PlatformFile> files,
    required String uploadedBy,
    required String uploaderRole,
  }) async {
    final results = <Map<String, dynamic>>[];
    for (final f in files) {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final safeName = f.name.replaceAll(RegExp(r'[^\w\.-]'), '_');
      final fullPath = '$pathPrefix/${ts}_$safeName';
      results.add(
        await uploadPdf(
          storagePath: fullPath,
          file: f,
          uploadedBy: uploadedBy,
          uploaderRole: uploaderRole,
        ),
      );
    }
    return results;
  }

  /// Delete an uploaded file by storage path. Best-effort; swallows missing-file errors.
  Future<void> deleteByPath(String storagePath) async {
    try {
      await _storage.ref(storagePath).delete();
    } on FirebaseException {
      // ignore: file may already be gone
    }
  }

  void _validatePdf(PlatformFile file) {
    final ext = (file.extension ?? '').toLowerCase();
    if (ext != 'pdf') {
      throw StorageValidationException(
        '${file.name}: only PDF files are allowed.',
      );
    }
    if (file.size > maxBytes) {
      throw StorageValidationException(
        '${file.name}: exceeds the ${maxBytes ~/ (1024 * 1024)} MB limit.',
      );
    }
  }
}

class StorageValidationException implements Exception {
  StorageValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

class StorageUploadException implements Exception {
  StorageUploadException(this.message);
  final String message;
  @override
  String toString() => message;
}
