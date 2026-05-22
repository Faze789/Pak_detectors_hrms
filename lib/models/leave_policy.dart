// lib/models/leave_policy.dart
//
// Single source of truth for the company leave policy. Mirrors the table
// HR ratified:
//
// Leave Type            | In-Station / Out-of-Station
// ──────────────────────|─────────────────────────────────────────────────
// Annual / Casual / Sick| 3 days/quarter (in) · 4 days/quarter (out)
// Half-Day              | 3 half-days/qtr (in) · 1 half-day/qtr (out)
//                       |   4–7h worked = half-day (50% deduction)
//                       |   < 4h worked = full-day deduction
// Marriage              | 5–6 days own · 3 days immediate family
//                       |   (siblings + children only)
// Bereavement           | 5 days, immediate family only
// Medical               | 10 days, surgery or hospitalization
//
// Maternity / paternity (gender-conditional):
//   • Female (standard childbirth) → 15 days + 2 months WFH
//   • Female (surgery)            → 1 month maternity
//   • Male (parenting)            → 3–4 days paternity
//
// General rule: every leave requires prior HR approval. Unapproved leaves
// incur a 2–3 day penalty deduction (applied at payroll time, not here).
//
// Enforcement status in code (today):
//   ✅ Regular leave per-quarter cap (this file + AttendanceViewModel)
//   ⏳ Half-day, marriage, bereavement, medical, maternity, paternity:
//      constants are exposed so the future leave-type picker UI can read
//      them; no quota tracking is wired yet.

class LeavePolicy {
  // ── Salary / working-day basis ──────────────────────────────────────────
  // The per-day wage divisor used by every penalty formula in this file.
  // Mirrors `AttendancePolicy.standardWorkingDays` — kept here so the
  // policy file is self-contained and doesn't need to cross-reference
  // the deduction policy.
  static const int standardWorkingDays = 22;

  // ── Regular leaves (Annual / Casual / Sick combined bucket) ─────────────
  static const int regularPerQuarterInStation = 3;
  static const int regularPerQuarterOutOfStation = 4;

  /// Days-per-quarter for the regular bucket, picked by station.
  static int regularQuotaPerQuarter({required bool isInStation}) =>
      isInStation
          ? regularPerQuarterInStation
          : regularPerQuarterOutOfStation;

  // ── Half-day leaves ───────────────────────────────────────────────────
  static const int halfDayPerQuarterInStation = 3;
  static const int halfDayPerQuarterOutOfStation = 1;
  // 4–7h worked = half-day; <4h = full day deduction
  static const int halfDayThresholdMinSeconds = 4 * 3600;
  static const int halfDayThresholdMaxSeconds = 7 * 3600;

  // ── Event leaves (annual / lifetime) ──────────────────────────────────
  static const int marriageOwnMinDays = 5;
  static const int marriageOwnMaxDays = 6;
  static const int marriageImmediateFamilyDays = 3;
  static const int bereavementDays = 5;
  static const int medicalDays = 10;

  // ── Maternity / paternity ─────────────────────────────────────────────
  static const int maternityStandardDays = 15;
  static const int maternityStandardWfhMonths = 2;
  static const int maternitySurgeryMonths = 1;
  static const int paternityMinDays = 3;
  static const int paternityMaxDays = 4;

  // ── Wage penalty formulas (per the authoritative HR doc) ───────────────
  //
  // Per the company policy section "Wage Penalty":
  //   • Informed / approved leave fine        = salary ÷ 22  (1× per-day)
  //   • Uninformed / unapproved leave fine    = (salary ÷ 22) × 2  (2×)
  //
  // i.e. an unapproved absence costs TWICE the daily wage. These are
  // exposed as multipliers so the deduction layer can opt in when we
  // start distinguishing "informed-but-disallowed" vs "uninformed".
  static const double informedLeavePenaltyMultiplier = 1.0;
  static const double uninformedLeavePenaltyMultiplier = 2.0;

  /// Returns the fine (in PKR) for taking [days] unapproved leave days
  /// on a monthly salary of [monthlySalary]. Worked example:
  ///   uninformedFine(35000, 1) → 35000 ÷ 22 × 2 ≈ Rs 3,182
  static double uninformedFine(double monthlySalary, int days) =>
      (monthlySalary / standardWorkingDays) *
      uninformedLeavePenaltyMultiplier *
      days;
  static double informedFine(double monthlySalary, int days) =>
      (monthlySalary / standardWorkingDays) *
      informedLeavePenaltyMultiplier *
      days;

  // ── Quarter helper ────────────────────────────────────────────────────
  /// Returns 1, 2, 3, or 4 for the calendar quarter that contains [date].
  static int quarterOf(DateTime date) => ((date.month - 1) ~/ 3) + 1;

  /// Inclusive [start, end] window for the quarter that contains [date].
  static ({DateTime start, DateTime end}) quarterBounds(DateTime date) {
    final q = quarterOf(date);
    final firstMonth = (q - 1) * 3 + 1; // 1, 4, 7, 10
    final start = DateTime(date.year, firstMonth, 1);
    // First day of next quarter, minus one day → last day of this quarter
    final nextQuarterMonth = firstMonth + 3;
    final endYear = nextQuarterMonth > 12 ? date.year + 1 : date.year;
    final endMonth = nextQuarterMonth > 12 ? 1 : nextQuarterMonth;
    final end =
        DateTime(endYear, endMonth, 1).subtract(const Duration(days: 1));
    return (start: start, end: end);
  }

  // ── Human-readable policy text shown to users (no enforcement) ────────
  // Pulled into the LeavePolicyInstructionsDialog. Keeps the wording
  // co-located with the constants so they can't drift apart.
  static const List<({String title, String body})> instructions = [
    (
      title: 'Annual / Casual / Sick',
      body:
          '3 days per quarter (in-station) · 4 days per quarter '
          '(out-of-station). Cannot be carried forward to the next '
          'quarter or year.',
    ),
    (
      title: 'Half-Day',
      body:
          '3 half-days/quarter (in-station) · 1 half-day/quarter '
          '(out-of-station). Working 4 to 7 hours counts as a half-day '
          '(50% wage deduction). Less than 4 hours is a full-day '
          'deduction.',
    ),
    (
      title: 'Marriage',
      body:
          '5–6 days for your own marriage · 3 days for an immediate '
          'family member (siblings and children only).',
    ),
    (
      title: 'Bereavement',
      body:
          '5 days, granted strictly for the death of an immediate '
          'family member.',
    ),
    (
      title: 'Medical',
      body: '10 days. Requires surgery or hospitalization due to illness.',
    ),
    (
      title: 'Maternity',
      body:
          'Female employees — 15 days + an approved 2-month '
          'Work-From-Home arrangement (standard childbirth). '
          '1 month maternity leave when childbirth involves surgery.',
    ),
    (
      title: 'Paternity',
      body:
          'Male employees — 3 to 4 days of paternity leave.',
    ),
    (
      title: 'Approval rule',
      body:
          'No leave is valid unless prior written approval is obtained '
          'from the HR department. Unapproved leaves incur a 2 to 3-day '
          'penalty deduction.',
    ),
  ];
}

// ── Leave type enum (for the request-leave dropdown) ─────────────────────────
//
// Categorical only — picking a type sets the `leaveType` field on the
// `request_for_leave` doc but does not change the per-quarter cap (which
// stays as the regular bucket from LeavePolicy.regularQuotaPerQuarter).
// "Custom" is the escape hatch for situations not covered by the table.

enum RequestLeaveType {
  annualCasualSick,
  marriageOwn,
  marriageFamily,
  bereavement,
  medical,
  maternity, // gated to female employees in the picker
  paternity, // gated to male employees in the picker
  custom,
}

extension RequestLeaveTypeX on RequestLeaveType {
  String get value => name;

  String get label => switch (this) {
        RequestLeaveType.annualCasualSick => 'Annual / Casual / Sick',
        RequestLeaveType.marriageOwn => 'Marriage (own)',
        RequestLeaveType.marriageFamily => 'Marriage (immediate family)',
        RequestLeaveType.bereavement => 'Bereavement',
        RequestLeaveType.medical => 'Medical',
        RequestLeaveType.maternity => 'Maternity',
        RequestLeaveType.paternity => 'Paternity',
        RequestLeaveType.custom => 'Custom (please describe)',
      };

  /// Short quota hint shown next to the dropdown option for context.
  String get quotaHint => switch (this) {
        RequestLeaveType.annualCasualSick =>
          '3 days/qtr (in) · 4 days/qtr (out)',
        RequestLeaveType.marriageOwn => '5–6 days',
        RequestLeaveType.marriageFamily => '3 days · siblings & children only',
        RequestLeaveType.bereavement => '5 days · immediate family',
        RequestLeaveType.medical => '10 days · surgery / hospitalization',
        RequestLeaveType.maternity =>
          '15 days + 2 months WFH (standard) · 1 month (surgery)',
        RequestLeaveType.paternity => '3–4 days',
        RequestLeaveType.custom => 'Describe in reason',
      };

  static RequestLeaveType parse(String? v) {
    switch (v) {
      case 'marriageOwn':
        return RequestLeaveType.marriageOwn;
      case 'marriageFamily':
        return RequestLeaveType.marriageFamily;
      case 'bereavement':
        return RequestLeaveType.bereavement;
      case 'medical':
        return RequestLeaveType.medical;
      case 'maternity':
        return RequestLeaveType.maternity;
      case 'paternity':
        return RequestLeaveType.paternity;
      case 'custom':
        return RequestLeaveType.custom;
      default:
        return RequestLeaveType.annualCasualSick;
    }
  }
}

/// Returns the leave types HR/Lead should let an employee pick from,
/// gated by the employee's gender. Maternity/paternity are hidden for
/// the opposite (or unspecified) gender, and Custom is always available.
List<RequestLeaveType> availableLeaveTypesForGender(String? gender) {
  final base = <RequestLeaveType>[
    RequestLeaveType.annualCasualSick,
    RequestLeaveType.marriageOwn,
    RequestLeaveType.marriageFamily,
    RequestLeaveType.bereavement,
    RequestLeaveType.medical,
  ];
  if (gender == 'female') base.add(RequestLeaveType.maternity);
  if (gender == 'male') base.add(RequestLeaveType.paternity);
  base.add(RequestLeaveType.custom);
  return base;
}
