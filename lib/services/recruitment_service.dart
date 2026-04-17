import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/job_model.dart';
import '../models/candidate_model.dart';
import 'dart:typed_data'; // ← fixes Uint8List


class RecruitmentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ─────────────────────── COLLECTIONS ────────────────────────
  CollectionReference get _jobs => _db.collection('jobs');
  CollectionReference get _candidates => _db.collection('candidates');

  // ─────────────────────── JOBS ───────────────────────────────

  /// Real-time stream of all jobs (HR dashboard)
  Stream<List<JobModel>> jobsStream() {
    return _jobs
        .orderBy('postedDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(JobModel.fromFirestore).toList());
  }

  /// Fetch a single job by ID (used on the public apply page)
  Future<JobModel?> getJobById(String jobId) async {
    final doc = await _jobs.doc(jobId).get();
    if (!doc.exists) return null;
    return JobModel.fromFirestore(doc);
  }

  /// Add a new job and return its generated ID
  Future<String> addJob({
    required String title,
    required String department,
    required String description,
    required String requirements,
    required int openings,
    required String baseUrl,
  }) async {
    final ref = _jobs.doc(); // auto-ID
    final applicationLink = '$baseUrl/apply/${ref.id}';
    final job = JobModel(
      id: ref.id,
      title: title,
      department: department,
      description: description,
      requirements: requirements,
      openings: openings,
      status: JobStatus.open,
      postedDate: DateTime.now(),
      applicationLink: applicationLink,
    );
    await ref.set(job.toMap());
    return ref.id;
  }

  /// Update job status
  Future<void> updateJobStatus(String jobId, JobStatus status) async {
    await _jobs.doc(jobId).update({'status': status.name});
  }

  /// Delete job and all its candidates
  Future<void> deleteJob(String jobId) async {
    final batch = _db.batch();
    final cands = await _candidates.where('jobId', isEqualTo: jobId).get();
    for (final doc in cands.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_jobs.doc(jobId));
    await batch.commit();
  }

  // ─────────────────────── CANDIDATES ─────────────────────────

  /// Real-time stream of candidates for a given job
  Stream<List<CandidateModel>> candidatesStream(String jobId) {
    return _candidates
        .where('jobId', isEqualTo: jobId)
        .orderBy('appliedDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(CandidateModel.fromFirestore).toList());
  }

  /// Upload resume to Firebase Storage → returns download URL
  /// Supports both web (bytes) and mobile (file path)
  Future<String> uploadResume({
    required String jobId,
    required String fileName,
    List<int>? bytes,       // Web: file bytes from FilePicker
    String? filePath,       // Mobile: file path from FilePicker
  }) async {
    assert(bytes != null || filePath != null,
    'Either bytes (web) or filePath (mobile) must be provided');

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storageRef = _storage.ref('resumes/$jobId/${timestamp}_$fileName');

    UploadTask task;

    if (bytes != null) {
      // ── Web upload using Uint8List ──────────────────────────
      final metadata = SettableMetadata(
        contentType: _contentType(fileName),
        customMetadata: {
          'jobId': jobId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );
      task = storageRef.putData(
        Uint8List.fromList(bytes),
        metadata,
      );
    } else {
      // ── Mobile upload using File ────────────────────────────
      final file = File(filePath!);
      final metadata = SettableMetadata(
        contentType: _contentType(fileName),
        customMetadata: {
          'jobId': jobId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );
      task = storageRef.putFile(file, metadata);
    }

    final snapshot = await task;
    return await snapshot.ref.getDownloadURL();
  }

  /// Returns the correct MIME type based on file extension
  String _contentType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':  return 'application/pdf';
      case 'doc':  return 'application/msword';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:     return 'application/octet-stream';
    }
  }

  /// Submit a candidate application
  Future<void> submitApplication({
    required String jobId,
    required String jobTitle,
    required String name,
    required String email,
    required String phone,
    required String experience,
    required String coverLetter,
    required String resumeUrl,
    required String resumeFileName,
  }) async {
    await _candidates.add(CandidateModel(
      id: '',
      jobId: jobId,
      jobTitle: jobTitle,
      name: name,
      email: email,
      phone: phone,
      experience: experience,
      coverLetter: coverLetter,
      resumeUrl: resumeUrl,
      resumeFileName: resumeFileName,
      status: CandidateStatus.pending,
      appliedDate: DateTime.now(),
    ).toMap());
  }

  /// Update candidate status (HR action)
  Future<void> updateCandidateStatus(
      String candidateId, CandidateStatus status) async {
    await _candidates.doc(candidateId).update({'status': status.name});
  }
}