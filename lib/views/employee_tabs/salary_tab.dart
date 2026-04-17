import 'package:flutter/material.dart';
import '../../models/employee_model.dart';

class SalaryTab extends StatelessWidget {
  final Employee employee;

  const SalaryTab({super.key, required this.employee});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Salary Card
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Monthly Salary',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                employee.salary > 0
                    ? 'PKR ${employee.salary.toStringAsFixed(0)}'
                    : 'Not set',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 13,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    employee.name,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.work_outline,
                    size: 13,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    employee.role,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Details Card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _row(Icons.badge_outlined, 'Employee', employee.name),
              const Divider(height: 20),
              _row(Icons.work_outline, 'Role', employee.role),
              const Divider(height: 20),
              _row(
                Icons.business_outlined,
                'Department',
                employee.department.isNotEmpty ? employee.department : '—',
              ),
              const Divider(height: 20),
              _row(
                Icons.location_on_outlined,
                'Location',
                employee.location.isNotEmpty ? employee.location : '—',
              ),
              const Divider(height: 20),
              _row(
                Icons.payments_outlined,
                'Basic Salary',
                employee.salary > 0
                    ? 'PKR ${employee.salary.toStringAsFixed(0)}'
                    : 'Not set',
                valueColor: const Color(0xFF2563EB),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Info banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFED7AA)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: Color(0xFFF97316)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Salary is managed by HR. To update, edit the employee profile.',
                  style: TextStyle(fontSize: 11, color: Color(0xFFC2410C)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(IconData icon, String label, String value, {Color? valueColor}) =>
      Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? const Color(0xFF0F172A),
            ),
          ),
        ],
      );
}
