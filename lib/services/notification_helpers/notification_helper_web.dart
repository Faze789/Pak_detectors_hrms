// lib/services/notification_helper_web.dart
// Used on web — browser Notification API via dart:html
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<void> initNotifications() async {
  // Request browser notification permission on init
  await html.Notification.requestPermission();
}

Future<void> showNotification({
  required String title,
  required String body,
}) async {
  final permission = await html.Notification.requestPermission();
  if (permission == 'granted') {
    html.Notification(title, body: body);
  }
}