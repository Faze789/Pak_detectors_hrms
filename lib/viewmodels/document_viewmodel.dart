// lib/viewmodels/document_viewmodel.dart

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/document_model.dart';
import '../services/document_service.dart';

class DocumentViewModel extends ChangeNotifier {
  final DocumentService _service;

  DocumentViewModel({DocumentService? service})
      : _service = service ?? DocumentService();

  // ── State ──────────────────────────────────────────────────────────────────
  List<OfficialDocument> _documents      = [];
  bool                   _isLoading      = false;
  bool                   _isUploading    = false;
  double                 _uploadProgress = 0;
  String?                _error;
  String?                _currentEmployeeId;
  StreamSubscription?    _sub;

  // ── Getters ────────────────────────────────────────────────────────────────
  List<OfficialDocument> get documents       => _documents;
  bool                   get isLoading       => _isLoading;
  bool                   get isUploading     => _isUploading;
  double                 get uploadProgress  => _uploadProgress;
  String?                get error           => _error;

  int get totalDocuments => _documents.length;
  int get verifiedCount  => _documents.where((d) => d.status == DocumentStatus.verified).length;
  int get pendingCount   => _documents.where((d) => d.status == DocumentStatus.pending).length;
  int get expiredCount   => _documents.where((d) => d.status == DocumentStatus.expired).length;

  // ── Load (real-time stream) ────────────────────────────────────────────────
  void loadDocuments({required String employeeId}) {
    if (_currentEmployeeId == employeeId) return;
    _currentEmployeeId = employeeId;

    _sub?.cancel();
    _isLoading = true;
    notifyListeners();

    _sub = _service.streamDocuments(employeeId).listen(
          (docs) {
        _documents = docs;
        _isLoading = false;
        _error     = null;
        notifyListeners();
      },
      onError: (e) {
        _error     = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  // ── Upload ─────────────────────────────────────────────────────────────────
  Future<bool> uploadDocument({
    required String           employeeId,
    required String           title,
    required DocumentCategory category,
  }) async {
    _isUploading    = true;
    _uploadProgress = 0;
    _error          = null;
    notifyListeners();

    try {
      final doc = await _service.uploadDocument(
        employeeId: employeeId,
        title:      title,
        category:   category,
        onProgress: (p) {
          _uploadProgress = p;
          notifyListeners();
        },
      );

      _isUploading    = false;
      _uploadProgress = 0;
      notifyListeners();
      return doc != null;
    } catch (e) {
      _error          = e.toString();
      _isUploading    = false;
      _uploadProgress = 0;
      notifyListeners();
      return false;
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────
  Future<bool> deleteDocument(String docId) async {
    final employeeId = _currentEmployeeId;
    if (employeeId == null) return false;

    final doc = _documents.firstWhere(
          (d) => d.id == docId,
      orElse: () => throw Exception('Document not found'),
    );

    try {
      await _service.deleteDocument(
        employeeId:  employeeId,
        docId:       docId,
        storagePath: doc.storagePath,
      );
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Verify ─────────────────────────────────────────────────────────────────
  Future<void> verifyDocument(String docId) async {
    final employeeId = _currentEmployeeId;
    if (employeeId == null) return;
    await _service.verifyDocument(employeeId: employeeId, docId: docId);
  }

  // ── Get URL ────────────────────────────────────────────────────────────────
  String? getFileUrl(String docId) {
    try {
      return _documents.firstWhere((d) => d.id == docId).fileUrl;
    } catch (_) {
      return null;
    }
  }

  // ── Cleanup ────────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}