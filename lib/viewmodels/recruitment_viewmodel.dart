import 'package:flutter/material.dart';
import '../models/job_model.dart';
import '../models/candidate_model.dart';
import '../services/recruitment_service.dart';

class RecruitmentViewModel extends ChangeNotifier {
  final RecruitmentService _service = RecruitmentService();

  // ─── State ───────────────────────────────────────────────────
  List<JobModel> _jobs = [];
  String _searchQuery = '';
  String _departmentFilter = 'All';
  String _statusFilter = 'All';
  bool _isLoading = false;
  String? _error;

  // ✅ Real Firebase Hosting URL
  static const String baseUrl = 'https://hrms-1bc9a.web.app';

  // ─── Getters ─────────────────────────────────────────────────
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<String> get departments => ['All', 'IT', 'HR', 'Sales', 'Finance', 'Marketing'];

  List<JobModel> get filteredJobs {
    return _jobs.where((job) {
      final matchSearch = job.title.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchDept = _departmentFilter == 'All' || job.department == _departmentFilter;
      final matchStatus = _statusFilter == 'All' || job.statusLabel == _statusFilter;
      return matchSearch && matchDept && matchStatus;
    }).toList();
  }

  // ─── Stream binding (call once from HR screen initState) ─────
  void bindJobsStream() {
    _service.jobsStream().listen((jobs) {
      _jobs = jobs;
      notifyListeners();
    }, onError: (e) {
      _error = e.toString();
      notifyListeners();
    });
  }

  // ─── Filters ─────────────────────────────────────────────────
  void setSearch(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  void setDepartmentFilter(String d) {
    _departmentFilter = d;
    notifyListeners();
  }

  void setStatusFilter(String s) {
    _statusFilter = s;
    notifyListeners();
  }

  // ─── Add Job ─────────────────────────────────────────────────
  Future<String?> addJob({
    required String title,
    required String department,
    required String description,
    required String requirements,
    required int openings,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final id = await _service.addJob(
        title: title,
        department: department,
        description: description,
        requirements: requirements,
        openings: openings,
        baseUrl: baseUrl,
      );
      return '$baseUrl/apply/$id';
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateJobStatus(String jobId, JobStatus status) async {
    await _service.updateJobStatus(jobId, status);
  }

  Future<void> deleteJob(String jobId) async {
    await _service.deleteJob(jobId);
  }

  // ─── Candidates stream for a job ─────────────────────────────
  Stream<List<CandidateModel>> candidatesStream(String jobId) =>
      _service.candidatesStream(jobId);

  Future<void> updateCandidateStatus(
      String candidateId, CandidateStatus status) async {
    await _service.updateCandidateStatus(candidateId, status);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Separate ViewModel for the PUBLIC apply page (no auth needed)
// ─────────────────────────────────────────────────────────────────────────────
class ApplyViewModel extends ChangeNotifier {
  final RecruitmentService _service = RecruitmentService();

  JobModel? job;
  bool isLoadingJob = true;
  bool isSubmitting = false;
  bool submitted = false;
  String? error;

  // Web uses bytes; mobile uses File path
  // We store both and the service decides which to use
  List<int>? resumeBytes;       // used on Web
  String? resumeFilePath;       // used on mobile
  String? resumeFileName;

  Future<void> loadJob(String jobId) async {
    isLoadingJob = true;
    error = null;
    notifyListeners();
    try {
      job = await _service.getJobById(jobId);
      if (job == null) error = 'Job not found.';
    } catch (e) {
      error = e.toString();
    } finally {
      isLoadingJob = false;
      notifyListeners();
    }
  }

  /// Call this from the resume picker with bytes (web) or path (mobile)
  void setResumeBytes(List<int> bytes, String name) {
    resumeBytes = bytes;
    resumeFilePath = null;
    resumeFileName = name;
    notifyListeners();
  }

  void setResumeFile(String path, String name) {
    resumeFilePath = path;
    resumeBytes = null;
    resumeFileName = name;
    notifyListeners();
  }

  bool get hasResume => resumeBytes != null || resumeFilePath != null;

  Future<bool> submitApplication({
    required String name,
    required String email,
    required String phone,
    required String experience,
    required String coverLetter,
  }) async {
    if (job == null || !hasResume) return false;
    isSubmitting = true;
    error = null;
    notifyListeners();
    try {
      final resumeUrl = await _service.uploadResume(
        jobId: job!.id,
        fileName: resumeFileName!,
        bytes: resumeBytes,
        filePath: resumeFilePath,
      );
      await _service.submitApplication(
        jobId: job!.id,
        jobTitle: job!.title,
        name: name,
        email: email,
        phone: phone,
        experience: experience,
        coverLetter: coverLetter,
        resumeUrl: resumeUrl,
        resumeFileName: resumeFileName!,
      );
      submitted = true;
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }
}