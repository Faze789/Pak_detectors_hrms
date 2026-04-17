// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import '../../../models/payroll_model.dart';
// import '../../../viewmodels/payroll_viewmodel.dart';
//
// final _numFmt = NumberFormat('#,###', 'en_US');
// String _pkr(double v) => 'Rs ${_numFmt.format(v.round())}';
//
// class PayslipSheet extends StatefulWidget {
//   final PayrollRecord record;
//   final PayrollViewModel vm;
//
//   const PayslipSheet({
//     super.key,
//     required this.record,
//     required this.vm,
//   });
//
//   @override
//   State<PayslipSheet> createState() => _PayslipSheetState();
// }
//
// class _PayslipSheetState extends State<PayslipSheet>
//     with SingleTickerProviderStateMixin {
//   late TabController _tab;
//   late List<AttendanceDeduction> _deductions;
//   String _deductionType = 'late';
//   final _descCtrl = TextEditingController();
//   final _amountCtrl = TextEditingController();
//   DateTime _date = DateTime.now();
//   bool _saving = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _tab = TabController(length: 2, vsync: this);
//     _deductions = List.from(widget.record.attendanceDeductions);
//   }
//
//   @override
//   void dispose() {
//     _tab.dispose();
//     _descCtrl.dispose();
//     _amountCtrl.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return DraggableScrollableSheet(
//       expand: false,
//       initialChildSize: 0.92,
//       maxChildSize: 0.95,
//       builder: (_, ctrl) => Container(
//         decoration: const BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//         ),
//         child: Column(
//           children: [
//             // Handle
//             Center(
//               child: Container(
//                 margin: const EdgeInsets.only(top: 8),
//                 width: 40,
//                 height: 4,
//                 decoration: BoxDecoration(
//                   color: Colors.grey.shade300,
//                   borderRadius: BorderRadius.circular(2),
//                 ),
//               ),
//             ),
//             // Header
//             Padding(
//               padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
//               child: Row(
//                 children: [
//                   const Icon(Icons.receipt_long,
//                       color: Color(0xFF2563EB), size: 22),
//                   const SizedBox(width: 10),
//                   Text(
//                     'Payslip – ${widget.record.employeeName}',
//                     style: const TextStyle(
//                         fontWeight: FontWeight.bold, fontSize: 16),
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 10),
//             TabBar(
//               controller: _tab,
//               labelColor: const Color(0xFF2563EB),
//               unselectedLabelColor: Colors.grey,
//               indicatorColor: const Color(0xFF2563EB),
//               tabs: const [
//                 Tab(text: 'Deductions'),
//                 Tab(text: 'Preview'),
//               ],
//             ),
//             Expanded(
//               child: TabBarView(
//                 controller: _tab,
//                 children: [
//                   _DeductionsTab(
//                     deductions: _deductions,
//                     deductionType: _deductionType,
//                     descCtrl: _descCtrl,
//                     amountCtrl: _amountCtrl,
//                     date: _date,
//                     onTypeChanged: (v) =>
//                         setState(() => _deductionType = v),
//                     onDateChanged: (d) => setState(() => _date = d),
//                     onAdd: _addDeduction,
//                     onRemove: _removeDeduction,
//                   ),
//                   _PreviewTab(
//                     record: widget.record,
//                     deductions: _deductions,
//                   ),
//                 ],
//               ),
//             ),
//             // Footer
//             Padding(
//               padding: EdgeInsets.fromLTRB(
//                   16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
//               child: Row(
//                 children: [
//                   Expanded(
//                     child: OutlinedButton(
//                       onPressed: () => Navigator.pop(context),
//                       child: const Text('Cancel'),
//                     ),
//                   ),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     flex: 2,
//                     child: ElevatedButton.icon(
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: const Color(0xFF2563EB),
//                         padding: const EdgeInsets.symmetric(vertical: 14),
//                         shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(10)),
//                       ),
//                       onPressed: _saving ? null : _save,
//                       icon: _saving
//                           ? const SizedBox(
//                           width: 16,
//                           height: 16,
//                           child: CircularProgressIndicator(
//                               strokeWidth: 2, color: Colors.white))
//                           : const Icon(Icons.save, color: Colors.white, size: 18),
//                       label: Text(
//                         _saving ? 'Saving...' : 'Generate & Save',
//                         style: const TextStyle(color: Colors.white),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   void _addDeduction() {
//     if (_descCtrl.text.isEmpty ||
//         double.tryParse(_amountCtrl.text) == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//               content: Text('Please fill description and amount')));
//       return;
//     }
//     setState(() {
//       _deductions.add(AttendanceDeduction(
//         id: DateTime.now().millisecondsSinceEpoch.toString(),
//         type: _deductionType == 'late'
//             ? AttendanceDeductionType.late
//             : _deductionType == 'absent'
//             ? AttendanceDeductionType.absent
//             : AttendanceDeductionType.other,
//         description: _descCtrl.text,
//         amount: double.parse(_amountCtrl.text),
//         date: _date,
//       ));
//       _descCtrl.clear();
//       _amountCtrl.clear();
//     });
//   }
//
//   void _removeDeduction(String id) {
//     setState(() => _deductions.removeWhere((d) => d.id == id));
//   }
//
//   Future<void> _save() async {
//     setState(() => _saving = true);
//     await widget.vm.updateAttendanceDeductions(
//         widget.record.employeeId, _deductions);
//     if (mounted) {
//       Navigator.pop(context);
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//             content: Text('Payslip saved successfully!'),
//             backgroundColor: Color(0xFF10B981)),
//       );
//     }
//   }
// }
//
// class _DeductionsTab extends StatelessWidget {
//   final List<AttendanceDeduction> deductions;
//   final String deductionType;
//   final TextEditingController descCtrl;
//   final TextEditingController amountCtrl;
//   final DateTime date;
//   final Function(String) onTypeChanged;
//   final Function(DateTime) onDateChanged;
//   final VoidCallback onAdd;
//   final Function(String) onRemove;
//
//   const _DeductionsTab({
//     required this.deductions,
//     required this.deductionType,
//     required this.descCtrl,
//     required this.amountCtrl,
//     required this.date,
//     required this.onTypeChanged,
//     required this.onDateChanged,
//     required this.onAdd,
//     required this.onRemove,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final total = deductions.fold(0.0, (s, d) => s + d.amount);
//
//     return ListView(
//       padding: const EdgeInsets.all(16),
//       children: [
//         // Add form
//         Container(
//           padding: const EdgeInsets.all(14),
//           decoration: BoxDecoration(
//             color: const Color(0xFFEFF6FF),
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: const Color(0xFFBFDBFE)),
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text('Add Attendance Deduction',
//                   style: TextStyle(fontWeight: FontWeight.bold)),
//               const SizedBox(height: 12),
//               Row(
//                 children: [
//                   Expanded(
//                     child: DropdownButtonFormField<String>(
//                       value: deductionType,
//                       decoration: _dec('Type'),
//                       items: [
//                         const DropdownMenuItem(value: 'late', child: Text('Late Arrival')),
//                         const DropdownMenuItem(value: 'absent', child: Text('Absent')),
//                         const DropdownMenuItem(value: 'other', child: Text('Other')),
//                       ],
//                       onChanged: (v) => onTypeChanged(v!),
//                     ),
//                   ),
//                   const SizedBox(width: 10),
//                   Expanded(
//                     child: InkWell(
//                       onTap: () async {
//                         final d = await showDatePicker(
//                           context: context,
//                           initialDate: date,
//                           firstDate: DateTime(2020),
//                           lastDate: DateTime.now(),
//                         );
//                         if (d != null) onDateChanged(d);
//                       },
//                       child: InputDecorator(
//                         decoration: _dec('Date'),
//                         child: Text(
//                             '${date.day}/${date.month}/${date.year}',
//                             style: const TextStyle(fontSize: 13)),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 10),
//               TextField(
//                 controller: descCtrl,
//                 decoration: _dec('Description (e.g. Late 2 hours)'),
//               ),
//               const SizedBox(height: 10),
//               TextField(
//                 controller: amountCtrl,
//                 decoration: _dec('Amount (Rs)'),
//                 keyboardType: TextInputType.number,
//               ),
//               const SizedBox(height: 12),
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton.icon(
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: const Color(0xFF2563EB),
//                     shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(8)),
//                   ),
//                   onPressed: onAdd,
//                   icon: const Icon(Icons.add, color: Colors.white, size: 18),
//                   label: const Text('Add Deduction',
//                       style: TextStyle(color: Colors.white)),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         const SizedBox(height: 16),
//         if (deductions.isEmpty)
//           const Center(
//             child: Padding(
//               padding: EdgeInsets.all(24),
//               child: Column(
//                 children: [
//                   Icon(Icons.check_circle_outline,
//                       size: 50, color: Color(0xFF10B981)),
//                   SizedBox(height: 8),
//                   Text('No deductions added',
//                       style: TextStyle(color: Colors.grey)),
//                 ],
//               ),
//             ),
//           )
//         else ...[
//           const Text('Current Deductions',
//               style: TextStyle(fontWeight: FontWeight.bold)),
//           const SizedBox(height: 8),
//           ...deductions.map((d) => _deductionTile(d)),
//           const SizedBox(height: 10),
//           Container(
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: const Color(0xFFFEF2F2),
//               borderRadius: BorderRadius.circular(8),
//               border: Border.all(color: const Color(0xFFFECACA)),
//             ),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 const Text('Total Attendance Deductions:',
//                     style: TextStyle(fontWeight: FontWeight.bold)),
//                 Text(_pkr(total),
//                     style: const TextStyle(
//                         color: Color(0xFFEF4444),
//                         fontWeight: FontWeight.bold,
//                         fontSize: 16)),
//               ],
//             ),
//           ),
//         ],
//       ],
//     );
//   }
//
//   Widget _deductionTile(AttendanceDeduction d) {
//     final typeColors = {
//       AttendanceDeductionType.late: [const Color(0xFFFEF9C3), const Color(0xFF854D0E)],
//       AttendanceDeductionType.absent: [const Color(0xFFFEF2F2), const Color(0xFF991B1B)],
//       AttendanceDeductionType.other: [const Color(0xFFF1F5F9), const Color(0xFF475569)],
//     };
//     final colors = typeColors[d.type]!;
//     final labels = {
//       AttendanceDeductionType.late: 'LATE',
//       AttendanceDeductionType.absent: 'ABSENT',
//       AttendanceDeductionType.other: 'OTHER',
//     };
//
//     return Container(
//       margin: const EdgeInsets.only(bottom: 8),
//       padding: const EdgeInsets.all(10),
//       decoration: BoxDecoration(
//         color: const Color(0xFFF8FAFC),
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: const Color(0xFFE2E8F0)),
//       ),
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//             decoration: BoxDecoration(
//               color: colors[0] as Color,
//               borderRadius: BorderRadius.circular(4),
//             ),
//             child: Text(labels[d.type]!,
//                 style: TextStyle(
//                     color: colors[1] as Color,
//                     fontSize: 9,
//                     fontWeight: FontWeight.bold)),
//           ),
//           const SizedBox(width: 8),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(d.description,
//                     style: const TextStyle(
//                         fontSize: 12, fontWeight: FontWeight.w500)),
//                 Text('${d.date.day}/${d.date.month}/${d.date.year}',
//                     style: const TextStyle(
//                         fontSize: 10, color: Colors.grey)),
//               ],
//             ),
//           ),
//           Text(_pkr(d.amount),
//               style: const TextStyle(
//                   color: Color(0xFFEF4444),
//                   fontWeight: FontWeight.bold,
//                   fontSize: 13)),
//           const SizedBox(width: 6),
//           IconButton(
//             icon: const Icon(Icons.close, size: 16, color: Colors.grey),
//             onPressed: () => onRemove(d.id),
//             padding: EdgeInsets.zero,
//             constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
//           ),
//         ],
//       ),
//     );
//   }
//
//   InputDecoration _dec(String label) => InputDecoration(
//     labelText: label,
//     border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
//     contentPadding:
//     const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//     isDense: true,
//   );
// }
//
// // ─── Preview Tab ───────────────────────────────
//
// class _PreviewTab extends StatelessWidget {
//   final PayrollRecord record;
//   final List<AttendanceDeduction> deductions;
//
//   const _PreviewTab({required this.record, required this.deductions});
//
//   @override
//   Widget build(BuildContext context) {
//     final totalAttDed = deductions.fold(0.0, (s, d) => s + d.amount);
//     final totalDed = record.tax + record.otherDeductions + totalAttDed + record.performanceDeductionAmount;
//     final net = record.grossEarnings - totalDed;
//
//     return ListView(
//       padding: const EdgeInsets.all(16),
//       children: [
//         Container(
//           padding: const EdgeInsets.all(20),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
//             borderRadius: BorderRadius.circular(12),
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // Header
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   const Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text('PAYSLIP',
//                           style: TextStyle(
//                               fontWeight: FontWeight.bold,
//                               fontSize: 22,
//                               letterSpacing: 2)),
//                       Text('Salary Statement',
//                           style: TextStyle(
//                               color: Colors.grey, fontSize: 12)),
//                     ],
//                   ),
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.end,
//                     children: [
//                       Text('ID: ${record.employeeCode}',
//                           style: const TextStyle(
//                               fontWeight: FontWeight.w600,
//                               fontSize: 12)),
//                       Text(DateFormat('MMMM yyyy')
//                           .format(DateTime.now()),
//                           style: const TextStyle(
//                               color: Colors.grey, fontSize: 11)),
//                     ],
//                   ),
//                 ],
//               ),
//               const Divider(height: 24),
//               // Employee info grid
//               _infoGrid([
//                 ['Employee', record.employeeName],
//                 ['Designation', record.role],
//                 ['Department', record.department],
//                 ['Location', record.location],
//               ]),
//               const SizedBox(height: 16),
//               // Earnings
//               _sectionHeader('Earnings'),
//               _lineItem('Basic Salary', _pkr(record.basic)),
//               _lineItem('Bonus', '+${_pkr(record.bonus)}'),
//               _lineItem('Allowance', '+${_pkr(record.allowance)}'),
//               _lineItem('Overtime', '+${_pkr(record.overtime)}'),
//               _boldLine('Gross Earnings', _pkr(record.grossEarnings),
//                   const Color(0xFF10B981)),
//               const SizedBox(height: 12),
//               // Deductions
//               _sectionHeader('Deductions'),
//               _lineItem('Tax', '-${_pkr(record.tax)}'),
//               _lineItem('Other Deductions', '-${_pkr(record.otherDeductions)}'),
//               if (record.performanceDeductionPercent > 0)
//                 _lineItem(
//                   'Performance Deduction (${record.performanceDeductionPercent.round()}%)',
//                   '-${_pkr(record.performanceDeductionAmount)}',
//                 ),
//               ...deductions.map((d) => _lineItem(
//                   '${d.type == AttendanceDeductionType.late ? '🕐' : '❌'} ${d.description}',
//                   '-${_pkr(d.amount)}')),
//               _boldLine('Total Deductions', '-${_pkr(totalDed)}',
//                   const Color(0xFFEF4444)),
//               const SizedBox(height: 16),
//               // Net salary
//               Container(
//                 padding: const EdgeInsets.all(14),
//                 decoration: BoxDecoration(
//                   gradient: const LinearGradient(
//                     colors: [Color(0xFFEFF6FF), Color(0xFFEEF2FF)],
//                   ),
//                   borderRadius: BorderRadius.circular(10),
//                   border: Border.all(color: const Color(0xFFBFDBFE)),
//                 ),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     const Text('NET SALARY (Take Home)',
//                         style: TextStyle(
//                             fontWeight: FontWeight.bold, fontSize: 14)),
//                     Text(_pkr(net),
//                         style: const TextStyle(
//                             color: Color(0xFF2563EB),
//                             fontWeight: FontWeight.bold,
//                             fontSize: 20)),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 16),
//               // Payment info
//               _infoGrid([
//                 ['Employee ID', record.employeeCode],
//                 ['Payment Date', DateFormat('dd/MM/yyyy').format(DateTime.now())],
//               ]),
//               const SizedBox(height: 16),
//               const Divider(),
//               const Center(
//                 child: Text(
//                   'Computer generated payslip. No signature required.\nFor discrepancies, contact HR.',
//                   textAlign: TextAlign.center,
//                   style: TextStyle(fontSize: 10, color: Colors.grey),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _sectionHeader(String title) => Padding(
//     padding: const EdgeInsets.only(bottom: 6),
//     child: Text(title.toUpperCase(),
//         style: const TextStyle(
//             fontWeight: FontWeight.bold,
//             fontSize: 11,
//             color: Color(0xFF6B7280),
//             letterSpacing: 1)),
//   );
//
//   Widget _lineItem(String label, String value) => Padding(
//     padding: const EdgeInsets.symmetric(vertical: 3),
//     child: Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Text(label,
//             style: const TextStyle(
//                 color: Color(0xFF6B7280), fontSize: 12)),
//         Text(value,
//             style: const TextStyle(
//                 fontSize: 12, fontWeight: FontWeight.w500)),
//       ],
//     ),
//   );
//
//   Widget _boldLine(String label, String value, Color color) => Container(
//     margin: const EdgeInsets.only(top: 4),
//     padding: const EdgeInsets.symmetric(vertical: 4),
//     decoration: const BoxDecoration(
//       border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
//     ),
//     child: Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Text(label,
//             style: const TextStyle(
//                 fontWeight: FontWeight.bold, fontSize: 13)),
//         Text(value,
//             style: TextStyle(
//                 color: color,
//                 fontWeight: FontWeight.bold,
//                 fontSize: 15)),
//       ],
//     ),
//   );
//
//   Widget _infoGrid(List<List<String>> items) {
//     return Wrap(
//       spacing: 16,
//       runSpacing: 8,
//       children: items
//           .map((i) => SizedBox(
//         width: 160,
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(i[0].toUpperCase(),
//                 style: const TextStyle(
//                     fontSize: 9,
//                     color: Colors.grey,
//                     fontWeight: FontWeight.bold,
//                     letterSpacing: 0.5)),
//             const SizedBox(height: 2),
//             Text(i[1],
//                 style: const TextStyle(
//                     fontWeight: FontWeight.bold,
//                     fontSize: 13)),
//           ],
//         ),
//       ))
//           .toList(),
//     );
//   }
// }