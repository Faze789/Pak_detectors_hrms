import 'package:cloud_firestore/cloud_firestore.dart';

enum JobStatus { open, closed, draft }

class JobModel {
  final String id;
  final String title;
  final String department;
  final String description;
  final String requirements;
  final int openings;
  final JobStatus status;
  final DateTime postedDate;
  final String applicationLink; // e.g. /apply/{id}

  JobModel({
    required this.id,
    required this.title,
    required this.department,
    required this.description,
    required this.requirements,
    required this.openings,
    required this.status,
    required this.postedDate,
    required this.applicationLink,
  });

  String get statusLabel {
    switch (status) {
      case JobStatus.open:
        return 'Open';
      case JobStatus.closed:
        return 'Closed';
      case JobStatus.draft:
        return 'Draft';
    }
  }

  factory JobModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JobModel(
      id: doc.id,
      title: data['title'] ?? '',
      department: data['department'] ?? '',
      description: data['description'] ?? '',
      requirements: data['requirements'] ?? '',
      openings: data['openings'] ?? 1,
      status: _statusFromString(data['status'] ?? 'open'),
      postedDate: (data['postedDate'] as Timestamp).toDate(),
      applicationLink: data['applicationLink'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'department': department,
    'description': description,
    'requirements': requirements,
    'openings': openings,
    'status': status.name,
    'postedDate': Timestamp.fromDate(postedDate),
    'applicationLink': applicationLink,
  };

  static JobStatus _statusFromString(String s) {
    switch (s) {
      case 'closed':
        return JobStatus.closed;
      case 'draft':
        return JobStatus.draft;
      default:
        return JobStatus.open;
    }
  }
}