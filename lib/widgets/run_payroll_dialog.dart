// import 'package:flutter/material.dart';
// import '../../../models/payroll_model.dart';
// import '../../../viewmodels/payroll_viewmodel.dart';
//
// class RunPayrollDialog extends StatelessWidget {
//   final PayrollViewModel vm;
//   const RunPayrollDialog({super.key, required this.vm});
//
//   @override
//   Widget build(BuildContext context) {
//     final pending = vm.records
//         .where((r) =>
//     r.status == PayrollStatus.draft ||
//         r.status == PayrollStatus.approved)
//         .toList();
//     final total = pending.fold(0.0, (s, r) => s + r.netSalary);
//
//     return Dialog(
//       shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(16)),
//       child: Padding(
//         padding: const EdgeInsets.all(24),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Container(
//               padding: const EdgeInsets.all(14),
//               decoration: const BoxDecoration(
//                 color: Color(0xFFD1FAE5),
//                 shape: BoxShape.circle,
//               ),
//               child: const Icon(Icons.payments_outlined,
//                   color: Color(0xFF10B981), size: 28),
//             ),
//             const SizedBox(height: 16),
//             const Text('Run Payroll Process',
//                 style: TextStyle(
//                     fontWeight: FontWeight.bold, fontSize: 18)),
//             const SizedBox(height: 6),
//             Text(
//               'Process payroll for ${pending.length} employee(s)',
//               style: const TextStyle(color: Colors.grey, fontSize: 13),
//             ),
//             const SizedBox(height: 20),
//             Container(
//               padding: const EdgeInsets.all(14),
//               decoration: BoxDecoration(
//                 color: const Color(0xFFEFF6FF),
//                 borderRadius: BorderRadius.circular(10),
//               ),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceAround,
//                 children: [
//                   _item('Employees', '${pending.length}',
//                       const Color(0xFF2563EB)),
//                   _item('Total Payout', 'Rs ${total.round()}',
//                       const Color(0xFF10B981)),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 16),
//             if (pending.isNotEmpty)
//               ConstrainedBox(
//                 constraints: const BoxConstraints(maxHeight: 200),
//                 child: ListView.builder(
//                   shrinkWrap: true,
//                   itemCount: pending.length,
//                   itemBuilder: (_, i) {
//                     final r = pending[i];
//                     return ListTile(
//                       dense: true,
//                       title: Text(r.employeeName,
//                           style: const TextStyle(
//                               fontWeight: FontWeight.bold,
//                               fontSize: 13)),
//                       subtitle: Text(r.employeeCode),
//                       trailing: Text('Rs ${r.netSalary.round()}',
//                           style: const TextStyle(
//                               fontWeight: FontWeight.bold,
//                               color: Color(0xFF1E293B))),
//                     );
//                   },
//                 ),
//               ),
//             const SizedBox(height: 16),
//             Container(
//               padding: const EdgeInsets.all(10),
//               decoration: BoxDecoration(
//                 color: const Color(0xFFFEF3C7),
//                 borderRadius: BorderRadius.circular(8),
//                 border: Border.all(color: const Color(0xFFFDE68A)),
//               ),
//               child: const Row(
//                 children: [
//                   Icon(Icons.warning_amber_rounded,
//                       color: Color(0xFFF59E0B), size: 18),
//                   SizedBox(width: 8),
//                   Expanded(
//                     child: Text(
//                       'This will mark all selected employees as Paid. '
//                           'Ensure all payslips and deductions are correct.',
//                       style: TextStyle(
//                           fontSize: 11, color: Color(0xFF92400E)),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 20),
//             Row(
//               children: [
//                 Expanded(
//                   child: OutlinedButton(
//                     onPressed: () => Navigator.pop(context),
//                     child: const Text('Cancel'),
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   flex: 2,
//                   child: ElevatedButton.icon(
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: const Color(0xFF10B981),
//                       padding:
//                       const EdgeInsets.symmetric(vertical: 12),
//                       shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(10)),
//                     ),
//                     onPressed: pending.isEmpty
//                         ? null
//                         : () async {
//                       await vm.runPayroll();
//                       if (context.mounted) Navigator.pop(context);
//                     },
//                     icon: const Icon(Icons.check,
//                         color: Colors.white, size: 18),
//                     label: const Text('Confirm & Process',
//                         style: TextStyle(color: Colors.white)),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _item(String label, String value, Color color) => Column(
//     children: [
//       Text(value,
//           style: TextStyle(
//               color: color,
//               fontWeight: FontWeight.bold,
//               fontSize: 20)),
//       Text(label,
//           style: const TextStyle(
//               color: Colors.grey, fontSize: 12)),
//     ],
//   );
// }