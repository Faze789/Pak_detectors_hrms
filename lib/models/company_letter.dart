// lib/models/company_letter.dart
//
// Model + per-kind default body generators for HR-issued company letters.
//
// Storage: one document per letter at `company_letters/{id}`. Subjects
// and bodies are persisted as plain text so HR can review and re-edit
// later. The renderer + PDF generator both read from these fields.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

enum LetterKind {
  offer,
  promotion,
  internship,
  probation,
  fullEmployment,
  warning,
  termination,
  experience,
}

extension LetterKindX on LetterKind {
  String get value => name;

  String get label => switch (this) {
        LetterKind.offer => 'Offer Letter',
        LetterKind.promotion => 'Promotion Letter',
        LetterKind.internship => 'Internship Letter',
        LetterKind.probation => 'Probation Letter',
        LetterKind.fullEmployment => 'Full Employment Letter',
        LetterKind.warning => 'Warning Letter',
        LetterKind.termination => 'Termination Letter',
        LetterKind.experience => 'Experience Letter',
      };

  /// Subject line shown at the top of the rendered document.
  String get defaultSubject => switch (this) {
        LetterKind.offer => 'Offer of Employment',
        LetterKind.promotion => 'Notification of Promotion',
        LetterKind.internship => 'Internship Offer Letter',
        LetterKind.probation => 'Probationary Employment',
        LetterKind.fullEmployment => 'Confirmation of Full Employment',
        LetterKind.warning => 'Formal Warning',
        LetterKind.termination => 'Notice of Termination',
        LetterKind.experience => 'Employment Experience Letter',
      };

  static LetterKind parse(String? v) {
    switch (v) {
      case 'promotion':
        return LetterKind.promotion;
      case 'internship':
        return LetterKind.internship;
      case 'probation':
        return LetterKind.probation;
      case 'fullEmployment':
        return LetterKind.fullEmployment;
      case 'warning':
        return LetterKind.warning;
      case 'termination':
        return LetterKind.termination;
      case 'experience':
        return LetterKind.experience;
      default:
        return LetterKind.offer;
    }
  }
}

class CompanyLetter {
  final String id;
  final LetterKind kind;
  final String subject;

  /// Recipient employee.
  final String employeeUid;
  final String employeeEmpId;
  final String employeeName;
  final String? employeeEmail;

  /// Date that goes at the top-right of the document.
  final DateTime letterDate;

  /// Per-kind structured fields (start date, salary, position, reason…).
  /// Stored verbatim so the renderer/PDF doesn't need to re-fetch.
  final Map<String, dynamic> fields;

  /// HR-editable plain-text body. Generated from a template on create;
  /// HR can amend before sending. PDF generator wraps + paragraph-breaks
  /// on \n\n.
  final String body;

  /// Who issued it.
  final String hrUid;
  final String hrName;
  final String? hrTitle;
  final String companyName;

  final DateTime createdAt;
  final DateTime? sentAt;

  const CompanyLetter({
    required this.id,
    required this.kind,
    required this.subject,
    required this.employeeUid,
    required this.employeeEmpId,
    required this.employeeName,
    this.employeeEmail,
    required this.letterDate,
    required this.fields,
    required this.body,
    required this.hrUid,
    required this.hrName,
    this.hrTitle,
    required this.companyName,
    required this.createdAt,
    this.sentAt,
  });

  Map<String, dynamic> toMap() => {
        'kind': kind.value,
        'subject': subject,
        'employeeUid': employeeUid,
        'employeeEmpId': employeeEmpId,
        'employeeName': employeeName,
        if (employeeEmail != null) 'employeeEmail': employeeEmail,
        'letterDate': Timestamp.fromDate(letterDate),
        'fields': fields,
        'body': body,
        'hrUid': hrUid,
        'hrName': hrName,
        if (hrTitle != null) 'hrTitle': hrTitle,
        'companyName': companyName,
        'createdAt': Timestamp.fromDate(createdAt),
        if (sentAt != null) 'sentAt': Timestamp.fromDate(sentAt!),
      };

  factory CompanyLetter.fromMap(Map<String, dynamic> m, {required String id}) {
    DateTime ts(dynamic v, [DateTime? fallback]) =>
        v is Timestamp ? v.toDate() : (fallback ?? DateTime.now());
    return CompanyLetter(
      id: id,
      kind: LetterKindX.parse((m['kind'] ?? '').toString()),
      subject: (m['subject'] ?? '').toString(),
      employeeUid: (m['employeeUid'] ?? '').toString(),
      employeeEmpId: (m['employeeEmpId'] ?? '').toString(),
      employeeName: (m['employeeName'] ?? '').toString(),
      employeeEmail: m['employeeEmail']?.toString(),
      letterDate: ts(m['letterDate']),
      fields: Map<String, dynamic>.from(m['fields'] as Map? ?? const {}),
      body: (m['body'] ?? '').toString(),
      hrUid: (m['hrUid'] ?? '').toString(),
      hrName: (m['hrName'] ?? '').toString(),
      hrTitle: m['hrTitle']?.toString(),
      companyName: (m['companyName'] ??
              'Pakistan Detector Technologies Pvt. Ltd.')
          .toString(),
      createdAt: ts(m['createdAt']),
      sentAt: m['sentAt'] is Timestamp ? (m['sentAt'] as Timestamp).toDate() : null,
    );
  }
}

/// Field keys each LetterKind expects. The HR form drives off this so
/// the renderer + PDF only need to look up known keys.
const Map<LetterKind, List<String>> letterKindFields = {
  LetterKind.offer: ['position', 'startDate', 'salary', 'workingDays'],
  LetterKind.promotion: ['oldPosition', 'newPosition', 'effectiveDate', 'newSalary'],
  LetterKind.internship: ['startDate', 'durationMonths', 'stipend', 'workingDays'],
  LetterKind.probation: ['position', 'startDate', 'probationMonths', 'salary'],
  LetterKind.fullEmployment: ['position', 'effectiveDate', 'salary', 'workingDays'],
  LetterKind.warning: ['incidentDate', 'reason', 'expectedAction'],
  LetterKind.termination: ['effectiveDate', 'reason', 'lastWorkingDay'],
  LetterKind.experience: ['position', 'startDate', 'endDate', 'performanceNote'],
};

/// Generates a sensible default body for a new letter. HR can edit this
/// freely in the preview before saving / sending.
String generateDefaultBody({
  required LetterKind kind,
  required String employeeName,
  required Map<String, dynamic> fields,
  required String companyName,
}) {
  String fmtDate(dynamic v) {
    if (v is DateTime) return DateFormat('EEEE, d MMMM, yyyy').format(v);
    if (v is Timestamp) {
      return DateFormat('EEEE, d MMMM, yyyy').format(v.toDate());
    }
    return v?.toString() ?? '';
  }

  String money(dynamic v) {
    if (v == null) return '';
    final s = v.toString();
    if (s.isEmpty) return '';
    return 'PKR $s';
  }

  switch (kind) {
    case LetterKind.offer:
      return 'We are pleased to offer you the position of '
          '${fields['position'] ?? '[position]'} at $companyName. Your '
          'employment is scheduled to begin on ${fmtDate(fields['startDate'])}.\n\n'
          'You will receive a monthly salary of ${money(fields['salary'])}. '
          'You are expected to demonstrate the standards of professionalism '
          'and contribution we expect of every team member.\n\n'
          'Office Timings: 09:00 a.m. to 06:00 p.m. (09:00 a.m. to 05:00 p.m. in Winters)\n'
          'Working Days: ${fields['workingDays'] ?? 'Monday to Friday'}\n\n'
          'We look forward to having you as part of our team.';

    case LetterKind.promotion:
      return 'We are pleased to inform you that you have been promoted '
          'from ${fields['oldPosition'] ?? '[old position]'} to '
          '${fields['newPosition'] ?? '[new position]'}, effective '
          '${fmtDate(fields['effectiveDate'])}.\n\n'
          'Your revised monthly salary will be ${money(fields['newSalary'])}. '
          'This promotion reflects the value and dedication you have '
          'brought to $companyName. We trust you will continue to deliver '
          'with the same commitment.';

    case LetterKind.internship:
      return 'We are pleased to offer you an internship position at '
          '$companyName. Your internship is scheduled to begin on '
          '${fmtDate(fields['startDate'])} and will run for '
          '${fields['durationMonths'] ?? '3'} months.\n\n'
          'As part of this internship, you will receive a monthly stipend of '
          '${money(fields['stipend'])}. Upon successful completion and based '
          'on your performance during or after the internship, you will be '
          'considered for a permanent position within the company. The '
          'salary package for the permanent position will be discussed upon '
          'completion of the internship.\n\n'
          'Office Timings: 09:00 a.m. to 06:00 p.m. (09:00 a.m. to 05:00 p.m. in Winters)\n'
          'Working Days: ${fields['workingDays'] ?? 'Monday to Friday'}\n\n'
          'We look forward to having you as part of our team.';

    case LetterKind.probation:
      return 'This letter is to confirm your appointment as '
          '${fields['position'] ?? '[position]'} at $companyName on a '
          'probationary basis, beginning ${fmtDate(fields['startDate'])}.\n\n'
          'Your probation period will be '
          '${fields['probationMonths'] ?? '3'} months. During this period '
          'your monthly salary will be ${money(fields['salary'])}. Your '
          'continued employment beyond probation is subject to a '
          'satisfactory performance review.';

    case LetterKind.fullEmployment:
      return 'Following the successful completion of your probationary '
          'period, we are pleased to confirm your appointment as a full-time '
          'employee in the position of ${fields['position'] ?? '[position]'} '
          'at $companyName, effective ${fmtDate(fields['effectiveDate'])}.\n\n'
          'Your monthly salary will be ${money(fields['salary'])}. All '
          'company policies, benefits, and conditions of service apply from '
          'this date.\n\n'
          'Working Days: ${fields['workingDays'] ?? 'Monday to Friday'}\n\n'
          'We look forward to your continued contribution.';

    case LetterKind.warning:
      return 'This letter is to formally bring to your attention the '
          'incident dated ${fmtDate(fields['incidentDate'])} regarding '
          '${fields['reason'] ?? '[reason]'}.\n\n'
          'This conduct is not in line with company standards. You are '
          'expected to: ${fields['expectedAction'] ?? '[expected corrective action]'}.\n\n'
          'Please treat this as a formal warning. Any recurrence may result '
          'in further disciplinary action up to and including termination of '
          'employment.';

    case LetterKind.termination:
      return 'We regret to inform you that your employment with '
          '$companyName is being terminated, effective '
          '${fmtDate(fields['effectiveDate'])}.\n\n'
          'The basis for this decision: ${fields['reason'] ?? '[reason]'}.\n\n'
          'Your last working day will be '
          '${fmtDate(fields['lastWorkingDay'])}. You are requested to '
          'complete the standard exit formalities including handover of '
          'company assets and clearance of dues by this date.\n\n'
          'We thank you for your service.';

    case LetterKind.experience:
      return 'This letter certifies that $employeeName was employed at '
          '$companyName in the position of '
          '${fields['position'] ?? '[position]'} from '
          '${fmtDate(fields['startDate'])} to ${fmtDate(fields['endDate'])}.\n\n'
          '${fields['performanceNote'] ?? 'During this period the employee discharged the responsibilities of the role with diligence and professionalism.'}\n\n'
          'We wish them every success in their future endeavours.';
  }
}
