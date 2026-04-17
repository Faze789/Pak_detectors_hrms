// ============================================================
// PERFORMANCE VIEWMODELS — HR + Employee
// CHANGES:
//  • markTaskStatus / handleReminderResponse accept teamRemarks
//  • teamRemarks stored directly in the task document (no new
//    collection — stored as a field on the existing task doc)
//  • Firestore rules must add 'teamRemarks' to the allowlist:
//      ['status','title','description','completedAt','dueDate','teamRemarks']
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/performance_models.dart';
import '../services/performance_service.dart';

// ─────────────────────────────────────────────────────────────
// EMPLOYEE CONTACT  (used by barrier dialog)
// ─────────────────────────────────────────────────────────────

class EmployeeContact {
  final String uid;
  final String name;
  final String email;
  final String? fcmToken;

  const EmployeeContact({
    required this.uid,
    required this.name,
    required this.email,
    this.fcmToken,
  });

  factory EmployeeContact.fromMap(String uid, Map<String, dynamic> m) =>
      EmployeeContact(
        uid: uid,
        name: (m['name'] as String? ?? '').trim(),
        email: (m['email'] as String? ?? '').trim(),
        fcmToken: m['fcmToken'] as String?,
      );
}

// ═══════════════════════════════════════════════════════════════
// HR VIEWMODEL
// ═══════════════════════════════════════════════════════════════

enum HRTab { dashboard, adhoc, quarterly, goals, rules }

class HRPerformanceViewModel extends ChangeNotifier {
  final PerformanceService _service;
  final String hrUserId;

  bool _disposed = false;

  HRPerformanceViewModel({
    required PerformanceService service,
    required this.hrUserId,
  }) : _service = service {
    _init();
  }

  // ── State ──────────────────────────────────────────────────
  HRTab activeTab = HRTab.dashboard;
  bool isLoading = false;
  String? errorMessage;
  String? successMessage;

  List<Map<String, dynamic>> employees = [];
  List<QuarterlyGoalModel> allGoals = [];
  List<EmployeeGoalModel> allEmployeeGoals = [];
  List<BarrierModel> barriers = [];
  PerformanceRulesModel? rules;
  List<UnscheduledEntry> unscheduledTasks = [];

  bool showQuarterlyForm = false;
  bool showUnscheduledForm = false;
  bool showEmployeeGoalForm = false;

  QuarterlyGoalModel? selectedGoal;
  List<WeeklyTaskModel> weeklyTasksTemp = [];

  final List<StreamSubscription<dynamic>> _subs = [];

  // ── Init ───────────────────────────────────────────────────
  void _init() {
    _loadEmployees();
    _watchGoals();
    _watchEmployeeGoalDocs();
    _watchRules();
    _watchBarriers();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void setTab(HRTab tab) {
    activeTab = tab;
    _notify();
  }

  Future<void> refresh() async {
    if (_disposed) return;
    isLoading = true;
    _notify();
    _init();
  }

  // ── Employees ──────────────────────────────────────────────
  Future<void> _loadEmployees() async {
    _setLoading(true);
    try {
      employees = await _service.getAllEmployees();
    } catch (e) {
      if (!_disposed) errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // ── Goals ──────────────────────────────────────────────────
  void _watchGoals() {
    final sub = _service.watchAllGoals().listen((goals) {
      if (_disposed) return;
      allGoals = goals;
      _refreshUnscheduledTasks();
      _notify();
    });
    _subs.add(sub);
  }

  void _watchEmployeeGoalDocs() {
    final sub = _service.watchAllEmployeeGoalsDocs().listen((list) {
      if (_disposed) return;
      allEmployeeGoals = list;
      _notify();
    });
    _subs.add(sub);
  }

  Future<void> _refreshUnscheduledTasks() async {
    final entries = <UnscheduledEntry>[];
    for (final goal in allGoals) {
      final tasks = await _service.getUnscheduledTasksForGoal(goal.id);
      for (final task in tasks) {
        entries.add(
          UnscheduledEntry(
            task: task,
            goalTitle: goal.title,
            empName: goal.employeeName,
          ),
        );
      }
    }
    try {
      final standaloneTasks = await _service.getAllStandaloneTasks();
      for (final task in standaloneTasks) {
        final emp = employees.firstWhere(
          (e) => e['id'] == task.employeeId,
          orElse: () => <String, dynamic>{},
        );
        entries.add(
          UnscheduledEntry(
            task: task,
            goalTitle: task.attachmentType == 'currentWeek'
                ? 'This Week — Standalone'
                : 'Upcoming Week — Standalone',
            empName: emp['name'] as String? ?? task.employeeId,
          ),
        );
      }
    } catch (_) {}
    if (_disposed) return;
    unscheduledTasks = entries;
    _notify();
  }

  List<QuarterlyGoalModel> goalsForEmployee(String empId) =>
      allGoals.where((g) => g.employeeId == empId).toList();

  List<EmployeeGoalModel> employeeGoalsFor(String empId) =>
      allEmployeeGoals.where((g) => g.employeeId == empId).toList();

  // ── Assign employee goal (`goals` collection) ───────────────
  Future<void> assignEmployeeGoal({
    required String employeeId,
    required String title,
    required String description,
    required GoalCadence cadence,
    required TaskPriority priority,
    required DateTime dueDate,
  }) async {
    final emp = employees.firstWhere(
      (e) => e['id'] == employeeId,
      orElse: () => {},
    );
    _setLoading(true);
    try {
      final goal = EmployeeGoalModel(
        id: '',
        employeeId: employeeId,
        employeeName: emp['name'] ?? '',
        title: title,
        description: description,
        cadence: cadence,
        priority: priority,
        status: GoalStatus.notStarted,
        dueDate: dueDate,
        completedAt: null,
        createdAt: DateTime.now(),
        createdBy: hrUserId,
      );
      await _service.createEmployeeGoal(goal);
      if (!_disposed) {
        showEmployeeGoalForm = false;
        successMessage = 'Goal assigned!';
      }
    } catch (e) {
      if (!_disposed) errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteEmployeeGoalDoc(String goalId) async {
    _setLoading(true);
    try {
      await _service.deleteEmployeeGoalDoc(goalId);
      if (!_disposed) successMessage = 'Goal removed.';
    } catch (e) {
      if (!_disposed) errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // ── Assign Quarterly Goal ──────────────────────────────────
  Future<void> assignQuarterlyGoal({
    required String employeeId,
    required String title,
    required String description,
    required GoalCategory category,
    required DateTime startDate,
    required DateTime endDate,
    required double weight,
  }) async {
    final emp = employees.firstWhere(
      (e) => e['id'] == employeeId,
      orElse: () => {},
    );
    _setLoading(true);
    try {
      final goal = QuarterlyGoalModel(
        id: '',
        employeeId: employeeId,
        employeeName: emp['name'] ?? '',
        title: title,
        description: description,
        category: category,
        startDate: startDate,
        endDate: endDate,
        weight: weight,
        status: GoalStatus.notStarted,
        currentProgress: 0,
        createdAt: DateTime.now(),
        createdBy: hrUserId,
      );
      await _service.assignQuarterlyGoal(goal);
      if (!_disposed) {
        showQuarterlyForm = false;
        successMessage = 'Quarterly task assigned!';
      }
    } catch (e) {
      if (!_disposed) errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // ── deleteGoal ─────────────────────────────────────────────
  Future<void> deleteGoal(String goalId) async {
    _setLoading(true);
    try {
      final db = FirebaseFirestore.instance;
      final tasksSnap = await db
          .collection('quarterly_goals')
          .doc(goalId)
          .collection('weekly_tasks')
          .get();

      if (tasksSnap.docs.isNotEmpty) {
        const chunkSize = 400;
        for (int i = 0; i < tasksSnap.docs.length; i += chunkSize) {
          final batch = db.batch();
          final chunk = tasksSnap.docs.skip(i).take(chunkSize);
          for (final doc in chunk) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        }
      }
      await _service.deleteGoal(goalId);
      if (!_disposed) successMessage = 'Task deleted.';
    } catch (e) {
      if (!_disposed) errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // ── Assign Unscheduled Task ────────────────────────────────
  Future<void> assignUnscheduledTask({
    required String goalId,
    required String employeeId,
    required String title,
    required String description,
    required DateTime dueDate,
    required TaskPriority priority,
    String attachmentType = 'quarterly',
  }) async {
    _setLoading(true);
    try {
      final task = WeeklyTaskModel(
        id: '',
        goalId: goalId,
        employeeId: employeeId,
        weekNumber: 0,
        title: title,
        description: description,
        dueDate: dueDate,
        status: TaskStatus.pending,
        isUnscheduled: true,
        priority: priority,
        attachmentType: attachmentType,
      );
      await _service.assignUnscheduledTask(goalId: goalId, task: task);
      if (!_disposed) {
        showUnscheduledForm = false;
        successMessage = 'Unscheduled task assigned!';
      }
      await _refreshUnscheduledTasks();
    } catch (e) {
      if (!_disposed) errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // ── Weekly Breakdown ───────────────────────────────────────
  int maxWeeksForGoal(QuarterlyGoalModel goal) =>
      goal.endDate.difference(goal.startDate).inDays ~/ 7;

  void openWeeklyBreakdown(QuarterlyGoalModel goal) {
    selectedGoal = goal;
    weeklyTasksTemp = [];
    _notify();
    _service.watchTasksForGoal(goal.id).first.then((tasks) {
      if (_disposed) return;
      weeklyTasksTemp = List.from(tasks);
      _notify();
    });
  }

  void updateTempTask(int index, WeeklyTaskModel updated) {
    weeklyTasksTemp[index] = updated;
    _notify();
  }

  Future<void> saveWeeklyBreakdown() async {
    if (selectedGoal == null) return;
    final toSave = weeklyTasksTemp
        .where((t) => t.title.trim().isNotEmpty || t.id.isNotEmpty)
        .toList();
    if (toSave.isEmpty) {
      if (!_disposed) errorMessage = 'Please add at least one task title';
      _notify();
      return;
    }
    _setLoading(true);
    try {
      await _service.createWeeklyTasks(selectedGoal!.id, toSave);
      if (!_disposed) {
        selectedGoal = null;
        weeklyTasksTemp = [];
        successMessage = 'Weekly plan saved!';
      }
    } catch (e) {
      if (!_disposed) errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // ── Rules ──────────────────────────────────────────────────
  void _watchRules() {
    final sub = _service.watchPerformanceRules().listen((r) {
      if (_disposed) return;
      rules = r;
      _notify();
    });
    _subs.add(sub);
  }

  Future<void> saveRules(PerformanceRulesModel updated) async {
    _setLoading(true);
    try {
      await _service.savePerformanceRules(updated, hrUserId);
      if (!_disposed) successMessage = 'Rules updated!';
    } catch (e) {
      if (!_disposed) errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // ── Barriers ───────────────────────────────────────────────
  void _watchBarriers() {
    final sub = _service.watchAllBarriers().listen((b) {
      if (_disposed) return;
      barriers = b;
      _notify();
    });
    _subs.add(sub);
  }

  // ── Helpers ────────────────────────────────────────────────
  void _setLoading(bool v) {
    if (_disposed) return;
    isLoading = v;
    _notify();
  }

  void clearMessages() {
    if (_disposed) return;
    errorMessage = null;
    successMessage = null;
    _notify();
  }

  set showUnscheduledFormValue(bool v) {
    showUnscheduledForm = v;
    _notify();
  }

  set showQuarterlyFormValue(bool v) {
    showQuarterlyForm = v;
    _notify();
  }

  set showEmployeeGoalFormValue(bool v) {
    showEmployeeGoalForm = v;
    _notify();
  }
}

// ═══════════════════════════════════════════════════════════════
// EMPLOYEE VIEWMODEL
// ═══════════════════════════════════════════════════════════════

class EmployeePerformanceViewModel extends ChangeNotifier {
  final PerformanceService _service;
  final String employeeId;

  String employeeName;
  String employeeRole;

  bool _disposed = false;

  EmployeePerformanceViewModel({
    required PerformanceService service,
    required this.employeeId,
    required this.employeeName,
    required this.employeeRole,
  }) : _service = service {
    _init();
  }

  // ── State ──────────────────────────────────────────────────
  bool isLoading = false;
  String? errorMessage;
  String? successMessage;

  List<QuarterlyGoalModel> goals = [];
  List<EmployeeGoalModel> employeeGoals = [];
  List<WeeklyTaskModel> currentWeekTasks = [];
  MonthlyDeductionModel? currentMonthDeduction;
  PerformanceRulesModel? rules;
  List<BarrierModel> barriers = [];

  QuarterlyGoalModel? selectedGoal;
  List<WeeklyTaskModel> weeklyTasksTemp = [];

  bool showWeeklyReminder = false;
  WeeklyTaskModel? reminderTask;
  QuarterlyGoalModel? reminderGoal;

  Timer? _reminderTimer;
  final List<StreamSubscription<dynamic>> _subs = [];

  /// First snapshot received from quarterly_goals stream for this employee.
  bool quarterlyStreamReady = false;

  // ── Init ───────────────────────────────────────────────────
  void _init() {
    _watchOwnProfile();
    _watchGoals();
    _watchEmployeeGoalDocs();
    _watchRules();
    _watchBarriers();
    _watchStandaloneTasks();
    _loadCurrentWeekTasks();
    _loadCurrentMonthDeduction();
  }

  Future<void> refresh() async {
    if (_disposed) return;
    isLoading = true;
    _notify();
    _init();
  }

  @override
  void dispose() {
    _disposed = true;
    _reminderTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ── Own profile ────────────────────────────────────────────
  void _watchOwnProfile() {
    final sub = _service.watchEmployeeProfile(employeeId).listen((data) {
      if (_disposed) return;
      if (data.isNotEmpty) {
        final name = (data['name'] ?? data['fullName'] ?? '').toString().trim();
        final role =
            (data['role'] ?? data['designation'] ?? data['jobTitle'] ?? '')
                .toString()
                .trim();
        if (name.isNotEmpty) employeeName = name;
        if (role.isNotEmpty) employeeRole = role;
        _notify();
      }
    }, onError: (_) {});
    _subs.add(sub);
  }

  // ── Goals ──────────────────────────────────────────────────
  void _watchGoals() {
    final sub = _service
        .watchEmployeeGoals(employeeId)
        .listen(
          (g) {
            if (_disposed) return;
            goals = g;
            quarterlyStreamReady = true;
            _notify();
            _scheduleReminderCheck();
          },
          onError: (_) {
            if (_disposed) return;
            quarterlyStreamReady = true;
            _notify();
          },
        );
    _subs.add(sub);
  }

  void _watchEmployeeGoalDocs() {
    final sub = _service.watchEmployeeGoalsDocs(employeeId).listen((list) {
      if (_disposed) return;
      employeeGoals = list;
      _notify();
    });
    _subs.add(sub);
  }

  // ── Rules ──────────────────────────────────────────────────
  void _watchRules() {
    final sub = _service.watchPerformanceRules().listen((r) {
      if (_disposed) return;
      rules = r;
      _notify();
    });
    _subs.add(sub);
  }

  // ── Standalone tasks ───────────────────────────────────────
  void _watchStandaloneTasks() {
    final sub = _service.watchStandaloneTasksForEmployee(employeeId).listen((
      standaloneTasks,
    ) {
      if (_disposed) return;
      currentWeekTasks = [
        ...currentWeekTasks.where(
          (t) =>
              t.attachmentType != 'currentWeek' &&
              t.attachmentType != 'upcomingWeek',
        ),
        ...standaloneTasks,
      ];
      _notify();
    });
    _subs.add(sub);
  }

  // ── Current week tasks ─────────────────────────────────────
  Future<void> _loadCurrentWeekTasks() async {
    try {
      final tasks = await _service.getTasksForCurrentWeek(employeeId);
      if (_disposed) return;
      currentWeekTasks = tasks;
      _notify();
    } catch (e) {
      if (_disposed) return;
      errorMessage = e.toString();
      _notify();
    }
  }

  // ── Current month deduction ────────────────────────────────
  Future<void> _loadCurrentMonthDeduction() async {
    final d = await _service.getCurrentMonthDeduction(employeeId);
    if (_disposed) return;
    currentMonthDeduction = d;
    _notify();
  }

  // ── Weekly reminder ────────────────────────────────────────
  void _scheduleReminderCheck() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_disposed || showWeeklyReminder) return;
      for (final goal in goals) {
        final pending = currentWeekTasks.where(
          (t) => t.goalId == goal.id && t.status == TaskStatus.pending,
        );
        if (pending.isNotEmpty) {
          reminderGoal = goal;
          reminderTask = pending.first;
          showWeeklyReminder = true;
          _notify();
          break;
        }
      }
    });
  }

  // ── markTaskStatus ─────────────────────────────────────────
  //
  // [teamRemarks] is a list of {name, remark} maps entered by the
  // employee before marking a task as completed. Stored directly in
  // the existing task document — no new collection created.
  //
  // ⚠️  Add 'teamRemarks' to your Firestore security rule allowlist:
  //   ['status','title','description','completedAt','dueDate','teamRemarks']
  Future<void> markTaskStatus({
    required String goalId,
    required String taskId,
    required TaskStatus status,
    List<Map<String, String>>? teamRemarks, // ← NEW
  }) async {
    if (taskId.trim().isEmpty) {
      if (!_disposed) {
        errorMessage =
            'Cannot update task: task ID is missing. '
            'Save the plan first.';
      }
      _notify();
      return;
    }

    _setLoading(true);
    try {
      if (goalId.trim().isEmpty) {
        await _markStandaloneTaskStatus(
          taskId: taskId,
          status: status,
          teamRemarks: teamRemarks,
        );
      } else {
        await _markQuarterlyWeeklyTaskStatus(
          goalId: goalId,
          taskId: taskId,
          status: status,
          teamRemarks: teamRemarks,
        );
      }

      if (_disposed) return;
      showWeeklyReminder = false;
      reminderTask = null;
      reminderGoal = null;
      await _loadCurrentWeekTasks();
      await _loadCurrentMonthDeduction();
      if (_disposed) return;

      successMessage = status == TaskStatus.completed
          ? 'Task completed! Progress updated.'
          : status == TaskStatus.missed
          ? 'Task marked as missed.'
          : null;
    } catch (e) {
      if (!_disposed) errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // ── Quarterly weekly task ──────────────────────────────────
  Future<void> _markQuarterlyWeeklyTaskStatus({
    required String goalId,
    required String taskId,
    required TaskStatus status,
    List<Map<String, String>>? teamRemarks,
  }) async {
    final db = FirebaseFirestore.instance;
    final taskRef = db
        .collection('quarterly_goals')
        .doc(goalId)
        .collection('weekly_tasks')
        .doc(taskId);

    // ✅ Step 1 — Update the task document
    final Map<String, dynamic> taskUpdate = {'status': _statusString(status)};
    if (status == TaskStatus.completed) {
      taskUpdate['completedAt'] = FieldValue.serverTimestamp();
      // Store team remarks directly in the task doc (no new collection)
      if (teamRemarks != null && teamRemarks.isNotEmpty) {
        taskUpdate['teamRemarks'] = teamRemarks
            .map((r) => {'name': r['name'] ?? '', 'remark': r['remark'] ?? ''})
            .toList();
      }
    }
    await taskRef.update(taskUpdate);

    // ✅ Step 2 — Update parent goal progress (silent on rule rejection)
    if (rules != null &&
        (status == TaskStatus.completed || status == TaskStatus.missed)) {
      try {
        final goalRef = db.collection('quarterly_goals').doc(goalId);
        await db.runTransaction((tx) async {
          final snap = await tx.get(goalRef);
          if (!snap.exists) return;
          final cur =
              (snap.data()?['currentProgress'] as num?)?.toDouble() ?? 0;
          double next = cur;
          if (status == TaskStatus.completed) {
            next = (cur + rules!.completedTaskProgressPercent).clamp(
              0.0,
              100.0,
            );
          } else if (status == TaskStatus.missed) {
            next = (cur - rules!.missedTaskDeductionPercent).clamp(0.0, 100.0);
          }
          tx.update(goalRef, {
            'currentProgress': next,
            'status': next >= 100
                ? 'completed'
                : next > 0
                ? 'inProgress'
                : snap.data()?['status'] ?? 'notStarted',
          });
        });
      } catch (e) {
        debugPrint('[Progress] goal update skipped: $e');
      }
    }

    // ✅ Step 3 — Apply salary deduction (silent on failure)
    if (status == TaskStatus.missed && rules != null) {
      try {
        await _applyMonthlyDeduction();
      } catch (e) {
        debugPrint('[Deduction] skipped: $e');
      }
    }
  }

  // ── Standalone task ────────────────────────────────────────
  Future<void> _markStandaloneTaskStatus({
    required String taskId,
    required TaskStatus status,
    List<Map<String, String>>? teamRemarks,
  }) async {
    final db = FirebaseFirestore.instance;
    final taskRef = db.collection('standalone_tasks').doc(taskId);

    final Map<String, dynamic> update = {'status': _statusString(status)};
    if (status == TaskStatus.completed) {
      update['completedAt'] = FieldValue.serverTimestamp();
      if (teamRemarks != null && teamRemarks.isNotEmpty) {
        update['teamRemarks'] = teamRemarks
            .map((r) => {'name': r['name'] ?? '', 'remark': r['remark'] ?? ''})
            .toList();
      }
    }
    await taskRef.update(update);

    if (status == TaskStatus.missed && rules != null) {
      try {
        await _applyMonthlyDeduction();
      } catch (e) {
        debugPrint('[Deduction] skipped (permission or error): $e');
      }
    }
  }

  // ── Monthly deduction ──────────────────────────────────────
  Future<void> _applyMonthlyDeduction() async {
    if (rules == null) return;
    final db = FirebaseFirestore.instance;
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final ref = db.collection('monthly_deductions').doc('${employeeId}_$month');
    final pct = rules!.missedTaskDeductionPercent / 100;

    await db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) {
        final cur = (snap.data()?['deductionPercent'] as num?)?.toDouble() ?? 0;
        tx.update(ref, {
          'deductionPercent': cur + pct,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        tx.set(ref, {
          'employeeId': employeeId,
          'month': month,
          'deductionPercent': pct,
          'bonusPercent': 0.0,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  String _statusString(TaskStatus status) {
    switch (status) {
      case TaskStatus.completed:
        return 'completed';
      case TaskStatus.missed:
        return 'missed';
      case TaskStatus.weekend:
        return 'weekend';
      default:
        return 'pending';
    }
  }

  // handleReminderResponse — UI layer shows the dialog for 'completed',
  // then calls markTaskStatus directly. This method is kept for
  // missed / weekend where no dialog is needed.
  Future<void> handleReminderResponse(
    TaskStatus status, {
    List<Map<String, String>>? teamRemarks,
  }) async {
    if (reminderTask == null || reminderGoal == null) return;
    await markTaskStatus(
      goalId: reminderGoal!.id,
      taskId: reminderTask!.id,
      status: status,
      teamRemarks: teamRemarks,
    );
  }

  void dismissReminder() {
    showWeeklyReminder = false;
    _notify();
  }

  /// Updates a document in the `goals` collection (not quarterly).
  Future<void> updateEmployeeGoalStatus({
    required String goalId,
    required GoalStatus status,
  }) async {
    _setLoading(true);
    try {
      await _service.updateEmployeeGoalStatus(goalId: goalId, status: status);
      if (!_disposed) {
        successMessage = status == GoalStatus.completed
            ? 'Goal marked complete.'
            : 'Goal updated.';
      }
    } catch (e) {
      if (!_disposed) errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // ── Weekly breakdown ───────────────────────────────────────
  int maxWeeksForGoal(QuarterlyGoalModel goal) =>
      goal.endDate.difference(goal.startDate).inDays ~/ 7;

  int get _scheduledWeekCount =>
      weeklyTasksTemp.where((t) => !t.isUnscheduled).length;

  bool get canAddWeek {
    if (selectedGoal == null) return false;
    final max = maxWeeksForGoal(selectedGoal!);
    if (_scheduledWeekCount >= max) return false;
    final nextDue = _nextDueDate;
    return nextDue != null && !nextDue.isAfter(selectedGoal!.endDate);
  }

  DateTime? get _nextDueDate {
    if (selectedGoal == null) return null;
    final scheduled = weeklyTasksTemp.where((t) => !t.isUnscheduled).toList();
    final highest = scheduled.isEmpty
        ? 0
        : scheduled.map((t) => t.weekNumber).reduce((a, b) => a > b ? a : b);
    return selectedGoal!.startDate.add(Duration(days: (highest + 1) * 7));
  }

  int get remainingWeeks {
    if (selectedGoal == null) return 0;
    return (maxWeeksForGoal(selectedGoal!) - _scheduledWeekCount).clamp(0, 13);
  }

  void openWeeklyBreakdown(QuarterlyGoalModel goal) {
    selectedGoal = goal;
    weeklyTasksTemp = [];
    _notify();
    _service.watchTasksForGoal(goal.id).first.then((tasks) {
      if (_disposed) return;
      weeklyTasksTemp = List.from(tasks);
      _notify();
    });
  }

  void addWeekTask() {
    if (!canAddWeek || selectedGoal == null) return;
    final scheduled = weeklyTasksTemp.where((t) => !t.isUnscheduled).toList();
    final nextWeek = scheduled.isEmpty
        ? 1
        : scheduled.map((t) => t.weekNumber).reduce((a, b) => a > b ? a : b) +
              1;
    final dueDate = selectedGoal!.startDate.add(Duration(days: nextWeek * 7));
    weeklyTasksTemp.add(
      WeeklyTaskModel(
        id: '',
        goalId: selectedGoal!.id,
        employeeId: employeeId,
        weekNumber: nextWeek,
        title: '',
        description: '',
        dueDate: dueDate,
        status: TaskStatus.pending,
        isUnscheduled: false,
        priority: TaskPriority.normal,
      ),
    );
    _notify();
  }

  void updateTempTask(int index, WeeklyTaskModel updated) {
    weeklyTasksTemp[index] = updated;
    _notify();
  }

  Future<void> saveWeeklyBreakdown() async {
    if (selectedGoal == null) return;
    final toSave = weeklyTasksTemp
        .where((t) => t.title.trim().isNotEmpty || t.id.isNotEmpty)
        .toList();
    if (toSave.isEmpty) {
      if (!_disposed) errorMessage = 'Please add at least one task title';
      _notify();
      return;
    }
    _setLoading(true);
    try {
      await _service.createWeeklyTasks(selectedGoal!.id, toSave);
      if (!_disposed) {
        selectedGoal = null;
        weeklyTasksTemp = [];
        successMessage = 'Weekly plan saved!';
      }
    } catch (e) {
      if (!_disposed) errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  void closeWeeklyBreakdown() {
    selectedGoal = null;
    weeklyTasksTemp = [];
    _notify();
  }

  // ── Barriers ───────────────────────────────────────────────
  void _watchBarriers() {
    final sub = _service.watchBarriersForEmployee(employeeId).listen((b) {
      if (_disposed) return;
      barriers = b;
      _notify();
    });
    _subs.add(sub);
  }

  // ── fetchAllEmployeeContacts ───────────────────────────────
  Future<List<EmployeeContact>> fetchAllEmployeeContacts() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('users').get();
      final contacts =
          snap.docs
              .where((d) => d.id != employeeId)
              .map((d) => EmployeeContact.fromMap(d.id, d.data()))
              .where((c) => c.name.isNotEmpty && c.email.isNotEmpty)
              .toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
      debugPrint(
        '[fetchAllEmployeeContacts] found ${contacts.length} contacts',
      );
      return contacts;
    } catch (e) {
      debugPrint('[fetchAllEmployeeContacts] error: $e');
      return [];
    }
  }

  // ── reportBarrierWithNotifications ────────────────────────
  Future<void> reportBarrierWithNotifications({
    required EmployeeContact recipient,
    required List<EmployeeContact> ccList,
    required String description,
  }) async {
    _setLoading(true);
    try {
      await FirebaseFirestore.instance.collection('barriers').add({
        'employeeId': employeeId,
        'employeeName': employeeName,
        'recipientId': recipient.uid,
        'recipientName': recipient.name,
        'recipientEmail': recipient.email,
        'ccIds': ccList.map((e) => e.uid).toList(),
        'ccNames': ccList.map((e) => e.name).toList(),
        'description': description,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'open',
      });

      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      final short = description.length > 80
          ? '${description.substring(0, 80)}…'
          : description;

      batch.set(db.collection('notifications').doc(), {
        'userId': recipient.uid,
        'title': '⚠ Barrier Report',
        'body': '$employeeName reported a barrier: $short',
        'type': 'barrier_report',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'reportedBy': employeeId,
        'reporterName': employeeName,
      });
      for (final cc in ccList) {
        batch.set(db.collection('notifications').doc(), {
          'userId': cc.uid,
          'title': '📋 Barrier Report (CC)',
          'body': '$employeeName sent a barrier report — you are CC\'d.',
          'type': 'barrier_report_cc',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'reportedBy': employeeId,
          'reporterName': employeeName,
        });
      }
      await batch.commit();

      if (recipient.fcmToken?.isNotEmpty == true) {
        await _sendFcmMessage(
          token: recipient.fcmToken!,
          title: '⚠ Barrier Report',
          body: '$employeeName reported a barrier: $short',
          data: {
            'type': 'barrier_report',
            'reporterId': employeeId,
            'reporterName': employeeName,
            'description': description,
            'timestamp': DateTime.now().toIso8601String(),
          },
          includeNotification: true,
        );
      }
      for (final cc in ccList) {
        if (cc.fcmToken?.isNotEmpty == true) {
          await _sendFcmMessage(
            token: cc.fcmToken!,
            title: '📋 Barrier Report (CC)',
            body: '$employeeName sent a barrier report.',
            data: {
              'type': 'barrier_report_cc',
              'reporterId': employeeId,
              'reporterName': employeeName,
              'description': description,
              'timestamp': DateTime.now().toIso8601String(),
            },
            includeNotification: false,
          );
        }
      }
      if (!_disposed) successMessage = 'Barrier reported to ${recipient.name}';
    } catch (e) {
      if (!_disposed) errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  static const _fcmServerKey = 'YOUR_FCM_SERVER_KEY';

  Future<void> _sendFcmMessage({
    required String token,
    required String title,
    required String body,
    required Map<String, String> data,
    required bool includeNotification,
  }) async {
    final payload = <String, dynamic>{
      'to': token,
      'data': data,
      'priority': 'high',
    };
    if (includeNotification) {
      payload['notification'] = {
        'title': title,
        'body': body,
        'sound': 'default',
      };
      payload['android'] = {
        'priority': 'high',
        'notification': {
          'channel_id': 'barrier_reports',
          'sound': 'default',
          'priority': 'high',
        },
      };
      payload['apns'] = {
        'payload': {
          'aps': {
            'alert': {'title': title, 'body': body},
            'sound': 'default',
          },
        },
        'headers': {'apns-priority': '10'},
      };
    }
    try {
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$_fcmServerKey',
        },
        body: jsonEncode(payload),
      );
      debugPrint('[FCM] ${response.statusCode}: ${response.body}');
    } catch (e) {
      debugPrint('[FCM] send error: $e');
    }
  }

  // ── OLD barrier method — kept for compatibility ────────────
  Future<void> reportBarrier({
    required String recipientName,
    required String recipientEmail,
    required String description,
    String? goalId,
  }) async {
    _setLoading(true);
    try {
      await _service.reportBarrier(
        BarrierModel(
          id: '',
          employeeId: employeeId,
          employeeName: employeeName,
          recipientName: recipientName,
          recipientEmail: recipientEmail,
          description: description,
          goalId: goalId,
          status: BarrierStatus.open,
          createdAt: DateTime.now(),
        ),
      );
      if (!_disposed) successMessage = 'Barrier reported to $recipientName';
    } catch (e) {
      if (!_disposed) errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // ── Computed ───────────────────────────────────────────────
  double get quarterlyScore {
    if (goals.isEmpty) return 0;
    double total = 0, weight = 0;
    for (final g in goals) {
      total += g.currentProgress * g.weight;
      weight += g.weight;
    }
    return weight > 0 ? (total / weight).clamp(0, 100) : 0;
  }

  String get performanceRating {
    final s = quarterlyScore;
    if (s >= 80) return 'Excellent';
    if (s >= 60) return 'Good';
    return 'Needs Improvement';
  }

  double get projectedBonus => currentMonthDeduction?.bonusAmount ?? 0;
  double get projectedDeduction => currentMonthDeduction?.deductionAmount ?? 0;

  // ── Helpers ────────────────────────────────────────────────
  void _setLoading(bool v) {
    if (_disposed) return;
    isLoading = v;
    _notify();
  }

  void clearMessages() {
    if (_disposed) return;
    errorMessage = null;
    successMessage = null;
    _notify();
  }
}
