import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/employee_viewmodel.dart';

class ExEmployeesScreen extends StatefulWidget {
  const ExEmployeesScreen({super.key});

  @override
  State<ExEmployeesScreen> createState() => _ExEmployeesScreenState();
}

class _ExEmployeesScreenState extends State<ExEmployeesScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<EmployeeViewModel>().loadExEmployees();
      if (!mounted) return;
      setState(() => _loading = false);
    });
  }

  Future<void> _confirmRestore(String uid, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Restore Employee?'),
        content: Text(
          'This will restore "$name" to the active employee list. '
          'Their data, history, and credentials remain intact.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<EmployeeViewModel>().restoreEmployee(uid);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name restored to active employees'),
        backgroundColor: const Color(0xFF16A34A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Ex-Employees',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<EmployeeViewModel>(
              builder: (ctx, vm, _) {
                final list = vm.exEmployees;
                if (list.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.archive_outlined,
                            size: 56, color: Color(0xFFCBD5E1)),
                        SizedBox(height: 12),
                        Text(
                          'No ex-employees',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Archived employees will appear here.',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFFCBD5E1)),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final e = list[i];
                    final archivedAt = e.archivedAt;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFFF1F5F9),
                            child: Text(
                              e.name.isNotEmpty
                                  ? e.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${e.emp_id} · ${e.department} · ${e.role}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                if (archivedAt != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Archived ${archivedAt.day}/${archivedAt.month}/${archivedAt.year}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _confirmRestore(e.uid, e.name),
                            icon: const Icon(
                              Icons.restore_rounded,
                              size: 14,
                              color: Color(0xFF16A34A),
                            ),
                            label: const Text(
                              'Restore',
                              style: TextStyle(
                                color: Color(0xFF16A34A),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              side: const BorderSide(color: Color(0xFF16A34A)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
