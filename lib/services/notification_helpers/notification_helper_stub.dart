// lib/services/notification_helper_stub.dart
// Mobile implementation — flutter_local_notifications ^20.1.0

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin _plugin =
FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  const androidSettings =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  await _plugin.initialize(
    settings: const InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    ),
  );
}

Future<void> showNotification({
  required String title,
  required String body,
}) async {
  const androidDetails = AndroidNotificationDetails(
    'leave_channel',
    'Leave Notifications',
    channelDescription: 'Notifications for leave requests and approvals',
    importance: Importance.high,
    priority: Priority.high,
    showWhen: true,
  );

  const iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  await _plugin.show(
    id: DateTime.now().millisecondsSinceEpoch ~/ 1000 % 2147483647,
    title:title,
    body: body,
    notificationDetails: const NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    ),
  );
}