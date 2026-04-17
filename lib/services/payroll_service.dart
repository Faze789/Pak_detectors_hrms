// ============================================================
// PAYROLL SERVICE
// Basic pulled from users.salary (HR can override in config)
// Deductions: loan + performance + attendance (late/absent/early)
//
// FIX #1: Added per-day deduction cap — total deductions for a
//         single day cannot exceed perDayWage (100%). Previously
//         an employee could be penalised 175%+ in one day if they
//         had late + early severe + underworked all at once.
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payroll_model.dart';
import '../models/leave_model.dart';

// ── Attendance policy thresholds ─────────────────────────────
const int _workStartHour    = 9;
const int _lateWarningHour  = 10;
const int _earlyWarningHour = 17;
const int _workEndHour      = 18;
const int _minWorkSeconds   = 4 * 3600;

const _halfLeaveStatuses = {'firstHalfLeave', 'secondHalfLeave', 'onLeave'};

class PayrollService {
  final _db = FirebaseFirestore.instance;

  CollectionReference get _configs        => _db.collection('payroll_config');
  CollectionReference get _payslips       => _db.collection('payslips');
  CollectionReference get _runs           => _db.collection('payroll_runs');
  CollectionReference get _users          => _db.collection('users');
  CollectionReference get _perfDeductions => _db.collection('monthly_deductions');
  CollectionReference get _archive        => _db.collection('attendance_archive');

  // ─────────────────────────────────────────────────────────
  // CONFIG CRUD
  // ─────────────────────────────────────────────────────────

  Future<PayrollConfigModel?> getConfig(String employeeId) async {
    final doc = await _configs.doc(employeeId).get();
    if (!doc.exists) return null;
    return PayrollConfigModel.fromDoc(doc);
  }

  Future<void> saveConfig(PayrollConfigModel config) async {
    await _configs
        .doc(config.employeeId)
        .set(config.toMap(), SetOptions(merge: true));
  }

  // ─────────────────────────────────────────────────────────
  // EMPLOYEES LIST
  // ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getEmployees() async {
    final snap = await _users.where('role', isEqualTo: 'employee').get();
    return snap.docs.map((d) {
      final data = d.data() as Map<String, dynamic>;
      return {
        'id':          d.id,
        'name':        data['name'] ?? '',
        'role':        data['role'] ?? '',
        'designation': data['designation'] ?? '',
        'salary':      (data['salary'] as num? ?? 0).toDouble(),
      };
    }).toList();
  }

  // ─────────────────────────────────────────────────────────
  // PAYSLIP GENERATION
  // ─────────────────────────────────────────────────────────

  Future<List<PayslipModel>> runPayroll({
    required String month,
    required int monthNum,
    required int year,
    required String hrUserId,
  }) async {
    final employees = await getEmployees();
    final payslips  = <PayslipModel>[];

    for (final emp in employees) {
      final empId = emp['id'] as String;

      final config = await getConfig(empId);
      if (config == null) continue;

      final double basicSalary =
          config.basicSalaryOverride ?? (emp['salary'] as double? ?? 0);

      final perfData          = await _getPerfDeduction(empId, monthNum, year);
      final attendanceSummary = await _getAttendanceDeductions(
        employeeId:  empId,
        monthNum:    monthNum,
        year:        year,
        basicSalary: basicSalary,
      );

      final resolvedAllowances = config.allowances
          .map((a) => AllowanceItem(
        name:   a.name,
        amount: a.resolve(basicSalary),
        type:   AllowanceType.fixed,
      ))
          .toList();

      final payslip = PayslipModel(
        id:                   '',
        employeeId:           empId,
        employeeName:         emp['name'] as String,
        employeeRole:         emp['designation'] as String? ?? emp['role'] as String? ?? '',
        month:                month,
        monthNum:             monthNum,
        year:                 year,
        basicSalary:          basicSalary,
        allowances:           resolvedAllowances,
        loanDeduction:        config.loanDeductionPerMonth,
        performanceDeduction: perfData['deductionAmount'] as double,
        performanceBonus:     perfData['bonusAmount'] as double,
        attendanceDeduction:  attendanceSummary.totalDeduction,
        attendanceSummary:    attendanceSummary,
        status:               PayslipStatus.draft,
        generatedAt:          DateTime.now(),
        totalTasksInMonth:    perfData['totalTasks'] as int,
        completedTasks:       perfData['completedTasks'] as int,
        missedTasks:          perfData['missedTasks'] as int,
        weekendTasks:         perfData['weekendTasks'] as int,
        performanceScore:     perfData['quarterlyScore'] as double,
      );

      final existing = await _payslips
          .where('employeeId', isEqualTo: empId)
          .where('monthNum',   isEqualTo: monthNum)
          .where('year',       isEqualTo: year)
          .limit(1)
          .get();

      DocumentReference ref;
      if (existing.docs.isNotEmpty) {
        ref = existing.docs.first.reference;
        await ref.set(payslip.toMap(), SetOptions(merge: true));
      } else {
        ref = await _payslips.add(payslip.toMap());
      }

      payslips.add(PayslipModel(
        id:                   ref.id,
        employeeId:           payslip.employeeId,
        employeeName:         payslip.employeeName,
        employeeRole:         payslip.employeeRole,
        month:                payslip.month,
        monthNum:             payslip.monthNum,
        year:                 payslip.year,
        basicSalary:          payslip.basicSalary,
        allowances:           payslip.allowances,
        loanDeduction:        payslip.loanDeduction,
        performanceDeduction: payslip.performanceDeduction,
        performanceBonus:     payslip.performanceBonus,
        attendanceDeduction:  payslip.attendanceDeduction,
        attendanceSummary:    payslip.attendanceSummary,
        status:               payslip.status,
        generatedAt:          payslip.generatedAt,
        totalTasksInMonth:    payslip.totalTasksInMonth,
        completedTasks:       payslip.completedTasks,
        missedTasks:          payslip.missedTasks,
        weekendTasks:         payslip.weekendTasks,
        performanceScore:     payslip.performanceScore,
      ));
    }

    await _saveRunRecord(
      month:    month,
      monthNum: monthNum,
      year:     year,
      payslips: payslips,
      hrUserId: hrUserId,
    );

    return payslips;
  }

  // ─────────────────────────────────────────────────────────
  // READ PAYSLIPS
  // ─────────────────────────────────────────────────────────

  Future<List<PayslipModel>> getPayslipsForMonth(int monthNum, int year) async {
    final snap = await _payslips
        .where('monthNum', isEqualTo: monthNum)
        .where('year',     isEqualTo: year)
        .get();
    return snap.docs.map(PayslipModel.fromDoc).toList();
  }

  Future<List<PayslipModel>> getPayslipsForEmployee(String employeeId) async {
    final snap = await _payslips
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('year',     descending: true)
        .orderBy('monthNum', descending: true)
        .get();
    return snap.docs.map(PayslipModel.fromDoc).toList();
  }

  // ─────────────────────────────────────────────────────────
  // LEAVES — for report screen
  // ─────────────────────────────────────────────────────────

  /// Returns all leave records for an employee across all time.
  /// Used by HRReportScreen to build the Leave Report card.
  Future<List<LeaveModel>> getLeavesForEmployee(String employeeId) async {
    // No orderBy — avoids requiring a composite index on (userId, startDate).
    // Sorting is done in Dart after fetching.
    final snap = await _db
        .collection('leaves')
        .where('userId', isEqualTo: employeeId)
        .get();
    final list = snap.docs
        .map((d) => LeaveModel.fromMap(d.data(), id: d.id))
        .toList();
    // Sort newest first by fromDate
    list.sort((a, b) => b.fromDate.compareTo(a.fromDate));
    return list;
  }

  // ─────────────────────────────────────────────────────────
  // STATUS UPDATES
  // ─────────────────────────────────────────────────────────

  Future<void> approvePayslip(String payslipId) async {
    await _payslips.doc(payslipId).update({
      'status':     PayslipStatus.approved.name,
      'approvedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> markAsPaid(String payslipId) async {
    await _payslips.doc(payslipId).update({'status': PayslipStatus.paid.name});
  }

  Future<void> deletePayslip(String payslipId) async {
    await _payslips.doc(payslipId).delete();
  }

  // ─────────────────────────────────────────────────────────
  // HISTORY
  // ─────────────────────────────────────────────────────────

  Future<List<PayrollRunModel>> getRunHistory() async {
    final snap = await _runs
        .orderBy('year',     descending: true)
        .orderBy('monthNum', descending: true)
        .get();
    return snap.docs.map(PayrollRunModel.fromDoc).toList();
  }

  // ─────────────────────────────────────────────────────────
  // PRIVATE — ATTENDANCE DEDUCTION CALCULATOR
  //
  // FIX #1: Per-day cap added.
  //
  // Problem: A single bad day (e.g. late arrival + early severe
  // departure + underworked) could accumulate 25% + 50% + 50% =
  // 125% of a day's wage — more than a full day's pay deducted
  // for one day. With extreme combinations it could reach 175%.
  //
  // Fix: After all infractions are evaluated for a given day,
  // the combined amount is clamped to perDayWage (100%). Only
  // the capped amount is added to the running total and the
  // breakdown entries are scaled proportionally so they still
  // sum correctly and display correctly in the payslip detail.
  // ─────────────────────────────────────────────────────────

  Future<AttendanceDeductionSummary> _getAttendanceDeductions({
    required String employeeId,
    required int monthNum,
    required int year,
    required double basicSalary,
  }) async {
    final perDayWage = basicSalary / 22;

    final monthStr = monthNum.toString().padLeft(2, '0');
    final docId    = '${employeeId}_${year}_$monthStr';

    final snap = await _archive.doc(docId).get();
    if (!snap.exists) return AttendanceDeductionSummary.zero();

    final data = snap.data() as Map<String, dynamic>;
    final days = data['days'] as Map<String, dynamic>? ?? {};

    final breakdown = <AttendanceDayDeduction>[];

    int absentDays      = 0;
    int lateMildDays    = 0;
    int lateSevereDays  = 0;
    int earlyMildDays   = 0;
    int earlySevereDays = 0;
    int underworkedDays = 0;
    double total        = 0;

    for (final entry in days.entries) {
      final dateKey = entry.key;
      final day     = entry.value as Map<String, dynamic>;
      final status  = day['status'] as String? ?? '';

      if (status == 'weekend' || status == 'holiday') continue;

      // ── 1. Absent ─────────────────────────────────────────
      if (status == 'absent') {
        final amount = perDayWage; // already 100% — no cap needed
        absentDays++;
        total += amount;
        breakdown.add(AttendanceDayDeduction(
          date:   dateKey,
          type:   AttendanceInfractionType.absent,
          amount: amount,
        ));
        continue;
      }

      final checkInTs     = day['checkInTime']  as Timestamp?;
      final checkOutTs    = day['checkOutTime'] as Timestamp?;
      final totalWorkSecs = (day['totalWorkSeconds'] as num? ?? 0).toInt();

      if (checkInTs == null) continue;

      final checkIn  = checkInTs.toDate();
      final checkOut = checkOutTs?.toDate();
      final isApprovedHalfLeave = _halfLeaveStatuses.contains(status);

      // ── Collect all infractions for this day first ────────
      // We accumulate them into a temporary list, then cap the
      // total before committing to the main breakdown + counters.
      final dayInfractions = <AttendanceDayDeduction>[];

      // ── 2. Late arrival ───────────────────────────────────
      if (status != 'firstHalfLeave') {
        final checkInHour = checkIn.hour + checkIn.minute / 60;
        if (checkInHour > _workStartHour) {
          if (checkInHour >= _lateWarningHour) {
            dayInfractions.add(AttendanceDayDeduction(
              date:   dateKey,
              type:   AttendanceInfractionType.lateSevere,
              amount: perDayWage * 0.50,
            ));
          } else {
            dayInfractions.add(AttendanceDayDeduction(
              date:   dateKey,
              type:   AttendanceInfractionType.lateMild,
              amount: perDayWage * 0.25,
            ));
          }
        }
      }

      // ── 3. Early departure ────────────────────────────────
      if (checkOut != null && status != 'secondHalfLeave') {
        final checkOutHour = checkOut.hour + checkOut.minute / 60;
        if (checkOutHour < _workEndHour) {
          if (checkOutHour < _earlyWarningHour) {
            dayInfractions.add(AttendanceDayDeduction(
              date:   dateKey,
              type:   AttendanceInfractionType.earlySevere,
              amount: perDayWage * 0.50,
            ));
          } else {
            dayInfractions.add(AttendanceDayDeduction(
              date:   dateKey,
              type:   AttendanceInfractionType.earlyMild,
              amount: perDayWage * 0.25,
            ));
          }
        }
      }

      // ── 4. Underworked ────────────────────────────────────
      if (!isApprovedHalfLeave &&
          checkOut != null &&
          totalWorkSecs > 0 &&
          totalWorkSecs < _minWorkSeconds) {
        dayInfractions.add(AttendanceDayDeduction(
          date:   dateKey,
          type:   AttendanceInfractionType.underworked,
          amount: perDayWage * 0.50,
        ));
      }

      if (dayInfractions.isEmpty) continue;

      // ── FIX #1: Cap total for this day to perDayWage ──────
      //
      // Raw sum could exceed 100% on a day with multiple infractions
      // (e.g. late severe 50% + early severe 50% + underwork 50% = 150%).
      // We scale every entry proportionally so they still sum to ≤ 100%.
      //
      // Example: raw = 150%, cap = 100%, scale = 100/150 = 0.667
      //   late severe:  50% × 0.667 = 33.3%  → PKR X
      //   early severe: 50% × 0.667 = 33.3%  → PKR X
      //   underwork:    50% × 0.667 = 33.3%  → PKR X
      //   total = 100%  ✓
      final rawDayTotal = dayInfractions.fold<double>(
          0.0, (s, d) => s + d.amount);
      final scale = rawDayTotal > perDayWage
          ? perDayWage / rawDayTotal
          : 1.0;

      for (final infraction in dayInfractions) {
        final cappedAmount = infraction.amount * scale;

        // Increment counters
        switch (infraction.type) {
          case AttendanceInfractionType.lateMild:
            lateMildDays++;
            break;
          case AttendanceInfractionType.lateSevere:
            lateSevereDays++;
            break;
          case AttendanceInfractionType.earlyMild:
            earlyMildDays++;
            break;
          case AttendanceInfractionType.earlySevere:
            earlySevereDays++;
            break;
          case AttendanceInfractionType.underworked:
            underworkedDays++;
            break;
          case AttendanceInfractionType.absent:
            break; // handled above, never reaches here
        }

        total += cappedAmount;
        breakdown.add(AttendanceDayDeduction(
          date:   infraction.date,
          type:   infraction.type,
          amount: cappedAmount,
        ));
      }
    }

    breakdown.sort((a, b) => a.date.compareTo(b.date));

    return AttendanceDeductionSummary(
      absentDays:      absentDays,
      lateMildDays:    lateMildDays,
      lateSevereDays:  lateSevereDays,
      earlyMildDays:   earlyMildDays,
      earlySevereDays: earlySevereDays,
      underworkedDays: underworkedDays,
      totalDeduction:  total,
      breakdown:       breakdown,
    );
  }

  // ─────────────────────────────────────────────────────────
  // PRIVATE — PERFORMANCE DEDUCTION
  // ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _getPerfDeduction(
      String employeeId, int month, int year) async {
    final snap = await _perfDeductions
        .where('employeeId', isEqualTo: employeeId)
        .where('month',      isEqualTo: month)
        .where('year',       isEqualTo: year)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      return {
        'deductionAmount': 0.0,
        'bonusAmount':     0.0,
        'totalTasks':      0,
        'completedTasks':  0,
        'missedTasks':     0,
        'weekendTasks':    0,
        'quarterlyScore':  0.0,
      };
    }

    final d = snap.docs.first.data() as Map<String, dynamic>;
    return {
      'deductionAmount': (d['deductionAmount'] as num? ?? 0).toDouble(),
      'bonusAmount':     (d['bonusAmount']     as num? ?? 0).toDouble(),
      'totalTasks':      (d['totalTasks']      as int? ?? 0),
      'completedTasks':  (d['completedTasks']  as int? ?? 0),
      'missedTasks':     (d['missedTasks']     as int? ?? 0),
      'weekendTasks':    (d['weekendTasks']    as int? ?? 0),
      'quarterlyScore':  (d['quarterlyScore']  as num? ?? 0).toDouble(),
    };
  }

  // ─────────────────────────────────────────────────────────
  // PRIVATE — SAVE RUN RECORD
  // ─────────────────────────────────────────────────────────

  Future<void> _saveRunRecord({
    required String month,
    required int monthNum,
    required int year,
    required List<PayslipModel> payslips,
    required String hrUserId,
  }) async {
    final run = PayrollRunModel(
      id:                         '',
      month:                      month,
      monthNum:                   monthNum,
      year:                       year,
      totalEmployees:             payslips.length,
      totalGross:                 payslips.fold(0, (s, p) => s + p.grossPay),
      totalDeductions:            payslips.fold(0, (s, p) => s + p.totalDeductions),
      totalNetPay:                payslips.fold(0, (s, p) => s + p.netPay),
      totalPerformanceDeductions: payslips.fold(0, (s, p) => s + p.performanceDeduction),
      totalPerformanceBonuses:    payslips.fold(0, (s, p) => s + p.performanceBonus),
      totalAttendanceDeductions:  payslips.fold(0, (s, p) => s + p.attendanceDeduction),
      status:                     PayrollRunStatus.draft,
      runBy:                      hrUserId,
      runAt:                      DateTime.now(),
    );

    final existing = await _runs
        .where('monthNum', isEqualTo: monthNum)
        .where('year',     isEqualTo: year)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      await existing.docs.first.reference
          .set(run.toMap(), SetOptions(merge: true));
    } else {
      await _runs.add(run.toMap());
    }
  }
}