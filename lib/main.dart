import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:hrms_app/services/payroll_service.dart';
import 'package:hrms_app/services/performance_service.dart';
import 'package:hrms_app/viewmodels/attendance_viewmodel.dart';
import 'package:hrms_app/viewmodels/branch_viewmodel.dart';
import 'package:hrms_app/viewmodels/document_viewmodel.dart';
import 'package:hrms_app/viewmodels/employee_viewmodel.dart';
import 'package:hrms_app/viewmodels/leave_viewmodel.dart';
import 'package:hrms_app/viewmodels/performance_viewmodel.dart';
import 'package:hrms_app/viewmodels/recruitment_viewmodel.dart';
import 'package:hrms_app/viewmodels/monthly_goal_viewmodel.dart';
import 'package:hrms_app/viewmodels/employee_report_viewmodel.dart';
import 'package:hrms_app/viewmodels/task_viewmodel.dart';
import 'package:hrms_app/views/HR_views/apply_screen.dart';
import 'package:hrms_app/views/HR_views/employee_screen.dart';
import 'package:hrms_app/views/HR_views/hr_task_audit_screen.dart';
import 'package:hrms_app/views/employee_views/lead_review_screen.dart';
import 'package:hrms_app/views/employee_views/lead_task_receipt_screen.dart';
import 'package:hrms_app/views/employee_views/member_weekly_submit_screen.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'views/login_screen.dart';
import 'views/signup_screen.dart';
import 'views/splash_screen.dart';
import 'views/HR_views/sidebar_wrapper/hr_sidebar_wrapper.dart';
import 'views/employee_views/sidebar_wrapper/emp_sidebar_wrapper.dart';
import 'services/auth_service.dart';
import 'viewmodels/auth_viewmodel.dart';

// ─────────────────────────────────────────────────────────────
// FCM
// ─────────────────────────────────────────────────────────────
final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel _barrierChannel = AndroidNotificationChannel(
  'barrier_reports',
  'Barrier Reports',
  description: 'Notifications for reported barriers',
  importance: Importance.high,
  playSound: true,
);

const AndroidNotificationChannel _taskChannel = AndroidNotificationChannel(
  'task_notifications',
  'Task Notifications',
  description: 'Notifications for task updates and requests',
  importance: Importance.high,
  playSound: true,
);

// ─── HR system-alert channel ─────────────────────────────────────────────────
//
// Exclusive channel for genuine backend failures (uncaught cron errors,
// real FCM delivery failures, data-integrity issues). Routine FCM token
// hygiene NO LONGER routes through this channel after the spam-suppression
// fix — so anything that lands here is something HR should actually look at.
//
// Properties:
//   • Importance.max — heads-up notification, bypasses ambient-only DND
//     where the OS allows it.
//   • enableVibration + enableLights — extra perception channels.
//   • Custom sound: tries `hr_alert` (drop a file at
//     android/app/src/main/res/raw/hr_alert.mp3 if you want a distinct
//     tone; otherwise the device's default channel sound plays).
const AndroidNotificationChannel _hrSystemAlertChannel =
    AndroidNotificationChannel(
  'hr_system_alerts',
  'System Alerts (HR)',
  description:
      'Genuine backend failures — cron crashes, FCM delivery failures, '
      'data-integrity issues. HR-only.',
  importance: Importance.max,
  playSound: true,
  // RawResourceAndroidNotificationSound looks for
  // `android/app/src/main/res/raw/hr_alert.mp3`. If the file is missing
  // the Android system falls back to the channel default sound — no
  // crash, just less distinct.
  sound: RawResourceAndroidNotificationSound('hr_alert'),
  enableVibration: true,
  enableLights: true,
  ledColor: Color(0xFFDC2626), // red LED
);

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final data = message.data;
  if (data['type'] == 'barrier_report_cc') {
    _showLocalNotification(
      title: '📋 Barrier Report (CC)',
      body:
          '${data['reporterName'] ?? 'A colleague'} sent a barrier report — you are CC\'d.',
    );
  }
}

void _showTaskNotification({required String title, required String body}) {
  _localNotifications.show(
    id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title: title,
    body: body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        _taskChannel.id,
        _taskChannel.name,
        channelDescription: _taskChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    ),
  );
}

void _showLocalNotification({required String title, required String body}) {
  _localNotifications.show(
    id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title: title,
    body: body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        _barrierChannel.id,
        _barrierChannel.name,
        channelDescription: _barrierChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    ),
  );
}

/// Foreground display for HR system alerts on the dedicated channel.
/// Background-delivered alerts use the same `hr_system_alerts` channelId
/// passed by the FCM payload, so background and foreground stay consistent.
void _showHrSystemAlertNotification({
  required String title,
  required String body,
}) {
  _localNotifications.show(
    id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title: title,
    body: body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        _hrSystemAlertChannel.id,
        _hrSystemAlertChannel.name,
        channelDescription: _hrSystemAlertChannel.description,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('hr_alert'),
        enableVibration: true,
        enableLights: true,
        ledColor: const Color(0xFFDC2626),
        ledOnMs: 1000,
        ledOffMs: 500,
        icon: '@mipmap/ic_launcher',
        // Full-screen-intent or fullScreenIntent: true could be added for
        // truly critical alerts — leave off by default, it's quite invasive.
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// MAIN
// ─────────────────────────────────────────────────────────────
void main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await _localNotifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(_barrierChannel);
  await _localNotifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(_taskChannel);
  // Dedicated HR system-alert channel — see the channel declaration
  // comment above for why this exists.
  await _localNotifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(_hrSystemAlertChannel);

  await _localNotifications.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
    onDidReceiveNotificationResponse: (details) {
      debugPrint('[LocalNotif] tapped: ${details.payload}');
    },
  );

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  // ✅ Read URL path BEFORE runApp and decide which app to mount.
  // /apply/{jobId} → PublicApplyApp (no auth, no providers, no redirect)
  // anything else  → HRMSApp       (full authenticated app)
  final String path = kIsWeb ? Uri.base.path : '/';
  debugPrint('[Main] path = $path');

  final segments = Uri.parse(path).pathSegments;
  final bool isApplyRoute = segments.length >= 2 && segments[0] == 'apply';

  if (isApplyRoute) {
    final jobId = segments[1];
    debugPrint('[Main] → Public apply route jobId=$jobId');
    runApp(PublicApplyApp(jobId: jobId));
  } else {
    debugPrint('[Main] → Authenticated HRMS app');
    runApp(const HRMSApp());
  }
}

// ─────────────────────────────────────────────────────────────
// PUBLIC APPLY APP
// Completely isolated widget tree.
// No AuthViewModel, no EmployeeViewModel, no FCM listeners,
// no redirects — candidates are 100% sandboxed here.
// ─────────────────────────────────────────────────────────────
class PublicApplyApp extends StatelessWidget {
  final String jobId;
  const PublicApplyApp({super.key, required this.jobId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ApplyViewModel(),
      child: MaterialApp(
        title: 'Job Application',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1E3A5F),
            brightness: Brightness.light,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A5F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        // ✅ Goes straight to ApplyScreen — no splash, no auth,
        //    no navigator stack that could redirect anywhere
        home: ApplyScreen(jobId: jobId),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HRMS APP — full authenticated app
// Only mounted when path is NOT /apply/*
// ─────────────────────────────────────────────────────────────
class HRMSApp extends StatelessWidget {
  const HRMSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider<AuthViewModel>(
          create: (ctx) => AuthViewModel(authService: ctx.read<AuthService>()),
        ),
        ChangeNotifierProxyProvider<AuthViewModel, EmployeeViewModel>(
          create: (ctx) =>
              EmployeeViewModel(authViewModel: ctx.read<AuthViewModel>()),
          update: (ctx, authVM, prev) =>
              prev ?? EmployeeViewModel(authViewModel: authVM),
        ),
        ChangeNotifierProvider(create: (_) => TaskViewModel()),
        ChangeNotifierProvider(create: (_) => MonthlyGoalViewModel()),
        ChangeNotifierProvider(create: (_) => EmployeeReportViewModel()),
        ChangeNotifierProvider(create: (_) => AttendanceViewModel()),
        ChangeNotifierProvider(create: (_) => BranchViewModel()),
        Provider<PayrollService>(create: (_) => PayrollService()),
        ChangeNotifierProvider(create: (_) => LeaveViewModel()),
        ChangeNotifierProvider(create: (_) => DocumentViewModel()),
        ChangeNotifierProvider(create: (_) => RecruitmentViewModel()),
        ChangeNotifierProvider(create: (_) => ApplyViewModel()),
        Provider<PerformanceService>(create: (_) => PerformanceService()),
        ChangeNotifierProxyProvider<PerformanceService, HRPerformanceViewModel>(
          create: (ctx) => HRPerformanceViewModel(
            service: ctx.read<PerformanceService>(),
            hrUserId: '',
          ),
          update: (ctx, svc, prev) =>
              prev ?? HRPerformanceViewModel(service: svc, hrUserId: ''),
        ),
        ChangeNotifierProxyProvider2<
          AuthViewModel,
          PerformanceService,
          EmployeePerformanceViewModel
        >(
          create: (ctx) => EmployeePerformanceViewModel(
            service: ctx.read<PerformanceService>(),
            employeeId: ctx.read<AuthViewModel>().currentUser?.uid ?? '',
            employeeName: '',
            employeeRole: '',
          ),
          update: (ctx, authVM, svc, prev) {
            final uid = authVM.currentUser?.uid ?? '';
            if (uid.isEmpty) return prev!;
            if (prev == null || prev.employeeId != uid) {
              return EmployeePerformanceViewModel(
                service: svc,
                employeeId: uid,
                employeeName: prev?.employeeName ?? '',
                employeeRole: prev?.employeeRole ?? '',
              );
            }
            return prev;
          },
        ),
      ],
      child: MaterialApp(
        title: 'HRMS',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Inter',
          primarySwatch: MaterialColor(0xFF6366F1, const <int, Color>{
            50: Color(0xFFF0F4FF),
            100: Color(0xFFE0E7FF),
            200: Color(0xFFC7D2FE),
            300: Color(0xFFA5B4FC),
            400: Color(0xFF818CF8),
            500: Color(0xFF6366F1),
            600: Color(0xFF4F46E5),
            700: Color(0xFF4338CA),
            800: Color(0xFF3730A3),
            900: Color(0xFF312E81),
          }),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6366F1),
            brightness: Brightness.light,
          ),
          appBarTheme: const AppBarTheme(
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            backgroundColor: Color(0xFF6366F1),
            surfaceTintColor: Colors.transparent,
          ),
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            surfaceTintColor: Colors.transparent,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
            ),
            labelStyle: const TextStyle(color: Colors.grey),
            hintStyle: TextStyle(color: Colors.grey[500]),
          ),
          textTheme: const TextTheme(
            displayLarge: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            displayMedium: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            displaySmall: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            headlineLarge: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            headlineMedium: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            headlineSmall: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            titleLarge: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            titleMedium: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            titleSmall: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            bodyLarge: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.normal,
              color: Colors.black87,
            ),
            bodyMedium: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.normal,
              color: Colors.black87,
            ),
            bodySmall: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.normal,
              color: Colors.black87,
            ),
            labelLarge: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
            labelMedium: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
            labelSmall: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
        home: const _AppInit(),
        routes: {
          '/splash': (ctx) => const SplashScreen(),
          '/login': (ctx) => const LoginScreen(),
          '/signup': (ctx) => const SignupScreen(),
          '/hr_dashboard': (ctx) => const HRDashboardWithSidebar(),
          '/employee_dashboard': (ctx) => const EmployeeDashboardWithSidebar(),
          '/employee_list': (ctx) => const EmployeeListView(),
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _AppInit — auth + FCM bootstrap for authenticated app only
// ─────────────────────────────────────────────────────────────
class _AppInit extends StatefulWidget {
  const _AppInit();

  @override
  State<_AppInit> createState() => _AppInitState();
}

class _AppInitState extends State<_AppInit> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notifSub;
  bool _isFirstNotifSnapshot = true;

  @override
  void initState() {
    super.initState();
    _boot();
    _listenForegroundMessages();
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    super.dispose();
  }

  Future<void> _boot() async {
    await context.read<AuthViewModel>().initialize();
    if (!mounted) return;

    await _saveFcmToken();
    if (!mounted) return;

    FirebaseMessaging.instance.onTokenRefresh.listen(_updateFcmToken);
    if (!mounted) return;

    final authViewModel = context.read<AuthViewModel>();
    if (authViewModel.isLoggedIn && authViewModel.currentUser != null) {
      // Start listening for task notifications for this user
      _startTaskNotificationListener(authViewModel.currentUser!.uid);

      final role = authViewModel.currentUser!.role;
      if (role == 'hr') {
        Navigator.of(context).pushReplacementNamed('/hr_dashboard');
      } else {
        Navigator.of(context).pushReplacementNamed('/employee_dashboard');
      }
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  /// Listens to Firestore for new task_notifications targeting this user
  /// and shows a local pop-up notification in real time.
  void _startTaskNotificationListener(String uid) async {
    // Get the user's emp_id
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final empId = (userDoc.data()?['emp_id'] ?? '').toString().toLowerCase();
    if (empId.isEmpty) return;

    _notifSub = FirebaseFirestore.instance
        .collection('task_notifications')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .listen((snapshot) {
          // Skip the first snapshot (existing data)
          if (_isFirstNotifSnapshot) {
            _isFirstNotifSnapshot = false;
            return;
          }

          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data();
              if (data == null) continue;

              final leadId = (data['lead_id'] ?? '').toString().toLowerCase();
              final isRead = data['read'] == true;

              // Only show for this user + unread
              if (leadId == empId && !isRead) {
                final title = data['title'] ?? 'Task Notification';
                final body = data['body'] ?? '';
                _showTaskNotification(title: title, body: body);
              }
            }
          }
        });
  }

  Future<void> _saveFcmToken() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );
      debugPrint('[FCM] Permission: ${settings.authorizationStatus}');
      if (!mounted) return;
      final uid = context.read<AuthViewModel>().currentUser?.uid;
      if (uid == null || uid.isEmpty) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      if (!mounted) return;
      await _updateFcmToken(token);
    } catch (e) {
      debugPrint('[FCM] Failed to save token: $e');
    }
  }

  Future<void> _updateFcmToken(String token) async {
    try {
      if (!mounted) return;
      final uid = context.read<AuthViewModel>().currentUser?.uid;
      if (uid == null || uid.isEmpty) return;
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmToken': token,
      });
      debugPrint('[FCM] Token saved for $uid');
    } catch (e) {
      debugPrint('[FCM] Failed to update token: $e');
    }
  }

  void _listenForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      final data = message.data;
      final title = notification?.title ?? data['title'] ?? 'HRMS';
      final body = notification?.body ?? data['body'] ?? '';
      if (title.isNotEmpty && body.isNotEmpty) {
        // Route by `type`:
        //   • hr_alert  → dedicated HR system-alert channel (max
        //                  importance, distinct sound)
        //   • barrier_* → barrier reports channel
        //   • everything else (task / attendance / leave / schedule)
        //                → standard task-notifications channel
        final type = (data['type'] ?? '').toString();
        if (type == 'hr_alert') {
          _showHrSystemAlertNotification(title: title, body: body);
        } else if (type.startsWith('barrier')) {
          _showLocalNotification(title: title, body: body);
        } else {
          _showTaskNotification(title: title, body: body);
        }
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage msg) {
      debugPrint('[FCM Tapped] type: ${msg.data['type']}');
      _deepLinkFromFcm(msg.data);
    });
  }

  /// FCM tap → deep-link into the v2 hierarchical task screens when the
  /// payload carries `taskId`. Falls back to a no-op for legacy / non-task
  /// notifications since the in-app notifications screen handles those.
  Future<void> _deepLinkFromFcm(Map<String, dynamic> data) async {
    final taskId = (data['taskId'] ?? '').toString();
    if (taskId.isEmpty) return;
    if (!mounted) return;
    try {
      final taskDoc = await FirebaseFirestore.instance
          .collection('tasks')
          .doc(taskId)
          .get();
      if (!taskDoc.exists || taskDoc.data()?['schemaVersion'] != 2) return;
      if (!mounted) return;

      final user = context.read<AuthViewModel>().currentUser;
      final role = (user?.role ?? '').toLowerCase();
      final isHR = role == 'hr';
      final eventId = (data['eventId'] ?? '').toString();
      final weekRaw = data['weekNumber'];
      final weekNumber = weekRaw is int
          ? weekRaw
          : int.tryParse(weekRaw?.toString() ?? '');

      Widget? target;
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
        if (!mounted) return;
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
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => target!));
    } catch (e) {
      debugPrint('[FCM deep-link] failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) => const SplashScreen();
}
