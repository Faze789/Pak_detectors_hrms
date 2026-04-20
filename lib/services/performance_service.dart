// ============================================================
// PERFORMANCE SERVICE — Firestore operations
// Monthly deduction = missed tasks whose dueDate is in that month
//
// CHANGE: standalone unscheduled tasks (attachmentType ==
// 'currentWeek' | 'upcomingWeek') are routed to the top-level
// standalone_tasks collection instead of a goal sub-collection.
// getTasksForCurrentWeek and getTasksForMonth now merge both
// sources so deductions and the employee screen both see them.
// markTaskStatus routes updates to the correct collection.
//
// FIX: calculateMonthlyDeduction now saves 'monthNum' (int) and
// 'year' (int) alongside the existing 'month' string field.
// This makes PayrollService._getPerfDeduction's integer-based
// query work correctly, and aligns MonthlyDeductionModel with
// the same pattern used by PayslipModel and PayrollRunModel.
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/performance_models.dart';

class PerformanceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Collection references ─────────────────────────────────
  CollectionReference get _goals => _db.collection('quarterly_goals');
  CollectionReference get _rules => _db.collection('performance_rules');
  CollectionReference get _monthly => _db.collection('monthly_deductions');
  CollectionReference get _barriers => _db.collection('barriers');
  CollectionReference get _users => _db.collection('users');
  CollectionReference get _standalone => _db.collection('standalone_tasks');
  CollectionReference get _employeeGoalsColl => _db.collection('goals');

  CollectionReference _tasks(String goalId) =>
      _goals.doc(goalId).collection('weekly_tasks');

  // ============================================================
  // EMPLOYEE PROFILE
  // ============================================================

  Stream<Map<String, dynamic>> watchEmployeeProfile(String employeeId) {
    return _users
        .doc(employeeId)
        .snapshots()
        .map(
          (snap) => snap.exists ? (snap.data() as Map<String, dynamic>) : {},
        );
  }

  // ============================================================
  // QUARTERLY GOALS
  // ============================================================

  Future<String> assignQuarterlyGoal(QuarterlyGoalModel goal) async {
    final ref = await _goals.add(goal.toMap());
    return ref.id;
  }

  Stream<List<QuarterlyGoalModel>> watchEmployeeGoals(String employeeId) {
    return _goals
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((s) => s.docs.map(QuarterlyGoalModel.fromDoc).toList());
  }

  Stream<List<QuarterlyGoalModel>> watchAllGoals() {
    return _goals
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(QuarterlyGoalModel.fromDoc).toList());
  }

  Future<List<QuarterlyGoalModel>> getGoalsForEmployee(
    String employeeId,
  ) async {
    final snap = await _goals
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('startDate', descending: true)
        .get();
    return snap.docs.map(QuarterlyGoalModel.fromDoc).toList();
  }

  Future<void> deleteGoal(String goalId) async {
    final tasks = await _tasks(goalId).get();
    final batch = _db.batch();
    for (final doc in tasks.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_goals.doc(goalId));
    await batch.commit();
  }

  // ============================================================
  // EMPLOYEE GOALS (`goals` collection — not quarterly)
  // ============================================================

  Future<String> createEmployeeGoal(EmployeeGoalModel goal) async {
    final ref = await _employeeGoalsColl.add(goal.toMap());
    return ref.id;
  }

  Stream<List<EmployeeGoalModel>> watchEmployeeGoalsDocs(String employeeId) {
    return _employeeGoalsColl
        .where('employeeId', isEqualTo: employeeId)
        .snapshots()
        .map((s) {
          final list = s.docs.map(EmployeeGoalModel.fromDoc).toList()
            ..sort((a, b) {
              final pa = a.priority == TaskPriority.prioritized ? 0 : 1;
              final pb = b.priority == TaskPriority.prioritized ? 0 : 1;
              if (pa != pb) return pa.compareTo(pb);
              return a.dueDate.compareTo(b.dueDate);
            });
          return list;
        });
  }

  Stream<List<EmployeeGoalModel>> watchAllEmployeeGoalsDocs() {
    return _employeeGoalsColl
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(EmployeeGoalModel.fromDoc).toList());
  }

  Future<void> deleteEmployeeGoalDoc(String goalId) async {
    await _employeeGoalsColl.doc(goalId).delete();
  }

  /// Employee: only [status] / [completedAt] should change (see Firestore rules).
  Future<void> updateEmployeeGoalStatus({
    required String goalId,
    required GoalStatus status,
  }) async {
    await _employeeGoalsColl.doc(goalId).update({
      'status': status.name,
      'completedAt': status == GoalStatus.completed
          ? Timestamp.fromDate(DateTime.now())
          : null,
    });
  }

  // ============================================================
  // WEEKLY TASKS (inside a quarterly goal)
  // ============================================================

  /// Employee saves/updates their weekly breakdown for a goal.
  /// Replaces only pending tasks so completed/missed ones are preserved.
  Future<void> createWeeklyTasks(
    String goalId,
    List<WeeklyTaskModel> tasks,
  ) async {
    final batch = _db.batch();
    final existing = await _tasks(
      goalId,
    ).where('status', isEqualTo: 'pending').get();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    for (final task in tasks) {
      final ref = task.id.isEmpty
          ? _tasks(goalId).doc()
          : _tasks(goalId).doc(task.id);
      batch.set(ref, {...task.toMap(), 'goalId': goalId});
    }
    batch.update(_goals.doc(goalId), {'status': GoalStatus.inProgress.name});
    await batch.commit();
  }

  /// HR assigns an unscheduled task.
  /// Routes to standalone_tasks if attachmentType is currentWeek/upcomingWeek,
  /// otherwise nests under the goal sub-collection.
  Future<void> assignUnscheduledTask({
    required String goalId,
    required WeeklyTaskModel task,
  }) async {
    final type = task.attachmentType ?? 'quarterly';
    if (type == 'currentWeek' || type == 'upcomingWeek') {
      // Standalone — no goal to attach to
      await _standalone.add(task.toMap());
    } else {
      // Quarterly — nest under goal sub-collection
      await _tasks(goalId).add({...task.toMap(), 'goalId': goalId});
    }
  }

  /// Watch all tasks for a goal ordered by week number.
  Stream<List<WeeklyTaskModel>> watchTasksForGoal(String goalId) {
    return _tasks(goalId)
        .orderBy('weekNumber')
        .snapshots()
        .map((s) => s.docs.map(WeeklyTaskModel.fromDoc).toList());
  }

  /// Unscheduled tasks only — used by HR adhoc tab.
  Future<List<WeeklyTaskModel>> getUnscheduledTasksForGoal(
    String goalId,
  ) async {
    final snap = await _tasks(
      goalId,
    ).where('isUnscheduled', isEqualTo: true).orderBy('dueDate').get();
    return snap.docs.map(WeeklyTaskModel.fromDoc).toList();
  }

  // ============================================================
  // STANDALONE TASKS
  // ============================================================

  /// Watch pending standalone tasks for an employee (real-time).
  Stream<List<WeeklyTaskModel>> watchStandaloneTasksForEmployee(
    String employeeId,
  ) {
    return _standalone
        .where('employeeId', isEqualTo: employeeId)
        .where('status', isEqualTo: TaskStatus.pending.name)
        .snapshots()
        .map((s) => s.docs.map(WeeklyTaskModel.fromDoc).toList());
  }

  /// One-shot fetch of standalone tasks for an employee.
  Future<List<WeeklyTaskModel>> getStandaloneTasksForEmployee(
    String employeeId,
  ) async {
    final snap = await _standalone
        .where('employeeId', isEqualTo: employeeId)
        .where('status', isEqualTo: TaskStatus.pending.name)
        .get();
    // Sort in Dart — avoids requiring a composite index
    final list = snap.docs.map(WeeklyTaskModel.fromDoc).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return list;
  }

  /// All standalone tasks for the HR adhoc tab.
  Future<List<WeeklyTaskModel>> getAllStandaloneTasks() async {
    final snap = await _standalone.get();
    final list = snap.docs.map(WeeklyTaskModel.fromDoc).toList()
      ..sort((a, b) => b.dueDate.compareTo(a.dueDate));
    return list;
  }

  // ============================================================
  // CURRENT WEEK TASKS (quarterly sub-collections + standalone)
  // ============================================================

  /// Tasks due in the current calendar week for this employee.
  /// Merges quarterly sub-collection tasks + standalone tasks.
  Future<List<WeeklyTaskModel>> getTasksForCurrentWeek(
    String employeeId,
  ) async {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(monday.year, monday.month, monday.day);
    final weekEnd = weekStart.add(const Duration(days: 7));

    // 1 — Quarterly tasks
    List<WeeklyTaskModel> quarterlyTasks = [];
    try {
      final snap = await _db
          .collectionGroup('weekly_tasks')
          .where('employeeId', isEqualTo: employeeId)
          .where(
            'dueDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart),
          )
          .where('dueDate', isLessThan: Timestamp.fromDate(weekEnd))
          .where('status', isEqualTo: TaskStatus.pending.name)
          .get();
      quarterlyTasks = snap.docs.map(WeeklyTaskModel.fromDoc).toList();
    } catch (_) {
      // Fallback: iterate each goal's sub-collection
      final goals = await getGoalsForEmployee(employeeId);
      for (final goal in goals) {
        final snap = await _tasks(goal.id)
            .where(
              'dueDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart),
            )
            .where('dueDate', isLessThan: Timestamp.fromDate(weekEnd))
            .get();
        for (final doc in snap.docs) {
          final task = WeeklyTaskModel.fromDoc(doc);
          if (task.status == TaskStatus.pending) quarterlyTasks.add(task);
        }
      }
    }

    // 2 — Standalone tasks (currentWeek + upcomingWeek both included
    //     so the employee sees all assigned standalone tasks)
    final standaloneTasks = await getStandaloneTasksForEmployee(employeeId);

    return [...quarterlyTasks, ...standaloneTasks];
  }

  // ============================================================
  // TASKS FOR MONTH (quarterly + standalone — for deduction calc)
  // ============================================================

  Future<List<WeeklyTaskModel>> getTasksForMonth(
    String employeeId,
    String monthStr,
  ) async {
    final parts = monthStr.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month + 1, 1);

    // Quarterly tasks
    List<WeeklyTaskModel> all = [];
    try {
      final snap = await _db
          .collectionGroup('weekly_tasks')
          .where('employeeId', isEqualTo: employeeId)
          .where(
            'dueDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart),
          )
          .where('dueDate', isLessThan: Timestamp.fromDate(monthEnd))
          .get();
      all = snap.docs.map(WeeklyTaskModel.fromDoc).toList();
    } catch (_) {
      final goals = await getGoalsForEmployee(employeeId);
      for (final goal in goals) {
        final snap = await _tasks(goal.id)
            .where(
              'dueDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart),
            )
            .where('dueDate', isLessThan: Timestamp.fromDate(monthEnd))
            .get();
        all.addAll(snap.docs.map(WeeklyTaskModel.fromDoc));
      }
    }

    // Standalone tasks in the same month
    try {
      final snap = await _standalone
          .where('employeeId', isEqualTo: employeeId)
          .where(
            'dueDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart),
          )
          .where('dueDate', isLessThan: Timestamp.fromDate(monthEnd))
          .get();
      all.addAll(snap.docs.map(WeeklyTaskModel.fromDoc));
    } catch (_) {}

    return all;
  }

  // ============================================================
  // MARK TASK STATUS
  // ============================================================

  /// Routes the update to the correct collection based on attachmentType.
  Future<void> markTaskStatus({
    required String goalId,
    required String taskId,
    required TaskStatus status,
    required PerformanceRulesModel rules,
    String? attachmentType,
  }) async {
    final isStandalone =
        attachmentType == 'currentWeek' ||
        attachmentType == 'upcomingWeek' ||
        goalId.isEmpty;

    if (isStandalone) {
      // Standalone task — update directly in standalone_tasks
      await _standalone.doc(taskId).update({
        'status': status.name,
        if (status == TaskStatus.completed)
          'completedAt': Timestamp.fromDate(DateTime.now()),
      });
      return;
    }

    // Quarterly task — update and propagate progress to goal
    final batch = _db.batch();
    final taskRef = _tasks(goalId).doc(taskId);
    final goalRef = _goals.doc(goalId);

    batch.update(taskRef, {
      'status': status.name,
      if (status == TaskStatus.completed)
        'completedAt': Timestamp.fromDate(DateTime.now()),
    });

    // Only completion increases progress
    if (status == TaskStatus.completed) {
      final goalSnap = await goalRef.get();
      final goal = QuarterlyGoalModel.fromDoc(goalSnap);
      final newProgress =
          (goal.currentProgress + rules.completedTaskProgressPercent).clamp(
            0.0,
            100.0,
          );
      final newStatus = newProgress >= 100
          ? GoalStatus.completed
          : GoalStatus.inProgress;
      batch.update(goalRef, {
        'currentProgress': newProgress,
        'status': newStatus.name,
      });
    }

    await batch.commit();
  }

  // ============================================================
  // MONTHLY DEDUCTION CALCULATION
  //
  // FIX: Added 'monthNum' (int) and 'year' (int) fields to the
  // saved document so PayrollService._getPerfDeduction — which
  // queries by integer month/year — can find the record.
  // This also aligns MonthlyDeductionModel storage with the
  // same convention used by PayslipModel and PayrollRunModel.
  // ============================================================

  Future<MonthlyDeductionModel> calculateMonthlyDeduction({
    required String employeeId,
    required String monthStr,
    required PerformanceRulesModel rules,
  }) async {
    final userDoc = await _users.doc(employeeId).get();
    final userData = userDoc.data() as Map<String, dynamic>;
    final double salary = (userData['salary'] ?? 0).toDouble();

    // Includes both quarterly and standalone tasks
    final tasks = await getTasksForMonth(employeeId, monthStr);

    final completed = tasks
        .where((t) => t.status == TaskStatus.completed)
        .length;
    final missed = tasks.where((t) => t.status == TaskStatus.missed).length;
    final weekend = tasks.where((t) => t.status == TaskStatus.weekend).length;

    final deductionAmount =
        missed * (rules.missedTaskDeductionPercent / 100) * salary;

    final scorable = tasks.where((t) => t.status != TaskStatus.weekend).length;
    final performanceScore = scorable > 0
        ? (completed / scorable * 100).clamp(0.0, 100.0)
        : 0.0;

    double bonusAmount = 0;
    if (performanceScore >= rules.bonusThresholdScore &&
        rules.bonusAmount > 0) {
      bonusAmount = rules.bonusAmountType == 'percentage'
          ? salary * rules.bonusAmount / 100
          : rules.bonusAmount;
    }

    // Parse month string once — used for both the model and the
    // integer fields we now persist alongside it.
    final parts = monthStr.split('-');
    final yearInt = int.parse(parts[0]);
    final monthInt = int.parse(parts[1]);

    final docId = '${employeeId}_${monthStr.replaceAll('-', '_')}';
    final model = MonthlyDeductionModel(
      id: docId,
      employeeId: employeeId,
      month: monthStr,
      totalTasksInMonth: tasks.length,
      completedTasks: completed,
      missedTasks: missed,
      weekendTasks: weekend,
      deductionAmount: deductionAmount,
      bonusAmount: bonusAmount,
      performanceScore: performanceScore,
      salarySnapshot: salary,
      calculatedAt: DateTime.now(),
    );

    // FIX: persist monthNum + year as integers so the integer-
    // based query in PayrollService._getPerfDeduction matches.
    await _monthly.doc(docId).set({
      ...model.toMap(),
      'monthNum': monthInt,
      'year': yearInt,
    });

    if (deductionAmount > 0 || bonusAmount > 0) {
      await _users.doc(employeeId).update({
        'lastSalaryAdjustment': bonusAmount - deductionAmount,
        'lastAdjustmentMonth': monthStr,
        'lastAdjustmentAt': Timestamp.fromDate(DateTime.now()),
      });
    }

    return model;
  }

  Future<MonthlyDeductionModel?> getCurrentMonthDeduction(
    String employeeId,
  ) async {
    final now = DateTime.now();
    final monthStr = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final docId = '${employeeId}_${monthStr.replaceAll('-', '_')}';
    final doc = await _monthly.doc(docId).get();
    if (!doc.exists) return null;
    return MonthlyDeductionModel.fromDoc(doc);
  }

  Stream<List<MonthlyDeductionModel>> watchMonthlyHistory(String employeeId) {
    return _monthly
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('month', descending: true)
        .limit(12)
        .snapshots()
        .map((s) => s.docs.map(MonthlyDeductionModel.fromDoc).toList());
  }

  // ============================================================
  // PERFORMANCE RULES
  // ============================================================

  Stream<PerformanceRulesModel> watchPerformanceRules() {
    return _rules.doc('global').snapshots().map((doc) {
      if (!doc.exists) return PerformanceRulesModel.defaults();
      return PerformanceRulesModel.fromDoc(doc);
    });
  }

  Future<void> savePerformanceRules(
    PerformanceRulesModel rules,
    String updatedBy,
  ) async {
    await _rules.doc('global').set({
      ...rules.toMap(),
      'updatedBy': updatedBy,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // ============================================================
  // BARRIERS
  // ============================================================

  Future<void> reportBarrier(BarrierModel barrier) async {
    await _barriers.add(barrier.toMap());
  }

  Stream<List<BarrierModel>> watchBarriersForEmployee(String employeeId) {
    return _barriers
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(BarrierModel.fromDoc).toList());
  }

  Stream<List<BarrierModel>> watchAllBarriers() {
    return _barriers
        .where('status', isEqualTo: BarrierStatus.open.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(BarrierModel.fromDoc).toList());
  }

  Future<void> resolveBarrier(String barrierId) async {
    await _barriers.doc(barrierId).update({
      'status': BarrierStatus.resolved.name,
    });
  }

  // ============================================================
  // EMPLOYEES (HR only)
  // ============================================================

  Future<List<Map<String, dynamic>>> getAllEmployees() async {
    final snap = await _users.where('role', isEqualTo: 'employee').get();
    return snap.docs
        .map((d) => {'id': d.id, ...(d.data() as Map<String, dynamic>)})
        .toList();
  }

  Stream<Map<String, dynamic>> watchEmployeeProfileByUid(String uid) =>
      watchEmployeeProfile(uid);
}
