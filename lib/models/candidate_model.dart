import 'package:cloud_firestore/cloud_firestore.dart';

enum CandidateStatus { pending, shortlisted, hired, rejected }

class CandidateModel {
  final String id;
  final String jobId;
  final String jobTitle;
  final String name;
  final String email;
  final String phone;
  final String experience;
  final String coverLetter;
  final String resumeUrl;      // Firebase Storage download URL
  final String resumeFileName;
  final CandidateStatus status;
  final DateTime appliedDate;

  CandidateModel({
    required this.id,
    required this.jobId,
    required this.jobTitle,
    required this.name,
    required this.email,
    required this.phone,
    required this.experience,
    required this.coverLetter,
    required this.resumeUrl,
    required this.resumeFileName,
    required this.status,
    required this.appliedDate,
  });

  String get statusLabel {
    switch (status) {
      case CandidateStatus.pending:
        return 'Pending';
      case CandidateStatus.shortlisted:
        return 'Shortlisted';
      case CandidateStatus.hired:
        return 'Hired';
      case CandidateStatus.rejected:
        return 'Rejected';
    }
  }

  factory CandidateModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CandidateModel(
      id: doc.id,
      jobId: data['jobId'] ?? '',
      jobTitle: data['jobTitle'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      experience: data['experience'] ?? '',
      coverLetter: data['coverLetter'] ?? '',
      resumeUrl: data['resumeUrl'] ?? '',
      resumeFileName: data['resumeFileName'] ?? '',
      status: _statusFromString(data['status'] ?? 'pending'),
      appliedDate: (data['appliedDate'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'jobId': jobId,
    'jobTitle': jobTitle,
    'name': name,
    'email': email,
    'phone': phone,
    'experience': experience,
    'coverLetter': coverLetter,
    'resumeUrl': resumeUrl,
    'resumeFileName': resumeFileName,
    'status': status.name,
    'appliedDate': Timestamp.fromDate(appliedDate),
  };

  CandidateModel copyWith({CandidateStatus? status}) => CandidateModel(
    id: id,
    jobId: jobId,
    jobTitle: jobTitle,
    name: name,
    email: email,
    phone: phone,
    experience: experience,
    coverLetter: coverLetter,
    resumeUrl: resumeUrl,
    resumeFileName: resumeFileName,
    status: status ?? this.status,
    appliedDate: appliedDate,
  );

  static CandidateStatus _statusFromString(String s) {
    switch (s) {
      case 'shortlisted':
        return CandidateStatus.shortlisted;
      case 'hired':
        return CandidateStatus.hired;
      case 'rejected':
        return CandidateStatus.rejected;
      default:
        return CandidateStatus.pending;
    }
  }
}