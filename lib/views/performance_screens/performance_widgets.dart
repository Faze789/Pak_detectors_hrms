// ============================================================
// SHARED PERFORMANCE WIDGETS
// ============================================================

import 'package:flutter/material.dart';
import '../../models/performance_models.dart';

// ── String extension ──────────────────────────────────────────

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}

// ── Design tokens ─────────────────────────────────────────────

const kBlue = Color(0xFF2563EB);
const kBlueSoft = Color(0xFFEFF6FF);
const kBlueBorder = Color(0xFFBFDBFE);
const kGreen = Color(0xFF10B981);
const kGreenSoft = Color(0xFFF0FDF4);
const kRed = Color(0xFFDC2626);
const kRedSoft = Color(0xFFFEF2F2);
const kOrange = Color(0xFFEA580C);
const kOrangeSoft = Color(0xFFFFF7ED);
const kSlate = Color(0xFF64748B);
const kSlateDark = Color(0xFF0F172A);
const kSlateBg = Color(0xFFF8FAFC);
const kSlate100 = Color(0xFFF1F5F9);
const kSlate200 = Color(0xFFE2E8F0);

// ── Form decoration ───────────────────────────────────────────

InputDecoration formDec(String label) => InputDecoration(
  labelText: label,
  labelStyle: const TextStyle(color: kSlate, fontSize: 13),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: kSlate200),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: kBlue, width: 1.5),
  ),
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  filled: true,
  fillColor: Colors.white,
);

// ── Date picker field ─────────────────────────────────────────

class DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final Function(DateTime) onPick;

  const DatePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          builder: (ctx, child) => Theme(
            data: Theme.of(
              ctx,
            ).copyWith(colorScheme: const ColorScheme.light(primary: kBlue)),
            child: child!,
          ),
        );
        if (picked != null) onPick(picked);
      },
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: formDec(label),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value == null
                    ? 'Select Date'
                    : '${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 13,
                  color: value == null ? kSlate : kSlateDark,
                ),
              ),
            ),
            const Icon(Icons.calendar_today_rounded, size: 15, color: kSlate),
          ],
        ),
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: kSlate,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: kSlateDark,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}

// ── Plain card ────────────────────────────────────────────────

class PCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;

  const PCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ── Score badge ───────────────────────────────────────────────

class ScoreBadge extends StatelessWidget {
  final int score;

  const ScoreBadge({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    if (score >= 80) {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF16A34A);
    } else if (score >= 60) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFD97706);
    } else {
      bg = const Color(0xFFFEE2E2);
      fg = kRed;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$score%',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}

// ── Goal status badge ─────────────────────────────────────────

class GoalStatusBadge extends StatelessWidget {
  final GoalStatus status;

  const GoalStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      GoalStatus.completed => (
        'Completed',
        const Color(0xFFDCFCE7),
        const Color(0xFF16A34A),
      ),
      GoalStatus.inProgress => ('In Progress', kBlueSoft, kBlue),
      GoalStatus.onTrack => (
        'On Track',
        const Color(0xFFDCFCE7),
        const Color(0xFF16A34A),
      ),
      GoalStatus.atRisk => ('At Risk', const Color(0xFFFEE2E2), kRed),
      GoalStatus.failed => ('Failed', const Color(0xFFFEE2E2), kRed),
      GoalStatus.notStarted => (
        'Not Started',
        kSlate100,
        const Color(0xFF475569),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}

// ── Task status badge ─────────────────────────────────────────

class TaskStatusBadge extends StatelessWidget {
  final TaskStatus status;

  const TaskStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (status) {
      TaskStatus.completed => (Icons.check_circle_rounded, kGreen, 'Completed'),
      TaskStatus.missed => (Icons.cancel_rounded, kRed, 'Missed'),
      TaskStatus.weekend => (
        Icons.access_time_rounded,
        const Color(0xFFF59E0B),
        'Weekend',
      ),
      TaskStatus.pending => (
        Icons.radio_button_unchecked_rounded,
        kSlate,
        'Pending',
      ),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Priority badge ────────────────────────────────────────────

class PriorityBadge extends StatelessWidget {
  final TaskPriority priority;

  const PriorityBadge({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    final isUrgent = priority == TaskPriority.prioritized;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isUrgent ? const Color(0xFFFEE2E2) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isUrgent ? 'URGENT' : 'NORMAL',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isUrgent ? kRed : kOrange,
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  final String message;

  const EmptyState({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kSlate200),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_rounded, size: 48, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}

// ── Progress bar ──────────────────────────────────────────────

class PerformanceProgressBar extends StatelessWidget {
  final double current;
  final double target;
  final Color color;

  const PerformanceProgressBar({
    super.key,
    required this.current,
    required this.target,
    this.color = kBlue,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (current / target).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: LinearProgressIndicator(
        value: pct,
        backgroundColor: kSlate200,
        valueColor: AlwaysStoppedAnimation(color),
        minHeight: 8,
      ),
    );
  }
}

// ── Deduction frequency label ─────────────────────────────────

String frequencyLabel(DeductionFrequency f) => switch (f) {
  DeductionFrequency.monthly => 'Monthly',
  DeductionFrequency.weekly => 'Weekly',
  DeductionFrequency.biWeekly => 'Bi-Weekly',
};
