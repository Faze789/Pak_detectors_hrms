// ============================================================
// EMPLOYEE PAYSLIP SCREEN
// Shows payslip history + full detail + attendance deductions.
// PDF generation via `pdf` + `printing` packages.
//
// pubspec.yaml dependencies needed:
//   pdf: ^3.10.8
//   printing: ^5.12.0
//   path_provider: ^2.1.2
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../models/payroll_model.dart';
import '../../services/payroll_service.dart';
import '../../viewmodels/payroll_viewmodel.dart';
import '../HR_views/payroll_screen.dart';
import '../performance_screens/performance_widgets.dart';

// ─────────────────────────────────────────────────────────────
// ENTRY POINT
// ─────────────────────────────────────────────────────────────

class EmployeePayslipScreen extends StatelessWidget {
  final String employeeId;
  final String employeeName;

  const EmployeePayslipScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EmployeePayslipViewModel(
        service: context.read<PayrollService>(),
        employeeId: employeeId,
      ),
      child: _EmployeePayslipBody(employeeName: employeeName),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BODY
// ─────────────────────────────────────────────────────────────

class _EmployeePayslipBody extends StatelessWidget {
  final String employeeName;
  const _EmployeePayslipBody({required this.employeeName});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EmployeePayslipViewModel>();

    return Scaffold(
      backgroundColor: kSlateBg,
      body: CustomScrollView(
        slivers: [
          // ── App bar ────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 1,
            expandedHeight: 110,
            flexibleSpace: FlexibleSpaceBar(
              background: Padding(
                padding: const EdgeInsets.fromLTRB(20, 48, 20, 8),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                        ),
                        borderRadius: BorderRadius.circular(23),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        employeeName
                            .split(' ')
                            .map((n) => n.isNotEmpty ? n[0] : '')
                            .take(2)
                            .join(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          employeeName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: kSlateDark,
                          ),
                        ),
                        const Text(
                          'My Payslips',
                          style: TextStyle(fontSize: 12, color: kSlate),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Content ────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (vm.isLoading) ...[
                  const SizedBox(height: 60),
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 60),
                ] else ...[
                  // ── YTD summary cards ────────────────────────
                  if (vm.payslips.isNotEmpty) ...[
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 2.2,
                      children: [
                        StatCard(
                          title: 'YTD Net Pay',
                          value: _pkr(vm.ytdNet),
                          icon: Icons.payments_rounded,
                          color: kGreen,
                        ),
                        StatCard(
                          title: 'YTD Deductions',
                          value: _pkr(vm.ytdDeductions),
                          icon: Icons.trending_down_rounded,
                          color: kRed,
                        ),
                      ],
                    ),
                    // Attendance deduction YTD if any
                    if (vm.ytdAttendanceDeductions > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFED7AA)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 16,
                              color: Color(0xFFEA580C),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'YTD Attendance Deductions',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF92400E),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '-${_pkr(vm.ytdAttendanceDeductions)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFEA580C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],

                  // ── Latest payslip hero ──────────────────────
                  if (vm.latest != null) ...[
                    Row(
                      children: [
                        const Text(
                          'Latest Payslip',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _PayslipStatusChip(status: vm.latest!.status),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Dark hero card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          // Net pay + period
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'NET PAY',
                                    style: TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 11,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  Text(
                                    'PKR ${vm.latest!.netPay.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: Color(0xFF34D399),
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'Pay Period',
                                    style: TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    vm.latest!.month,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Divider(color: Color(0xFF334155), height: 24),

                          // Breakdown row
                          Row(
                            children: [
                              _DarkStat('Basic', vm.latest!.basicSalary),
                              _DarkStat('Gross', vm.latest!.grossPay),
                              _DarkStat(
                                'Deductions',
                                vm.latest!.totalDeductions,
                                isNegative: true,
                              ),
                            ],
                          ),

                          // Deduction badges
                          if (vm.latest!.performanceDeduction > 0 ||
                              vm.latest!.performanceBonus > 0 ||
                              vm.latest!.attendanceDeduction > 0) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                if (vm.latest!.attendanceDeduction > 0)
                                  _DarkStatLabel(
                                    '⏰ Attendance',
                                    vm.latest!.attendanceDeduction,
                                    const Color(0xFFFBBF24),
                                  ),
                                if (vm.latest!.performanceDeduction > 0)
                                  _DarkStatLabel(
                                    '⚠ Perf Deduction',
                                    vm.latest!.performanceDeduction,
                                    const Color(0xFFFCA5A5),
                                  ),
                                if (vm.latest!.performanceBonus > 0)
                                  _DarkStatLabel(
                                    '★ Perf Bonus',
                                    vm.latest!.performanceBonus,
                                    const Color(0xFF34D399),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Action buttons row
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    PayslipDetailScreen(payslip: vm.latest!),
                              ),
                            ),
                            icon: const Icon(
                              Icons.receipt_long_rounded,
                              size: 16,
                            ),
                            label: const Text('View Full'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kBlue,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _PdfDownloadButton(payslip: vm.latest!),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                  ],

                  // ── History list ─────────────────────────────
                  const Text(
                    'Payslip History',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  if (vm.payslips.isEmpty)
                    const EmptyState(
                      message: 'No payslips yet. Ask HR to run payroll.',
                    )
                  else
                    ...vm.payslips.map(
                      (p) => _PayslipHistoryTile(
                        payslip: p,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PayslipDetailScreen(payslip: p),
                          ),
                        ),
                      ),
                    ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _pkr(double v) =>
      'PKR ${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
}

// ─────────────────────────────────────────────────────────────
// PDF DOWNLOAD BUTTON
// ─────────────────────────────────────────────────────────────

class _PdfDownloadButton extends StatefulWidget {
  final PayslipModel payslip;
  const _PdfDownloadButton({required this.payslip});

  @override
  State<_PdfDownloadButton> createState() => _PdfDownloadButtonState();
}

class _PdfDownloadButtonState extends State<_PdfDownloadButton> {
  bool _generating = false;

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      final bytes = await PayslipPdfGenerator.generate(widget.payslip);
      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'Payslip_${widget.payslip.employeeName.replaceAll(' ', '_')}_${widget.payslip.month.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: kRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _generating ? null : _generate,
      icon: _generating
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.download_rounded, size: 16),
      label: Text(_generating ? 'Generating…' : 'Download PDF'),
      style: ElevatedButton.styleFrom(
        backgroundColor: kBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PDF GENERATOR
// ─────────────────────────────────────────────────────────────

class PayslipPdfGenerator {
  // Company branding colors
  static const _dark = PdfColor.fromInt(0xFF0F172A);
  static const _blue = PdfColor.fromInt(0xFF2563EB);
  static const _green = PdfColor.fromInt(0xFF10B981);
  static const _red = PdfColor.fromInt(0xFFEF4444);
  static const _orange = PdfColor.fromInt(0xFFEA580C);
  static const _slate = PdfColor.fromInt(0xFF64748B);
  static const _slate50 = PdfColor.fromInt(0xFFF8FAFC);
  static const _slate100 = PdfColor.fromInt(0xFFF1F5F9);
  static const _border = PdfColor.fromInt(0xFFE2E8F0);

  static Future<Uint8List> generate(PayslipModel p) async {
    final doc = pw.Document(
      title: 'Payslip — ${p.month}',
      author: 'Pakistan Detector Technologies',
      subject: '${p.employeeName} — ${p.month}',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (ctx) => [
          _header(p),
          pw.SizedBox(height: 20),
          _earningsSection(p),
          pw.SizedBox(height: 16),
          _deductionsSection(p),
          pw.SizedBox(height: 16),
          _netPayBox(p),
          if (p.attendanceDeduction > 0) ...[
            pw.SizedBox(height: 16),
            _attendanceSection(p),
          ],
          if (p.totalTasksInMonth > 0) ...[
            pw.SizedBox(height: 16),
            _performanceSection(p),
          ],
          pw.SizedBox(height: 24),
          _footer(p),
        ],
      ),
    );

    return doc.save();
  }

  // ── Header ──────────────────────────────────────────────────
  static pw.Widget _header(PayslipModel p) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: _dark,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'PAKISTAN DETECTOR TECHNOLOGIES',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Gulberg Trade Center, Islamabad',
                    style: pw.TextStyle(color: _slate, fontSize: 9),
                  ),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: pw.BoxDecoration(
                  color: _statusBgColor(p.status),
                  borderRadius: pw.BorderRadius.circular(20),
                ),
                child: pw.Text(
                  p.status.name.toUpperCase(),
                  style: pw.TextStyle(
                    color: _statusFgColor(p.status),
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Divider(color: const PdfColor.fromInt(0xFF334155)),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'EMPLOYEE',
                    style: pw.TextStyle(color: _slate, fontSize: 8),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    p.employeeName,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    p.employeeRole,
                    style: pw.TextStyle(color: _slate, fontSize: 9),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'PAY PERIOD',
                    style: pw.TextStyle(color: _slate, fontSize: 8),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    p.month,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'NET PAY',
                    style: pw.TextStyle(color: _slate, fontSize: 8),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'PKR ${_fmt(p.netPay)}',
                    style: pw.TextStyle(
                      color: _green,
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Earnings ─────────────────────────────────────────────────
  static pw.Widget _earningsSection(PayslipModel p) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: _cardDec(),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('EARNINGS', _green),
          pw.SizedBox(height: 10),
          _lineItem('Basic Salary', p.basicSalary),
          ...p.allowances.map((a) => _lineItem(a.name, a.amount)),
          if (p.performanceBonus > 0)
            _lineItem(
              'Performance Bonus',
              p.performanceBonus,
              valueColor: _green,
              bold: true,
            ),
          _divider(),
          _lineItem('Gross Pay', p.grossPay, bold: true),
        ],
      ),
    );
  }

  // ── Deductions ───────────────────────────────────────────────
  static pw.Widget _deductionsSection(PayslipModel p) {
    final rows = <pw.Widget>[];
    if (p.loanDeduction > 0) {
      rows.add(_lineItem('Loan Repayment', p.loanDeduction, isDeduction: true));
    }
    if (p.performanceDeduction > 0) {
      rows.add(
        _lineItem(
          'Performance Deduction (${p.missedTasks} missed tasks)',
          p.performanceDeduction,
          isDeduction: true,
        ),
      );
    }
    if (p.attendanceDeduction > 0) {
      rows.add(_attendanceSummaryLine(p));
    }

    if (rows.isEmpty) return pw.SizedBox();

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: _cardDec(),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('DEDUCTIONS', _red),
          pw.SizedBox(height: 10),
          ...rows,
          _divider(),
          _lineItem(
            'Total Deductions',
            p.totalDeductions,
            bold: true,
            isDeduction: true,
          ),
        ],
      ),
    );
  }

  static pw.Widget _attendanceSummaryLine(PayslipModel p) {
    final s = p.attendanceSummary;
    final parts = <String>[];
    if (s.absentDays > 0) parts.add('${s.absentDays} absent');
    if (s.lateSevereDays > 0) parts.add('${s.lateSevereDays} late >10AM');
    if (s.lateMildDays > 0) parts.add('${s.lateMildDays} late 9–10AM');
    if (s.earlySevereDays > 0) parts.add('${s.earlySevereDays} early <5PM');
    if (s.earlyMildDays > 0) parts.add('${s.earlyMildDays} early 5–6PM');
    if (s.underworkedDays > 0) parts.add('${s.underworkedDays} <4h work');

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Attendance Deduction',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: _orange,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                parts.join(' · '),
                style: pw.TextStyle(fontSize: 8, color: _slate),
              ),
            ],
          ),
          pw.Text(
            '-PKR ${_fmt(p.attendanceDeduction)}',
            style: pw.TextStyle(
              fontSize: 10,
              color: _orange,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ── Net pay box ──────────────────────────────────────────────
  static pw.Widget _netPayBox(PayslipModel p) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _dark,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'NET PAY',
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            'PKR ${_fmt(p.netPay)}',
            style: pw.TextStyle(
              color: _green,
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ── Attendance breakdown ─────────────────────────────────────
  static pw.Widget _attendanceSection(PayslipModel p) {
    final s = p.attendanceSummary;

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFFFF7ED),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFFED7AA)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('ATTENDANCE DEDUCTION BREAKDOWN', _orange),
          pw.SizedBox(height: 10),

          // Summary chips row
          pw.Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (s.absentDays > 0)
                _attChip(
                  '${s.absentDays}× Absent',
                  const PdfColor.fromInt(0xFFDC2626),
                ),
              if (s.lateSevereDays > 0)
                _attChip('${s.lateSevereDays}× Late >10AM', _orange),
              if (s.lateMildDays > 0)
                _attChip(
                  '${s.lateMildDays}× Late 9–10AM',
                  const PdfColor.fromInt(0xFFD97706),
                ),
              if (s.earlySevereDays > 0)
                _attChip('${s.earlySevereDays}× Early <5PM', _orange),
              if (s.earlyMildDays > 0)
                _attChip(
                  '${s.earlyMildDays}× Early 5–6PM',
                  const PdfColor.fromInt(0xFFD97706),
                ),
              if (s.underworkedDays > 0)
                _attChip(
                  '${s.underworkedDays}× <4h work',
                  const PdfColor.fromInt(0xFF7C3AED),
                ),
            ],
          ),

          if (s.breakdown.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Divider(color: const PdfColor.fromInt(0xFFFED7AA)),
            pw.SizedBox(height: 8),

            // Day-by-day table
            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(4),
                2: const pw.FlexColumnWidth(2),
              },
              children: [
                // Table header
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFFFEF3C7),
                  ),
                  children: [
                    _tableCell('Date', header: true),
                    _tableCell('Infraction', header: true),
                    _tableCell(
                      'Deduction',
                      header: true,
                      align: pw.TextAlign.right,
                    ),
                  ],
                ),
                ...s.breakdown.map(
                  (d) => pw.TableRow(
                    children: [
                      _tableCell(d.date),
                      _tableCell(d.type.label),
                      _tableCell(
                        '-PKR ${_fmt(d.amount)}',
                        align: pw.TextAlign.right,
                        color: _orange,
                      ),
                    ],
                  ),
                ),
                // Total row
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFFFEF3C7),
                  ),
                  children: [
                    _tableCell('', header: true),
                    _tableCell('Total Attendance Deduction', header: true),
                    _tableCell(
                      '-PKR ${_fmt(p.attendanceDeduction)}',
                      header: true,
                      align: pw.TextAlign.right,
                      color: _orange,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Performance section ──────────────────────────────────────
  static pw.Widget _performanceSection(PayslipModel p) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFEFF6FF),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFBFDBFE)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('PERFORMANCE THIS MONTH', _blue),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              pw.Expanded(
                child: _perfStat('Total Tasks', '${p.totalTasksInMonth}'),
              ),
              pw.Expanded(
                child: _perfStat(
                  'Completed',
                  '${p.completedTasks}',
                  color: _green,
                ),
              ),
              pw.Expanded(
                child: _perfStat(
                  'Missed',
                  '${p.missedTasks}',
                  color: p.missedTasks > 0 ? _red : _slate,
                ),
              ),
              pw.Expanded(
                child: _perfStat('Score', '${p.performanceScore.toInt()}%'),
              ),
            ],
          ),
          if (p.performanceDeduction > 0 || p.performanceBonus > 0) ...[
            pw.SizedBox(height: 8),
            pw.Divider(color: const PdfColor.fromInt(0xFFBFDBFE)),
            pw.SizedBox(height: 6),
            if (p.performanceDeduction > 0)
              _lineItem(
                'Performance Deduction Applied',
                p.performanceDeduction,
                isDeduction: true,
              ),
            if (p.performanceBonus > 0)
              _lineItem(
                'Performance Bonus Applied',
                p.performanceBonus,
                valueColor: _green,
              ),
          ],
        ],
      ),
    );
  }

  // ── Footer ───────────────────────────────────────────────────
  static pw.Widget _footer(PayslipModel p) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _slate100,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: _border),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated: ${DateTime.now().toString().substring(0, 16)}',
            style: pw.TextStyle(fontSize: 8, color: _slate),
          ),
          pw.Text(
            'Pakistan Detector Technologies (Pvt) Ltd',
            style: pw.TextStyle(fontSize: 8, color: _slate),
          ),
          pw.Text(
            'Employee ID: ${p.employeeId}',
            style: pw.TextStyle(fontSize: 8, color: _slate),
          ),
        ],
      ),
    );
  }

  // ── Shared PDF helpers ───────────────────────────────────────

  static pw.Widget _sectionTitle(String text, PdfColor color) => pw.Row(
    children: [
      pw.Container(
        width: 3,
        height: 14,
        color: color,
        margin: const pw.EdgeInsets.only(right: 8),
      ),
      pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: color,
        ),
      ),
    ],
  );

  static pw.Widget _lineItem(
    String label,
    double amount, {
    bool bold = false,
    bool isDeduction = false,
    PdfColor? valueColor,
  }) {
    final vc = valueColor ?? (isDeduction ? _red : (bold ? _dark : _slate));
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 10,
              color: bold ? _dark : _slate,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            '${isDeduction ? '-' : ''}PKR ${_fmt(amount)}',
            style: pw.TextStyle(
              fontSize: 10,
              color: vc,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _divider() => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 6),
    child: pw.Divider(color: _border),
  );

  static pw.Widget _attChip(String label, PdfColor color) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: pw.BoxDecoration(
      color: PdfColor(color.red, color.green, color.blue, 0.1),
      borderRadius: pw.BorderRadius.circular(10),
      border: pw.Border.all(
        color: PdfColor(color.red, color.green, color.blue, 0.4),
      ),
    ),
    child: pw.Text(
      label,
      style: pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: color,
      ),
    ),
  );

  static pw.Widget _perfStat(String label, String value, {PdfColor? color}) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8, color: _slate)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: color ?? _dark,
            ),
          ),
        ],
      );

  static pw.Widget _tableCell(
    String text, {
    bool header = false,
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor? color,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    child: pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(
        fontSize: 9,
        fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color ?? (header ? _dark : _slate),
      ),
    ),
  );

  static pw.BoxDecoration _cardDec() => pw.BoxDecoration(
    color: PdfColors.white,
    borderRadius: pw.BorderRadius.circular(8),
    border: pw.Border.all(color: _border),
  );

  static PdfColor _statusBgColor(PayslipStatus s) => switch (s) {
    PayslipStatus.draft => const PdfColor.fromInt(0xFFE2E8F0),
    PayslipStatus.approved => const PdfColor.fromInt(0xFFDBEAFE),
    PayslipStatus.paid => const PdfColor.fromInt(0xFFD1FAE5),
  };

  static PdfColor _statusFgColor(PayslipStatus s) => switch (s) {
    PayslipStatus.draft => const PdfColor.fromInt(0xFF64748B),
    PayslipStatus.approved => const PdfColor.fromInt(0xFF2563EB),
    PayslipStatus.paid => const PdfColor.fromInt(0xFF059669),
  };

  static String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
}

// ─────────────────────────────────────────────────────────────
// DARK HERO STAT WIDGETS
// ─────────────────────────────────────────────────────────────

class _DarkStat extends StatelessWidget {
  final String label;
  final double amount;
  final bool isNegative;

  const _DarkStat(this.label, this.amount, {this.isNegative = false});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
        ),
        Text(
          '${isNegative ? '-' : ''}PKR ${amount.toStringAsFixed(0)}',
          style: TextStyle(
            color: isNegative ? const Color(0xFFFCA5A5) : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _DarkStatLabel extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _DarkStatLabel(this.label, this.amount, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
        ),
        Text(
          'PKR ${amount.toStringAsFixed(0)}',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// HISTORY TILE
// ─────────────────────────────────────────────────────────────

class _PayslipHistoryTile extends StatelessWidget {
  final PayslipModel payslip;
  final VoidCallback onTap;

  const _PayslipHistoryTile({required this.payslip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kSlate200),
        ),
        child: Row(
          children: [
            // Month badge
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: kBlueSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                _monthBadge(payslip.month),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: kBlue,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Month + task summary
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payslip.month,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (payslip.completedTasks > 0)
                        Text(
                          '${payslip.completedTasks} completed',
                          style: const TextStyle(fontSize: 11, color: kGreen),
                        ),
                      if (payslip.missedTasks > 0) ...[
                        const Text(
                          '  ·  ',
                          style: TextStyle(fontSize: 11, color: kSlate),
                        ),
                        Text(
                          '${payslip.missedTasks} missed',
                          style: const TextStyle(fontSize: 11, color: kRed),
                        ),
                      ],
                      if (payslip.completedTasks == 0 &&
                          payslip.missedTasks == 0)
                        const Text(
                          'No tasks this month',
                          style: TextStyle(fontSize: 11, color: kSlate),
                        ),
                    ],
                  ),
                  // Attendance deduction sub-label
                  if (payslip.attendanceDeduction > 0)
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 10,
                          color: Color(0xFFEA580C),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '-PKR ${payslip.attendanceDeduction.toStringAsFixed(0)} attendance',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFFEA580C),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Net pay + deduction badges
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'PKR ${payslip.netPay.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: kSlateDark,
                  ),
                ),
                if (payslip.performanceDeduction > 0)
                  Text(
                    '-PKR ${payslip.performanceDeduction.toStringAsFixed(0)} perf',
                    style: const TextStyle(fontSize: 10, color: kRed),
                  ),
                if (payslip.loanDeduction > 0)
                  Text(
                    '-PKR ${payslip.loanDeduction.toStringAsFixed(0)} loan',
                    style: const TextStyle(fontSize: 10, color: kSlate),
                  ),
              ],
            ),
            const SizedBox(width: 8),

            // PDF button + status chip column
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _PayslipStatusChip(status: payslip.status),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    final bytes = await PayslipPdfGenerator.generate(payslip);
                    await Printing.sharePdf(
                      bytes: bytes,
                      filename:
                          'Payslip_${payslip.month.replaceAll(' ', '_')}.pdf',
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: kBlueSoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.download_rounded, size: 11, color: kBlue),
                        SizedBox(width: 3),
                        Text(
                          'PDF',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: kBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _monthBadge(String monthLabel) {
    try {
      final parts = monthLabel.trim().split(' ');
      if (parts.length < 2) return monthLabel;
      final shortMonth = parts[0].length >= 3
          ? parts[0].substring(0, 3)
          : parts[0];
      final shortYear = parts[1].length >= 4 ? parts[1].substring(2) : parts[1];
      return '$shortMonth\n$shortYear';
    } catch (_) {
      return monthLabel;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// STATUS CHIP
// ─────────────────────────────────────────────────────────────

class _PayslipStatusChip extends StatelessWidget {
  final PayslipStatus status;
  const _PayslipStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      PayslipStatus.draft => ('Draft', kSlate100, kSlate),
      PayslipStatus.approved => ('Approved', kBlueSoft, kBlue),
      PayslipStatus.paid => ('Paid', kGreenSoft, kGreen),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
