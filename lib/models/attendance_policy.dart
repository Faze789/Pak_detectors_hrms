// lib/models/attendance_policy.dart
//
// Single source of truth for salary-deduction rules.
//
// DEFAULT thresholds (no HR override):
//   workStart  = 09:00   workEnd = 18:00
//   Late ≤ 10:00          → 15%   (workStart + 1 h)
//   Late > 10:00          → 50%
//   Early-out ≥ 17:00     → 25%   (workEnd   − 1 h)
//   Early-out < 17:00     → 50%
//   Absent                → 100%
//   Approved leave        →   0%
//
// WITH HR OVERRIDE (custom workStart / workEnd):
//   lateThreshold   = workStart + 1 h  (same 1-hour gap, different anchor)
//   earlyThreshold  = workEnd   − 1 h
//   All percentages remain identical.
//
// Per-day deduction is capped at 100 % of the daily wage.

import 'attendance_model.dart';
import 'work_hour_override_model.dart';

// ── Infraction ────────────────────────────────────────────────────────────────

class Infraction {
  final String label;

  /// Fraction of the daily wage (0.0–1.0).
  final double pct;

  /// Rupee amount already computed (pct × perDayWage).
  final double amount;

  const Infraction({
    required this.label,
    required this.pct,
    required this.amount,
  });
}

// ── DayDeduction ─────────────────────────────────────────────────────────────

class DayDeduction {
  /// Per-day wage basis used for this computation.
  final double wage;

  /// Zero or more infractions that drove a deduction.
  final List<Infraction> infractions;

  /// Total amount deducted (capped at [wage]).
  final double totalDeduction;

  const DayDeduction({
    required this.wage,
    required this.infractions,
    required this.totalDeduction,
  });

  double get netForDay => wage - totalDeduction;
}

// ── AttendancePolicy ──────────────────────────────────────────────────────────

class AttendancePolicy {
  // ── Salary constants ────────────────────────────────────────────────────
  // Fallback salary applied when an employee has no `users/{uid}.salary`
  // value on file. HR can set a per-employee salary on the employee edit
  // screen; once it's > 0, every deduction calculation for that employee
  // uses their saved salary instead of this fallback.
  static const double monthlySalary = 35000;
  static const int standardWorkingDays = 22;
  static double get perDayWage => monthlySalary / standardWorkingDays;

  /// Resolve the per-day wage for a given employee. Pass the employee's
  /// saved monthly salary (from `users/{uid}.salary`); if it is null, 0,
  /// or negative, falls back to the company default [monthlySalary].
  static double perDayWageFor(double? employeeMonthlySalary) {
    final s = (employeeMonthlySalary != null && employeeMonthlySalary > 0)
        ? employeeMonthlySalary
        : monthlySalary;
    return s / standardWorkingDays;
  }

  // ── Default shift boundaries ────────────────────────────────────────────
  static const int _defStartH = 9;
  static const int _defStartM = 0;
  static const int _defEndH = 18;
  static const int _defEndM = 0;

  // ── Main entry point ────────────────────────────────────────────────────

  /// Compute salary deductions for [att].
  ///
  /// • Pass [override] when HR has assigned custom hours for this employee
  ///   on this date — thresholds will slide accordingly (± 1 h from shift
  ///   ends).
  /// • Pass [employeeMonthlySalary] from `users/{uid}.salary` so the
  ///   deduction percentages anchor on that employee's actual pay. When
  ///   null / 0, the company-wide [monthlySalary] fallback is used.
  static DayDeduction compute(
    AttendanceModel att, {
    WorkHourOverride? override,
    double? employeeMonthlySalary,
  }) {
    final wage = perDayWageFor(employeeMonthlySalary);

    // ── Absent: full-day deduction ─────────────────────────────────────
    if (att.status == AttendanceStatus.absent) {
      return DayDeduction(
        wage: wage,
        infractions: [
          Infraction(label: 'Absent — full day', pct: 1.0, amount: wage),
        ],
        totalDeduction: wage,
      );
    }

    // ── Approved leave: no deduction ──────────────────────────────────
    if (att.status.isAnyLeave) {
      return DayDeduction(wage: wage, infractions: [], totalDeduction: 0);
    }

    // ── Determine shift boundaries ─────────────────────────────────────
    final int startH = override?.workStartHour ?? _defStartH;
    final int startM = override?.workStartMinute ?? _defStartM;
    final int endH = override?.workEndHour ?? _defEndH;
    final int endM = override?.workEndMinute ?? _defEndM;

    // lateThreshold   = workStart + 1 hour
    final int lateThH = (startH + 1).clamp(0, 23);
    final int lateThM = startM;

    // earlyOutThreshold = workEnd − 1 hour
    final int earlyThH = (endH - 1).clamp(0, 23);
    final int earlyThM = endM;

    final infractions = <Infraction>[];

    // ── Late check-in ──────────────────────────────────────────────────
    final ci = att.checkInTime;
    if (ci != null) {
      final ciMins = ci.hour * 60 + ci.minute;
      final startMins = startH * 60 + startM;
      final lateThMins = lateThH * 60 + lateThM;

      if (ciMins > startMins) {
        if (ciMins <= lateThMins) {
          // Late but ≤ 1 h past shift start → 15%
          infractions.add(
            Infraction(
              label: 'Late check-in (before ${_fmtHM(lateThH, lateThM)})',
              pct: 0.15,
              amount: wage * 0.15,
            ),
          );
        } else {
          // Late > 1 h past shift start → 50%
          infractions.add(
            Infraction(
              label: 'Late check-in (after ${_fmtHM(lateThH, lateThM)})',
              pct: 0.50,
              amount: wage * 0.50,
            ),
          );
        }
      }
    }

    // ── Early check-out ────────────────────────────────────────────────
    final co = att.checkOutTime;
    if (co != null) {
      final coMins = co.hour * 60 + co.minute;
      final endMins = endH * 60 + endM;
      final earlyThMins = earlyThH * 60 + earlyThM;

      if (coMins < endMins) {
        if (coMins >= earlyThMins) {
          // Left within 1 h of shift end → 25%
          infractions.add(
            Infraction(
              label:
                  'Early check-out (between ${_fmtHM(earlyThH, earlyThM)} '
                  'and ${_fmtHM(endH, endM)})',
              pct: 0.25,
              amount: wage * 0.25,
            ),
          );
        } else {
          // Left more than 1 h before shift end → 50%
          infractions.add(
            Infraction(
              label: 'Early check-out (before ${_fmtHM(earlyThH, earlyThM)})',
              pct: 0.50,
              amount: wage * 0.50,
            ),
          );
        }
      }
    }

    // ── Cap at 100 % ───────────────────────────────────────────────────
    double total = infractions.fold(0.0, (s, i) => s + i.amount);
    if (total > wage) total = wage;

    return DayDeduction(
      wage: wage,
      infractions: infractions,
      totalDeduction: total,
    );
  }

  // ── Formatter ──────────────────────────────────────────────────────────
  static String _fmtHM(int h, int m) {
    final period = h >= 12 ? 'PM' : 'AM';
    final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$displayH:${m.toString().padLeft(2, '0')} $period';
  }
}
