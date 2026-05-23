import 'package:flutter/material.dart';
import '../models/job_model.dart';
import '../models/candidate_model.dart';
import '../models/employee_model.dart';

/// Unified StatusBadge that handles:
///   - JobStatus       (open / closed / draft)
///   - CandidateStatus (pending / shortlisted / hired / rejected)
///   - EmployeeStatus  (active / leave / inactive)
class StatusBadge extends StatelessWidget {
  final Object? status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == null) {
      return _badge(
        'Unknown',
        Colors.grey.shade100,
        Colors.grey.shade600,
        null,
      );
    }

    if (status is JobStatus) {
      return _jobBadge(status as JobStatus);
    } else if (status is CandidateStatus) {
      return _candidateBadge(status as CandidateStatus);
    } else if (status is EmployeeStatus) {
      return _employeeBadge(status as EmployeeStatus);
    }

    return _badge('Unknown', Colors.grey.shade100, Colors.grey.shade600, null);
  }

  // ─────────────────── JOB STATUS ─────────────────────────────
  Widget _jobBadge(JobStatus s) {
    switch (s) {
      case JobStatus.open:
        return _badge(
          'Open',
          const Color(0xFFECFDF5),
          const Color(0xFF065F46),
          Icons.circle,
          dotOnly: true,
        );
      case JobStatus.closed:
        return _badge(
          'Closed',
          const Color(0xFFFEF2F2),
          const Color(0xFF991B1B),
          Icons.circle,
          dotOnly: true,
        );
      case JobStatus.draft:
        return _badge(
          'Draft',
          const Color(0xFFF1F5F9),
          const Color(0xFF475569),
          Icons.circle,
          dotOnly: true,
        );
    }
  }

  // ─────────────────── CANDIDATE STATUS ───────────────────────
  Widget _candidateBadge(CandidateStatus s) {
    switch (s) {
      case CandidateStatus.pending:
        return _badge(
          'Pending',
          const Color(0xFFFFFBEB),
          const Color(0xFF92400E),
          Icons.schedule,
        );
      case CandidateStatus.shortlisted:
        return _badge(
          'Shortlisted',
          const Color(0xFFECFDF5),
          const Color(0xFF065F46),
          Icons.check_circle,
        );
      case CandidateStatus.hired:
        return _badge(
          'Hired',
          const Color(0xFFEFF6FF),
          const Color(0xFF1D4ED8),
          Icons.person,
        );
      case CandidateStatus.rejected:
        return _badge(
          'Rejected',
          const Color(0xFFFEF2F2),
          const Color(0xFF991B1B),
          Icons.cancel,
        );
    }
  }

  // ─────────────────── EMPLOYEE STATUS ────────────────────────
  Widget _employeeBadge(EmployeeStatus s) {
    switch (s) {
      case EmployeeStatus.active:
        return _badge(
          'Active',
          const Color(0xFFECFDF5),
          const Color(0xFF065F46),
          Icons.check_circle,
        );
      case EmployeeStatus.leave:
        return _badge(
          'On Leave',
          const Color(0xFFFFFBEB),
          const Color(0xFF92400E),
          Icons.beach_access,
        );
      case EmployeeStatus.inactive:
        return _badge(
          'Inactive',
          const Color(0xFFF1F5F9),
          const Color(0xFF475569),
          Icons.pause_circle,
        );
    }
  }

  // ─────────────────── BASE BUILDER ───────────────────────────
  Widget _badge(
    String label,
    Color bg,
    Color fg,
    IconData? icon, {
    bool dotOnly = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dotOnly ? 8 : 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
