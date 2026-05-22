// Central routing for notification taps (FCM, local notifications, in-app).
//
// Company letters: switch employee shell to My Letters and optionally
// open the PDF for `referenceId`.

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/company_letter_service.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../views/HR_views/hr_task_audit_screen.dart';
import '../views/employee_views/lead_review_screen.dart';
import '../views/employee_views/lead_task_receipt_screen.dart';
import '../views/employee_views/member_weekly_submit_screen.dart';
import '../widgets/letter_pdf.dart';

/// Root navigator for deep links when no local [BuildContext] is mounted.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Pending navigation consumed by [EmployeeDashboardWithSidebar].
class EmployeeLetterDeepLinkRequest {
  final String? letterId;
  const EmployeeLetterDeepLinkRequest({this.letterId});
}

class EmployeeLetterDeepLink {
  static final ValueNotifier<EmployeeLetterDeepLinkRequest?> pending =
      ValueNotifier(null);

  static void request({String? letterId}) {
    final id = letterId?.trim();
    pending.value = EmployeeLetterDeepLinkRequest(
      letterId: (id == null || id.isEmpty) ? null : id,
    );
  }
}

/// JSON payload stored on local notification taps.
String encodeNotificationPayload(Map<String, dynamic> data) =>
    jsonEncode(data);

Map<String, dynamic> decodeNotificationPayload(String? raw) {
  if (raw == null || raw.isEmpty) return {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  } catch (_) {}
  return {};
}

/// Opens a letter PDF by Firestore document id.
Future<void> openLetterById(BuildContext context, String letterId) async {
  final letter = await CompanyLetterService().getById(letterId);
  if (!context.mounted) return;
  if (letter == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Letter not found or was removed.')),
    );
    return;
  }
  await previewLetterPdf(letter);
}

/// Routes a notification data map to the appropriate screen.
Future<void> handleNotificationDeepLink(Map<String, dynamic> data) async {
  final type = (data['type'] ?? '').toString();

  if (type == 'company_letter') {
    final letterId = (data['referenceId'] ?? '').toString();
    EmployeeLetterDeepLink.request(
      letterId: letterId.isEmpty ? null : letterId,
    );

    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;

    final role =
        (ctx.read<AuthViewModel>().currentUser?.role ?? '').toLowerCase();
    if (role == 'hr' || role == 'admin') return;

    final nav = rootNavigatorKey.currentState;
    if (nav == null) return;

    final current = ModalRoute.of(ctx)?.settings.name;
    if (current != '/employee_dashboard') {
      nav.pushNamedAndRemoveUntil('/employee_dashboard', (route) => false);
    }
    return;
  }

  final taskId = (data['taskId'] ?? '').toString();
  if (taskId.isEmpty) return;

  final ctx = rootNavigatorKey.currentContext;
  if (ctx == null) return;

  try {
    final taskDoc = await FirebaseFirestore.instance
        .collection('tasks')
        .doc(taskId)
        .get();
    if (!taskDoc.exists || taskDoc.data()?['schemaVersion'] != 2) return;
    if (!ctx.mounted) return;

    final user = ctx.read<AuthViewModel>().currentUser;
    final role = (user?.role ?? '').toLowerCase();
    final isHR = role == 'hr' || role == 'admin';
    final eventId = (data['eventId'] ?? '').toString();
    final weekRaw = data['weekNumber'];
    final weekNumber = weekRaw is int
        ? weekRaw
        : int.tryParse(weekRaw?.toString() ?? '');

    Widget target;
    if (isHR) {
      target = HRTaskAuditScreen(
        taskId: taskId,
        highlightedEventId: eventId.isEmpty ? null : eventId,
        highlightedWeekNumber: weekNumber,
      );
    } else {
      final myUid = user?.uid ?? '';
      if (myUid.isEmpty) return;
      final me = await FirebaseFirestore.instance
          .collection('users')
          .doc(myUid)
          .get();
      if (!ctx.mounted) return;
      final myEmpId = (me.data()?['emp_id'] ?? '').toString();
      final leadId =
          (taskDoc.data()?['lead_id'] ?? '').toString().toLowerCase();
      final isLead = leadId.isNotEmpty && leadId == myEmpId.toLowerCase();
      if (isLead) {
        if (weekNumber != null &&
            (data['memberEmpId'] ?? '').toString().isNotEmpty) {
          target = LeadReviewScreen(taskId: taskId);
        } else {
          target = LeadTaskReceiptScreen(taskId: taskId);
        }
      } else {
        target = MemberWeeklySubmitScreen(taskId: taskId, empId: myEmpId);
      }
    }
    if (!ctx.mounted) return;
    Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => target));
  } catch (e) {
    debugPrint('[NotificationRouter] task deep-link failed: $e');
  }
}
