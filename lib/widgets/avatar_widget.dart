import 'package:flutter/material.dart';

class Avatar extends StatelessWidget {
  final String name;
  final String? department;
  final double size;

  const Avatar({
    super.key,
    required this.name,
    this.department = 'Engineering',
    this.size = 80,
  });

  String get initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';

    final parts = trimmed.split(' ').where((n) => n.isNotEmpty).toList();
    if (parts.length >= 2) {
      // First letter of first and last word
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    } else {
      // Single word — take up to 2 characters
      final word = parts.first;
      return word.substring(0, word.length >= 2 ? 2 : 1).toUpperCase();
    }
  }

  LinearGradient get gradient {
    final departmentGradients = {
      'Engineering': const LinearGradient(
        colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'Management': const LinearGradient(
        colors: [Color(0xFFA855F7), Color(0xFFEC4899)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'Design': const LinearGradient(
        colors: [Color(0xFFF97316), Color(0xFFFBBF24)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'Human Resources': const LinearGradient(
        colors: [Color(0xFFEF4444), Color(0xFFF43F5E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'Quality Assurance': const LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF14B8A6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'Marketing': const LinearGradient(
        colors: [Color(0xFFEAB308), Color(0xFFF97316)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    };

    return departmentGradients[department] ??
        const LinearGradient(
          colors: [Color(0xFF64748B), Color(0xFF475569)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(size / 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: size / 2.6,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
