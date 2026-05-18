// lib/models/attendance_policy.dart
//
// Single source of truth for the attendance-driven salary deduction rules
// shown to HR in `_AttendancePolicyDialog` (hr_attendance_screen.dart).
// All currency math for the HR Monthly Attendance screen flows through
// `AttendancePolicy.compute(day)` so the UI and the policy text can never
// drift out of sync.

import 'attendance_model.dart';

class AttendancePolicy {
  // Dummy basic salary (per task brief). When real payroll wires in, this
  // is the only knob that needs to change — replace with users.salary.
  static const double monthlySalary = 35000.0;

  // 22 working days per month regardless of actual weekday count.
  static const int standardWorkingDays = 22;
  static double get perDayWage => monthlySalary / standardWorkingDays;

  // Shift boundaries.
  static const int workStartHour = 9;   // 9:00 AM
  static const int workEndHour = 18;    // 6:00 PM

  // Late tiers (from the dialog).
  //   Up to 9:15 AM ─ 15%   (the dialog leaves 9:15–10:00 undefined; we
  //                          extend the 15% band up to 10:00 so the policy
  //                          partitions the late-window with no gap)
  //   After 10:00 AM ─ 50%
  static const int lateBoundaryHour = 10;
  static const int lateBoundaryMinute = 0;
  static const double lateMildPct = 0.15;
  static const double lateSeverePct = 0.50;

  // Early-out tiers.
  //   5:00 PM ≤ co < 6:00 PM ─ 25%
  //   co < 5:00 PM            ─ 50%
  static const int earlyBoundaryHour = 17;
  static const double earlyMildPct = 0.25;
  static const double earlySeverePct = 0.50;

  // Status-driven flat penalties.
  static const double absentPct = 1.00;     // 100% of day
  static const double halfDayPct = 0.50;    // legacy halfDay status

  /// Compute the deduction breakdown for one archived day.
  /// Per-day total is capped at `perDayWage`.
  static DayDeduction compute(AttendanceModel day) {
    final wage = perDayWage;

    // 1) Absent → full day deducted, ignore everything else.
    if (day.status == AttendanceStatus.absent) {
      return DayDeduction(
        wage: wage,
        infractions: [
          Infraction(label: 'Absent', pct: absentPct, amount: wage),
        ],
      );
    }

    // 2) Approved leave (full / first half / second half) → paid, 0%.
    if (day.status.isAnyLeave) {
      return DayDeduction(wage: wage, infractions: const []);
    }

    // 3) Legacy half-day status.
    if (day.status == AttendanceStatus.halfDay) {
      return DayDeduction(
        wage: wage,
        infractions: [
          Infraction(
            label: 'Half day',
            pct: halfDayPct,
            amount: wage * halfDayPct,
          ),
        ],
      );
    }

    final infractions = <Infraction>[];
    final ci = day.checkInTime;
    final co = day.checkOutTime;

    // 4) Late check-in tier.
    if (ci != null) {
      final minutesLate = (ci.hour - workStartHour) * 60 + ci.minute;
      if (minutesLate > 0) {
        final severeAtMinutes =
            (lateBoundaryHour - workStartHour) * 60 + lateBoundaryMinute;
        if (minutesLate > severeAtMinutes) {
          infractions.add(Infraction(
            label: 'Late (after 10:00 AM)',
            pct: lateSeverePct,
            amount: wage * lateSeverePct,
          ));
        } else {
          infractions.add(Infraction(
            label: 'Late (after 9:00 AM)',
            pct: lateMildPct,
            amount: wage * lateMildPct,
          ));
        }
      }
    }

    // 5) Early checkout — OR no checkout at all (treated as severe-early).
    if (ci != null && co == null) {
      infractions.add(Infraction(
        label: 'Missed check-out',
        pct: earlySeverePct,
        amount: wage * earlySeverePct,
      ));
    } else if (co != null) {
      final coHourFloat = co.hour + co.minute / 60.0;
      if (coHourFloat < workEndHour) {
        if (coHourFloat < earlyBoundaryHour) {
          infractions.add(Infraction(
            label: 'Early out (before 5:00 PM)',
            pct: earlySeverePct,
            amount: wage * earlySeverePct,
          ));
        } else {
          infractions.add(Infraction(
            label: 'Early out (5:00–6:00 PM)',
            pct: earlyMildPct,
            amount: wage * earlyMildPct,
          ));
        }
      }
    }

    // 6) Cap at 100% of day wage. If the raw sum exceeds the wage
    // (e.g. severe late + severe early = 100%), scale every entry
    // proportionally so they still sum correctly.
    final rawSum = infractions.fold<double>(0, (s, x) => s + x.amount);
    if (rawSum > wage) {
      final scale = wage / rawSum;
      for (var i = 0; i < infractions.length; i++) {
        infractions[i] = infractions[i].scaled(scale);
      }
    }

    return DayDeduction(wage: wage, infractions: infractions);
  }
}

class Infraction {
  final String label;
  final double pct;     // 0..1 of perDayWage (post-cap)
  final double amount;  // currency value (post-cap)
  const Infraction({
    required this.label,
    required this.pct,
    required this.amount,
  });

  Infraction scaled(double factor) => Infraction(
        label: label,
        pct: pct * factor,
        amount: amount * factor,
      );
}

class DayDeduction {
  final double wage;
  final List<Infraction> infractions;
  const DayDeduction({required this.wage, required this.infractions});

  double get totalDeduction =>
      infractions.fold<double>(0, (s, x) => s + x.amount);
  double get netForDay => wage - totalDeduction;
  bool get hasDeduction => infractions.isNotEmpty;
}
