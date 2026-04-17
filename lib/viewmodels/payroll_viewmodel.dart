// ============================================================
// PAYROLL VIEWMODEL — Simplified
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/payroll_model.dart';
import '../services/payroll_service.dart';

enum HRPayrollTab { overview, runPayroll, configure, history }

class HRPayrollViewModel extends ChangeNotifier {
  final PayrollService service;
  final String hrUserId;

  HRPayrollViewModel({required this.service, required this.hrUserId}) {
    _init();
  }

  // ── State ────────────────────────────────────────────────────
  HRPayrollTab _activeTab = HRPayrollTab.overview;
  String _selectedMonth   = availableMonths().first;
  bool _isLoading         = false;
  bool _isRunning         = false;
  String _runProgressMessage = '';
  String? _successMessage;
  String? _errorMessage;

  List<PayslipModel>         _payslipsForMonth = [];
  List<PayrollRunModel>      _runHistory       = [];
  List<Map<String, dynamic>> _employees        = [];

  // Configure tab
  bool _showConfigForm          = false;
  PayrollConfigModel? _editingConfig;
  double _editingEmployeeSalary = 0;

  // ── Getters ──────────────────────────────────────────────────
  HRPayrollTab get activeTab            => _activeTab;
  String get selectedMonth              => _selectedMonth;
  bool get isLoading                    => _isLoading;
  bool get isRunning                    => _isRunning;
  String get runProgressMessage         => _runProgressMessage;
  String? get successMessage            => _successMessage;
  String? get errorMessage              => _errorMessage;
  List<PayslipModel> get payslipsForMonth       => _payslipsForMonth;
  List<PayrollRunModel> get runHistory          => _runHistory;
  List<Map<String, dynamic>> get employees      => _employees;
  bool get showConfigForm               => _showConfigForm;
  PayrollConfigModel? get editingConfig => _editingConfig;
  double get editingEmployeeSalary      => _editingEmployeeSalary;

  // ── Overview stats ───────────────────────────────────────────
  double get totalGrossForMonth =>
      _payslipsForMonth.fold(0, (s, p) => s + p.grossPay);

  double get totalNetForMonth =>
      _payslipsForMonth.fold(0, (s, p) => s + p.netPay);

  double get totalPerfDeductionsForMonth =>
      _payslipsForMonth.fold(0, (s, p) => s + p.performanceDeduction);

  double get totalBonusesForMonth =>
      _payslipsForMonth.fold(0, (s, p) => s + p.performanceBonus);

  double get totalAttendanceDeductionsForMonth =>
      _payslipsForMonth.fold(0, (s, p) => s + p.attendanceDeduction);

  int get approvedCount =>
      _payslipsForMonth.where((p) => p.status == PayslipStatus.approved).length;

  int get paidCount =>
      _payslipsForMonth.where((p) => p.status == PayslipStatus.paid).length;

  // ── Init ─────────────────────────────────────────────────────
  Future<void> _init() async {
    await Future.wait([
      _loadPayslips(),
      _loadEmployees(),
      _loadHistory(),
    ]);
  }

  Future<void> _loadPayslips() async {
    try {
      final parts = _parseMonth(_selectedMonth);
      _payslipsForMonth =
      await service.getPayslipsForMonth(parts.$1, parts.$2);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load payslips: $e';
      notifyListeners();
    }
  }

  Future<void> _loadEmployees() async {
    try {
      _employees = await service.getEmployees();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load employees: $e';
      notifyListeners();
    }
  }

  Future<void> _loadHistory() async {
    try {
      _runHistory = await service.getRunHistory();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load history: $e');
    }
  }

  // ── Tab / Month ──────────────────────────────────────────────
  void setTab(HRPayrollTab tab) {
    _activeTab = tab;
    notifyListeners();
  }

  void setMonth(String month) {
    _selectedMonth = month;
    _loadPayslips();
    notifyListeners();
  }

  // ── Run payroll ───────────────────────────────────────────────
  Future<void> runPayroll() async {
    _isRunning = true;
    _runProgressMessage = 'Preparing payroll…';
    notifyListeners();

    try {
      final parts = _parseMonth(_selectedMonth);

      _runProgressMessage = 'Pulling salary & attendance data…';
      notifyListeners();

      _payslipsForMonth = await service.runPayroll(
        month:    _selectedMonth,
        monthNum: parts.$1,
        year:     parts.$2,
        hrUserId: hrUserId,
      );

      _runProgressMessage = 'Saving payslips…';
      notifyListeners();

      await _loadHistory();
      _successMessage =
      'Payroll run complete — ${_payslipsForMonth.length} payslips generated';
    } catch (e) {
      _errorMessage = 'Payroll run failed: $e';
    } finally {
      _isRunning = false;
      _runProgressMessage = '';
      notifyListeners();
    }
  }

  // ── Payslip actions ───────────────────────────────────────────
  Future<void> approvePayslip(String id) async {
    try {
      await service.approvePayslip(id);
      await _loadPayslips();
      _successMessage = 'Payslip approved';
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to approve: $e';
      notifyListeners();
    }
  }

  Future<void> markAsPaid(String id) async {
    try {
      await service.markAsPaid(id);
      await _loadPayslips();
      _successMessage = 'Marked as paid';
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to update status: $e';
      notifyListeners();
    }
  }

  Future<void> deletePayslip(String id) async {
    try {
      await service.deletePayslip(id);
      await _loadPayslips();
      _successMessage = 'Payslip deleted';
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to delete: $e';
      notifyListeners();
    }
  }

  // ── Configure ─────────────────────────────────────────────────
  Future<void> openConfigForEmployee(String employeeId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final emp = _employees.firstWhere(
            (e) => e['id'] == employeeId,
        orElse: () => <String, dynamic>{},
      );

      PayrollConfigModel? config = await service.getConfig(employeeId);

      config ??= PayrollConfigModel.empty(
        employeeId,
        emp['name'] as String? ?? '',
      );

      _editingEmployeeSalary = (emp['salary'] as num?)?.toDouble() ?? 0;
      _editingConfig  = config;
      _showConfigForm = true;
    } catch (e) {
      _errorMessage = 'Failed to load config: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateEditingConfig(PayrollConfigModel config) {
    _editingConfig = config;
    notifyListeners();
  }

  Future<void> saveConfig() async {
    if (_editingConfig == null) return;
    try {
      await service.saveConfig(_editingConfig!);
      _showConfigForm        = false;
      _editingConfig         = null;
      _editingEmployeeSalary = 0;
      _successMessage        = 'Configuration saved';
    } catch (e) {
      _errorMessage = 'Failed to save: $e';
    }
    notifyListeners();
  }

  void cancelConfig() {
    _showConfigForm        = false;
    _editingConfig         = null;
    _editingEmployeeSalary = 0;
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────
  void clearMessages() {
    _successMessage = null;
    _errorMessage   = null;
    notifyListeners();
  }

  (int, int) _parseMonth(String label) {
    final dt = DateFormat('MMMM yyyy').parse(label);
    return (dt.month, dt.year);
  }

  static List<String> availableMonths() {
    final now = DateTime.now();
    return List.generate(12, (i) {
      final d = DateTime(now.year, now.month - i);
      return DateFormat('MMMM yyyy').format(d);
    });
  }
}

// ─────────────────────────────────────────────────────────────
// EMPLOYEE PAYSLIP VIEWMODEL
// ─────────────────────────────────────────────────────────────
class EmployeePayslipViewModel extends ChangeNotifier {
  final PayrollService service;
  final String employeeId;

  EmployeePayslipViewModel({required this.service, required this.employeeId}) {
    _load();
  }

  List<PayslipModel> _payslips = [];
  bool _isLoading = true;

  List<PayslipModel> get payslips => _payslips;
  bool get isLoading              => _isLoading;

  PayslipModel? get latest =>
      _payslips.isNotEmpty ? _payslips.first : null;

  double get ytdNet =>
      _payslips
          .where((p) => p.year == DateTime.now().year)
          .fold(0.0, (s, p) => s + p.netPay);

  double get ytdDeductions =>
      _payslips
          .where((p) => p.year == DateTime.now().year)
          .fold(0.0, (s, p) => s + p.totalDeductions);

  double get ytdAttendanceDeductions =>
      _payslips
          .where((p) => p.year == DateTime.now().year)
          .fold(0.0, (s, p) => s + p.attendanceDeduction);

  Future<void> _load() async {
    try {
      _payslips = await service.getPayslipsForEmployee(employeeId);
    } catch (e) {
      debugPrint('Failed to load payslips: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}