import 'package:cloud_firestore/cloud_firestore.dart';

enum MeetingStatus { pending, approved, rejected, completed, cancelled }

enum MeetingType { general, review, training, oneOnOne, event }

enum MeetingFormat { inPerson, virtual }

class MeetingModel {
  final String id;
  final String title;
  final DateTime dateTime;
  final String duration;
  final MeetingType type;
  final MeetingFormat format;
  final String location;
  final String description;
  final MeetingStatus status;
  final String organizerId;
  final String organizerName;
  final List<String> attendeeIds; // user IDs
  final List<String> attendeeNames;
  final bool isAllEmployees;
  final DateTime createdAt;
  final String? rejectionReason;
  final String? conclusion;
  final DateTime? cancelledAt;
  final String? cancellationReason;

  MeetingModel({
    required this.id,
    required this.title,
    required this.dateTime,
    required this.duration,
    required this.type,
    required this.format,
    required this.location,
    required this.description,
    required this.status,
    required this.organizerId,
    required this.organizerName,
    required this.attendeeIds,
    required this.attendeeNames,
    required this.isAllEmployees,
    required this.createdAt,
    this.rejectionReason,
    this.conclusion,
    this.cancelledAt,
    this.cancellationReason,
  });

  factory MeetingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MeetingModel(
      id: doc.id,
      title: data['title'] ?? '',
      dateTime: data['dateTime'] is Timestamp
          ? (data['dateTime'] as Timestamp).toDate()
          : DateTime.now(),
      duration: data['duration'] ?? '30m',
      type: MeetingType.values.firstWhere(
            (e) => e.name == data['type'],
        orElse: () => MeetingType.general,
      ),
      format: MeetingFormat.values.firstWhere(
            (e) => e.name == data['format'],
        orElse: () => MeetingFormat.inPerson,
      ),
      location: data['location'] ?? '',
      description: data['description'] ?? '',
      status: MeetingStatus.values.firstWhere(
            (e) => e.name == data['status'],
        orElse: () => MeetingStatus.pending,
      ),
      organizerId: data['organizerId'] ?? '',
      organizerName: data['organizerName'] ?? '',
      attendeeIds: List<String>.from(data['attendeeIds'] ?? []),
      attendeeNames: List<String>.from(data['attendeeNames'] ?? []),
      isAllEmployees: data['isAllEmployees'] ?? false,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      rejectionReason: data['rejectionReason'],
      conclusion: data['conclusion'] as String?,
      cancelledAt: data['cancelledAt'] is Timestamp
          ? (data['cancelledAt'] as Timestamp).toDate()
          : null,
      cancellationReason: data['cancellationReason'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'dateTime': Timestamp.fromDate(dateTime),
      'duration': duration,
      'type': type.name,
      'format': format.name,
      'location': location,
      'description': description,
      'status': status.name,
      'organizerId': organizerId,
      'organizerName': organizerName,
      'attendeeIds': attendeeIds,
      'attendeeNames': attendeeNames,
      'isAllEmployees': isAllEmployees,
      'createdAt': Timestamp.fromDate(createdAt),
      'rejectionReason': rejectionReason,
      if (conclusion != null) 'conclusion': conclusion,
      if (cancelledAt != null) 'cancelledAt': Timestamp.fromDate(cancelledAt!),
      if (cancellationReason != null) 'cancellationReason': cancellationReason,
    };
  }

  MeetingModel copyWith({
    MeetingStatus? status,
    String? rejectionReason,
    String? conclusion,
    DateTime? cancelledAt,
    String? cancellationReason,
  }) {
    return MeetingModel(
      id: id,
      title: title,
      dateTime: dateTime,
      duration: duration,
      type: type,
      format: format,
      location: location,
      description: description,
      status: status ?? this.status,
      organizerId: organizerId,
      organizerName: organizerName,
      attendeeIds: attendeeIds,
      attendeeNames: attendeeNames,
      isAllEmployees: isAllEmployees,
      createdAt: createdAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      conclusion: conclusion ?? this.conclusion,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
    );
  }
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final String role; // 'hr' or 'employee'
  final String? fcmToken;
  final String department;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.fcmToken,
    required this.department,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'employee',
      fcmToken: data['fcmToken'],
      department: data['department'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'fcmToken': fcmToken,
      'department': department,
    };
  }
}

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String meetingId;
  final bool isRead;
  final DateTime createdAt;
  final String type; // 'meeting_request', 'meeting_approved', 'meeting_rejected', 'new_meeting'

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.meetingId,
    required this.isRead,
    required this.createdAt,
    required this.type,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      meetingId: data['meetingId'] ?? '',
      isRead: data['isRead'] ?? false,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      type: data['type'] ?? '',
    );
  }
}