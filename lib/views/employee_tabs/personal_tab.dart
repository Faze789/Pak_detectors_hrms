import 'package:flutter/material.dart';
import '../../models/employee_model.dart';
import '../../widgets/status_badge.dart';

class PersonalTab extends StatelessWidget {
  final Employee employee;

  const PersonalTab({super.key, required this.employee});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, const Color(0xFFF8FAFC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Personal Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 20),
              _buildInfoRow('Full Name', employee.name),
              _buildInfoRow('Role', employee.role),
              _buildInfoRow('Email', employee.email ?? 'N/A'),
              _buildInfoRow('Phone', employee.phone ?? 'N/A'),
              _buildInfoRow('Location', employee.location),
              _buildInfoRow('Department', employee.department ?? 'N/A'),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Status',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  StatusBadge(status: employee.status),
                ],
              ),
              const SizedBox(height: 12),
              _buildInfoRow('Join Date', employee.joinDate ?? 'N/A'),
              _buildInfoRow(
                'Monthly Salary',
                '\$${employee.salary.toStringAsFixed(2)}',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
