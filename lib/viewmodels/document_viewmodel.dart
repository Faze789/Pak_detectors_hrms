// lib/viewmodels/document_viewmodel.dart

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/document_model.dart';
import '../services/document_service.dart';

class DocumentViewModel extends ChangeNotifier {
  final DocumentService _service;

  DocumentViewModel({DocumentService? service})
      : _service = service ?? DocumentService();

  List<OfficialDocument> _documents = [];
  List<OfficialDocument> _allDocuments = [];
  bool _isLoading = false;
  bool _isUploading = false;
  double _uploadProgress = 0;
  String? _error;
  String? _currentEmployeeId;
  String _employeeNameFilter = '';
  StreamSubscription? _sub;
  StreamSubscription? _allSub;

  List<OfficialDocument> get documents => _documents;
  List<OfficialDocument> get allDocuments => _filteredAllDocuments;
  int get allDocumentsTotal => _allDocuments.length;
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  double get uploadProgress => _uploadProgress;
  String? get error => _error;
  String get employeeNameFilter => _employeeNameFilter;

  List<OfficialDocument> get _filteredAllDocuments {
    if (_employeeNameFilter.trim().isEmpty) return _allDocuments;
    final q = _employeeNameFilter.trim().toLowerCase();
    return _allDocuments
        .where((d) => d.employeeName.toLowerCase().contains(q))
        .toList();
  }

  int get totalDocuments => _documents.length;
  int get verifiedCount =>
      _documents.where((d) => d.status == DocumentStatus.verified).length;
  int get pendingCount =>
      _documents.where((d) => d.status == DocumentStatus.pending).length;
  int get expiredCount =>
      _documents.where((d) => d.status == DocumentStatus.expired).length;

  void loadDocuments({required String employeeId}) {
    if (_currentEmployeeId == employeeId && _sub != null) return;
    _currentEmployeeId = employeeId;
    _allSub?.cancel();
    _allSub = null;

    _sub?.cancel();
    _isLoading = true;
    notifyListeners();

    _sub = _service.streamDocuments(employeeId).listen(
      (docs) {
        _documents = docs;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void loadAllDocumentsForHR() {
    _sub?.cancel();
    _sub = null;
    _currentEmployeeId = null;
    _isLoading = true;
    notifyListeners();

    _allSub?.cancel();
    _allSub = _service.streamAllDocuments().listen(
      (docs) {
        _allDocuments = docs;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) async {
        try {
          _allDocuments = await _service.getAllDocuments();
          _error = null;
        } catch (e2) {
          _error = e2.toString();
        }
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void setEmployeeNameFilter(String value) {
    _employeeNameFilter = value;
    notifyListeners();
  }

  Future<bool> uploadDocument({
    required String employeeId,
    required String employeeName,
    required String title,
    required DocumentCategory category,
  }) async {
    _isUploading = true;
    _uploadProgress = 0;
    _error = null;
    notifyListeners();

    try {
      final doc = await _service.uploadDocument(
        employeeId: employeeId,
        employeeName: employeeName,
        title: title,
        category: category,
        onProgress: (p) {
          _uploadProgress = p;
          notifyListeners();
        },
      );

      _isUploading = false;
      _uploadProgress = 0;
      notifyListeners();
      return doc != null;
    } catch (e) {
      _error = e.toString();
      _isUploading = false;
      _uploadProgress = 0;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteDocument(String docId, {String? employeeId}) async {
    OfficialDocument? doc;
    for (final d in [..._documents, ..._allDocuments]) {
      if (d.id == docId) {
        doc = d;
        break;
      }
    }
    if (doc == null) return false;
    final eid = employeeId ?? doc.employeeId;
    if (eid.isEmpty) return false;

    try {
      await _service.deleteDocument(
        employeeId: eid,
        docId: docId,
        storagePath: doc.storagePath,
      );
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> verifyDocument(String docId) async {
    final employeeId = _currentEmployeeId;
    if (employeeId == null) return;
    await _service.verifyDocument(employeeId: employeeId, docId: docId);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _allSub?.cancel();
    super.dispose();
  }
}
