import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/meeting_model.dart';

class MeetingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // ─── Meetings ───────────────────────────────────────────────

  /// Stream of all meetings (for HR)
  Stream<List<MeetingModel>> streamAllMeetings() {
    return _firestore
        .collection('meetings')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => MeetingModel.fromFirestore(d)).toList());
  }

  /// Stream of pending meetings (for HR approval tab)
  Stream<List<MeetingModel>> streamPendingMeetings() {
    return _firestore
        .collection('meetings')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => MeetingModel.fromFirestore(d)).toList());
  }

  /// Stream of meetings for a specific employee —
  /// includes meetings where they are an attendee OR the organizer
  /// Stream of meetings for a specific employee —
  /// includes meetings where they are an attendee OR the organizer.
  /// Uses a StreamController so both Firestore queries run independently
  /// and never reset to "waiting" when the other emits.
  Stream<List<MeetingModel>> streamEmployeeMeetings(String userId) {
    List<MeetingModel> attendeeList = [];
    List<MeetingModel> organizerList = [];

    late StreamController<List<MeetingModel>> controller;

    void emit() {
      final Map<String, MeetingModel> merged = {};
      for (final m in [...attendeeList, ...organizerList]) {
        merged[m.id] = m;
      }
      final sorted = merged.values.toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
      if (!controller.isClosed) controller.add(sorted);
    }

    StreamSubscription? subAttendee;
    StreamSubscription? subOrganizer;

    controller = StreamController<List<MeetingModel>>.broadcast(
      onListen: () {
        subAttendee = _firestore
            .collection('meetings')
            .where('attendeeIds', arrayContains: userId)
            .snapshots()
            .listen((snap) {
          attendeeList =
              snap.docs.map((d) => MeetingModel.fromFirestore(d)).toList();
          emit();
        });

        subOrganizer = _firestore
            .collection('meetings')
            .where('organizerId', isEqualTo: userId)
            .snapshots()
            .listen((snap) {
          organizerList =
              snap.docs.map((d) => MeetingModel.fromFirestore(d)).toList();
          emit();
        });
      },
      onCancel: () {
        subAttendee?.cancel();
        subOrganizer?.cancel();
      },
    );

    return controller.stream;
  }

  /// Stream of meetings organized by this user
  Stream<List<MeetingModel>> streamOrganizedMeetings(String userId) {
    return _firestore
        .collection('meetings')
        .where('organizerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => MeetingModel.fromFirestore(d)).toList());
  }

  /// HR arranges a meeting (auto-approved, send notifications to attendees)
  Future<void> hrArrangeMeeting({
    required MeetingModel meeting,
    required List<UserModel> employees,
  }) async {
    final docRef = _firestore.collection('meetings').doc();
    final meetingWithId = MeetingModel(
      id: docRef.id,
      title: meeting.title,
      dateTime: meeting.dateTime,
      duration: meeting.duration,
      type: meeting.type,
      format: meeting.format,
      location: meeting.location,
      description: meeting.description,
      status: MeetingStatus.approved,
      organizerId: meeting.organizerId,
      organizerName: meeting.organizerName,
      attendeeIds: meeting.attendeeIds,
      attendeeNames: meeting.attendeeNames,
      isAllEmployees: meeting.isAllEmployees,
      createdAt: DateTime.now(),
    );

    final batch = _firestore.batch();
    batch.set(docRef, meetingWithId.toFirestore());

    // Create notification records for each attendee
    for (int i = 0; i < meeting.attendeeIds.length; i++) {
      final notifRef = _firestore.collection('notifications').doc();
      batch.set(notifRef, {
        'userId': meeting.attendeeIds[i],
        'title': '📅 New Meeting Scheduled',
        'body': 'HR has scheduled "${meeting.title}" on ${_formatDate(meeting.dateTime)}',
        'meetingId': docRef.id,
        'isRead': false,
        'createdAt': Timestamp.now(),
        'type': 'new_meeting',
      });
    }

    await batch.commit();

    // Send push notifications
    await _sendPushToUsers(
      userIds: meeting.attendeeIds,
      employees: employees,
      title: '📅 New Meeting Scheduled',
      body: 'HR has scheduled "${meeting.title}" on ${_formatDate(meeting.dateTime)}',
      data: {'meetingId': docRef.id, 'type': 'new_meeting'},
    );
  }

  /// Employee requests a meeting (goes to HR for approval)
  Future<void> employeeRequestMeeting({
    required MeetingModel meeting,
    required List<UserModel> hrUsers,
  }) async {
    final docRef = _firestore.collection('meetings').doc();

    // Make sure the organizer is also in attendeeIds so the meeting
    // appears in their own stream once approved
    final allAttendeeIds = {meeting.organizerId, ...meeting.attendeeIds}.toList();
    final allAttendeeNames = meeting.attendeeNames.contains(meeting.organizerName)
        ? meeting.attendeeNames
        : [meeting.organizerName, ...meeting.attendeeNames];

    final meetingWithOrganizer = MeetingModel(
      id: meeting.id,
      title: meeting.title,
      dateTime: meeting.dateTime,
      duration: meeting.duration,
      type: meeting.type,
      format: meeting.format,
      location: meeting.location,
      description: meeting.description,
      status: meeting.status,
      organizerId: meeting.organizerId,
      organizerName: meeting.organizerName,
      attendeeIds: allAttendeeIds,
      attendeeNames: allAttendeeNames,
      isAllEmployees: meeting.isAllEmployees,
      createdAt: meeting.createdAt,
    );

    final batch = _firestore.batch();
    batch.set(docRef, meetingWithOrganizer.toFirestore());

    // Notify all HR users about the new request
    for (final hr in hrUsers) {
      final notifRef = _firestore.collection('notifications').doc();
      batch.set(notifRef, {
        'userId': hr.id,
        'title': '🔔 New Meeting Request',
        'body': '${meeting.organizerName} has requested a meeting: "${meeting.title}"',
        'meetingId': docRef.id,
        'isRead': false,
        'createdAt': Timestamp.now(),
        'type': 'meeting_request',
      });
    }

    await batch.commit();

    // Push to HR
    await _sendPushToUsers(
      userIds: hrUsers.map((u) => u.id).toList(),
      employees: hrUsers,
      title: '🔔 New Meeting Request',
      body: '${meetingWithOrganizer.organizerName} requested "${meetingWithOrganizer.title}"',
      data: {'meetingId': docRef.id, 'type': 'meeting_request'},
    );
  }

  /// HR approves a meeting request
  Future<void> approveMeeting({
    required MeetingModel meeting,
    required List<UserModel> allUsers,
  }) async {
    final batch = _firestore.batch();

    // Update meeting status
    batch.update(_firestore.collection('meetings').doc(meeting.id), {
      'status': 'approved',
    });

    // Notify organizer + all attendees
    final notifyIds = {...meeting.attendeeIds, meeting.organizerId}.toList();
    for (final uid in notifyIds) {
      final notifRef = _firestore.collection('notifications').doc();
      batch.set(notifRef, {
        'userId': uid,
        'title': '✅ Meeting Approved',
        'body': '"${meeting.title}" has been approved for ${_formatDate(meeting.dateTime)}',
        'meetingId': meeting.id,
        'isRead': false,
        'createdAt': Timestamp.now(),
        'type': 'meeting_approved',
      });
    }

    await batch.commit();

    final notifyUsers = allUsers.where((u) => notifyIds.contains(u.id)).toList();
    await _sendPushToUsers(
      userIds: notifyIds,
      employees: notifyUsers,
      title: '✅ Meeting Approved',
      body: '"${meeting.title}" on ${_formatDate(meeting.dateTime)} is confirmed!',
      data: {'meetingId': meeting.id, 'type': 'meeting_approved'},
    );
  }

  /// HR rejects a meeting request
  Future<void> rejectMeeting({
    required MeetingModel meeting,
    required String reason,
    required List<UserModel> allUsers,
  }) async {
    final batch = _firestore.batch();

    batch.update(_firestore.collection('meetings').doc(meeting.id), {
      'status': 'rejected',
      'rejectionReason': reason,
    });

    // Notify organizer
    final notifRef = _firestore.collection('notifications').doc();
    batch.set(notifRef, {
      'userId': meeting.organizerId,
      'title': '❌ Meeting Request Rejected',
      'body': '"${meeting.title}" was rejected. Reason: $reason',
      'meetingId': meeting.id,
      'isRead': false,
      'createdAt': Timestamp.now(),
      'type': 'meeting_rejected',
    });

    await batch.commit();

    final organizer = allUsers.where((u) => u.id == meeting.organizerId).toList();
    await _sendPushToUsers(
      userIds: [meeting.organizerId],
      employees: organizer,
      title: '❌ Meeting Request Rejected',
      body: '"${meeting.title}" was not approved.',
      data: {'meetingId': meeting.id, 'type': 'meeting_rejected'},
    );
  }

  // ─── Users ───────────────────────────────────────────────────

  Future<List<UserModel>> getAllEmployees() async {
    final snap = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'employee')
        .get();
    return snap.docs.map((d) => UserModel.fromFirestore(d)).toList();
  }

  Future<List<UserModel>> getAllHRUsers() async {
    final snap = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'hr')
        .get();
    return snap.docs.map((d) => UserModel.fromFirestore(d)).toList();
  }

  Future<List<UserModel>> getAllUsers() async {
    final snap = await _firestore.collection('users').get();
    return snap.docs.map((d) => UserModel.fromFirestore(d)).toList();
  }

  // ─── Notifications ───────────────────────────────────────────

  Stream<List<NotificationModel>> streamNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map((d) => NotificationModel.fromFirestore(d)).toList());
  }

  Stream<int> streamUnreadCount(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.size);
  }

  Future<void> markNotificationRead(String notifId) async {
    await _firestore.collection('notifications').doc(notifId).update({'isRead': true});
  }

  Future<void> markAllNotificationsRead(String userId) async {
    final snap = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // ─── FCM Token ───────────────────────────────────────────────

  Future<void> saveUserFCMToken(String userId) async {
    final token = await _messaging.getToken();
    if (token != null) {
      await _firestore.collection('users').doc(userId).update({'fcmToken': token});
    }
  }

  // ─── Internal helpers ─────────────────────────────────────────

  Future<void> _sendPushToUsers({
    required List<String> userIds,
    required List<UserModel> employees,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    // In production, use Firebase Cloud Functions to send FCM.
    // This demonstrates the structure — call your Cloud Function endpoint:
    try {
      final tokens = employees
          .where((u) => userIds.contains(u.id) && u.fcmToken != null)
          .map((u) => u.fcmToken!)
          .toList();

      if (tokens.isEmpty) return;

      // Replace with your Cloud Function URL
      await http.post(
        Uri.parse('https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/sendNotification'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'tokens': tokens,
          'title': title,
          'body': body,
          'data': data,
        }),
      );
    } catch (_) {
      // Log silently — notifications are best-effort
    }
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }
}