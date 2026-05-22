// lib/views/HR_views/company_letters_screen.dart
//
// HR-side screen. Two tabs:
//   • Compose — pick employee → pick kind → fill fields → edit body →
//     Save & Send (writes Firestore doc + pushes employee notification +
//     opens preview/download).
//   • Sent  — live list of previously-issued letters, tap to re-preview
//     or re-share.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/company_letter.dart';
import '../../services/company_letter_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/employee_viewmodel.dart';
import '../../widgets/letter_pdf.dart';

class CompanyLettersScreen extends StatefulWidget {
  const CompanyLettersScreen({super.key});

  @override
  State<CompanyLettersScreen> createState() => _CompanyLettersScreenState();
}

class _CompanyLettersScreenState extends State<CompanyLettersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  final _service = CompanyLetterService();

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        title: const Text(
          'Company Letters',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        bottom: TabBar(
          controller: _tab,
          labelColor: const Color(0xFF2563EB),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF2563EB),
          tabs: const [
            Tab(text: 'Compose'),
            Tab(text: 'Sent'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _ComposeTab(service: _service),
          _SentListTab(service: _service),
        ],
      ),
    );
  }
}

// ─── Compose tab ─────────────────────────────────────────────────────────────
class _ComposeTab extends StatefulWidget {
  final CompanyLetterService service;
  const _ComposeTab({required this.service});

  @override
  State<_ComposeTab> createState() => _ComposeTabState();
}

class _ComposeTabState extends State<_ComposeTab> {
  String? _selectedEmployeeUid;
  LetterKind _kind = LetterKind.offer;
  DateTime _letterDate = DateTime.now();
  final _bodyCtrl = TextEditingController();
  final _hrTitleCtrl = TextEditingController(text: 'HR Manager');

  // One controller per possible field key. Only the ones relevant to
  // the current LetterKind are rendered in the UI.
  final _positionCtrl = TextEditingController();
  final _oldPositionCtrl = TextEditingController();
  final _newPositionCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController();
  final _newSalaryCtrl = TextEditingController();
  final _stipendCtrl = TextEditingController();
  final _workingDaysCtrl = TextEditingController(text: 'Monday to Friday');
  final _durationMonthsCtrl = TextEditingController(text: '3');
  final _probationMonthsCtrl = TextEditingController(text: '3');
  final _reasonCtrl = TextEditingController();
  final _expectedActionCtrl = TextEditingController();
  final _performanceNoteCtrl = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _effectiveDate;
  DateTime? _incidentDate;
  DateTime? _lastWorkingDay;

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthViewModel>();
      final empVM = context.read<EmployeeViewModel>();
      if (empVM.employees.isEmpty && auth.currentUser != null) {
        await empVM.loadEmployees(auth.currentUser!.uid);
      }
      if (!mounted) return;
      if (empVM.employees.isNotEmpty) {
        setState(() => _selectedEmployeeUid = empVM.employees.first.uid);
        _regenerateBody();
      }
    });
  }

  @override
  void dispose() {
    _bodyCtrl.dispose();
    _hrTitleCtrl.dispose();
    _positionCtrl.dispose();
    _oldPositionCtrl.dispose();
    _newPositionCtrl.dispose();
    _salaryCtrl.dispose();
    _newSalaryCtrl.dispose();
    _stipendCtrl.dispose();
    _workingDaysCtrl.dispose();
    _durationMonthsCtrl.dispose();
    _probationMonthsCtrl.dispose();
    _reasonCtrl.dispose();
    _expectedActionCtrl.dispose();
    _performanceNoteCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _collectFields() {
    final f = <String, dynamic>{};
    final keys = letterKindFields[_kind] ?? const [];
    for (final k in keys) {
      switch (k) {
        case 'position':
          f[k] = _positionCtrl.text.trim();
          break;
        case 'oldPosition':
          f[k] = _oldPositionCtrl.text.trim();
          break;
        case 'newPosition':
          f[k] = _newPositionCtrl.text.trim();
          break;
        case 'salary':
          f[k] = _salaryCtrl.text.trim();
          break;
        case 'newSalary':
          f[k] = _newSalaryCtrl.text.trim();
          break;
        case 'stipend':
          f[k] = _stipendCtrl.text.trim();
          break;
        case 'workingDays':
          f[k] = _workingDaysCtrl.text.trim();
          break;
        case 'durationMonths':
          f[k] = _durationMonthsCtrl.text.trim();
          break;
        case 'probationMonths':
          f[k] = _probationMonthsCtrl.text.trim();
          break;
        case 'reason':
          f[k] = _reasonCtrl.text.trim();
          break;
        case 'expectedAction':
          f[k] = _expectedActionCtrl.text.trim();
          break;
        case 'performanceNote':
          f[k] = _performanceNoteCtrl.text.trim();
          break;
        case 'startDate':
          if (_startDate != null) f[k] = Timestamp.fromDate(_startDate!);
          break;
        case 'endDate':
          if (_endDate != null) f[k] = Timestamp.fromDate(_endDate!);
          break;
        case 'effectiveDate':
          if (_effectiveDate != null) {
            f[k] = Timestamp.fromDate(_effectiveDate!);
          }
          break;
        case 'incidentDate':
          if (_incidentDate != null) {
            f[k] = Timestamp.fromDate(_incidentDate!);
          }
          break;
        case 'lastWorkingDay':
          if (_lastWorkingDay != null) {
            f[k] = Timestamp.fromDate(_lastWorkingDay!);
          }
          break;
      }
    }
    return f;
  }

  String _selectedEmployeeName() {
    final empVM = context.read<EmployeeViewModel>();
    for (final e in empVM.employees) {
      if (e.uid == _selectedEmployeeUid) return e.name;
    }
    return '';
  }

  void _regenerateBody() {
    final name = _selectedEmployeeName();
    if (name.isEmpty) return;
    final body = generateDefaultBody(
      kind: _kind,
      employeeName: name,
      fields: _collectFieldsForGenerator(),
      companyName: 'Pakistan Detector Technologies Pvt. Ltd.',
    );
    _bodyCtrl.text = body;
  }

  /// Converts Timestamps back to DateTime for the generator (which expects
  /// DateTime, not Firestore Timestamps).
  Map<String, dynamic> _collectFieldsForGenerator() {
    final raw = _collectFields();
    final out = <String, dynamic>{};
    raw.forEach((k, v) {
      if (v is Timestamp) {
        out[k] = v.toDate();
      } else {
        out[k] = v;
      }
    });
    return out;
  }

  Future<void> _pickDate({
    required DateTime? current,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF2563EB),
            onPrimary: Colors.white,
            onSurface: Color(0xFF0F172A),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      onPicked(picked);
      setState(() {});
      _regenerateBody();
    }
  }

  CompanyLetter? _buildLetter() {
    final auth = context.read<AuthViewModel>();
    final empVM = context.read<EmployeeViewModel>();
    if (_selectedEmployeeUid == null) return null;
    final emp = empVM.employees.firstWhere(
      (e) => e.uid == _selectedEmployeeUid,
      orElse: () => empVM.employees.first,
    );
    final hrUid = auth.currentUser?.uid ?? '';
    final hrName = auth.currentUser?.name ?? 'HR';
    final now = DateTime.now();
    return CompanyLetter(
      id: '',
      kind: _kind,
      subject: _kind.defaultSubject,
      employeeUid: emp.uid,
      employeeEmpId: emp.emp_id,
      employeeName: emp.name,
      employeeEmail: emp.email,
      letterDate: _letterDate,
      fields: _collectFields(),
      body: _bodyCtrl.text.trim(),
      hrUid: hrUid,
      hrName: hrName,
      hrTitle: _hrTitleCtrl.text.trim().isEmpty
          ? null
          : _hrTitleCtrl.text.trim(),
      companyName: 'Pakistan Detector Technologies Pvt. Ltd.',
      createdAt: now,
    );
  }

  Future<void> _onSaveAndSend() async {
    final letter = _buildLetter();
    if (letter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick an employee first.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final id = await widget.service.createAndSend(letter);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Letter sent to ${letter.employeeName}.'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
      // Re-fetch the persisted doc so the preview/share has the canonical id.
      final saved = await widget.service.getById(id);
      if (saved != null) {
        await previewLetterPdf(saved);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onPreviewOnly() async {
    final letter = _buildLetter();
    if (letter == null) return;
    await previewLetterPdf(letter);
  }

  @override
  Widget build(BuildContext context) {
    final empVM = context.watch<EmployeeViewModel>();
    final employees = empVM.employees;
    final keys = letterKindFields[_kind] ?? const [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Section(
            label: 'Employee',
            child: DropdownButtonFormField<String>(
              initialValue: _selectedEmployeeUid,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              isExpanded: true,
              items: employees
                  .map((e) => DropdownMenuItem(
                        value: e.uid,
                        child: Text(
                          e.name.isNotEmpty ? e.name : e.email,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (v) {
                setState(() => _selectedEmployeeUid = v);
                _regenerateBody();
              },
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            label: 'Letter type',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: LetterKind.values
                  .map((k) => ChoiceChip(
                        label: Text(k.label),
                        selected: _kind == k,
                        onSelected: (_) {
                          setState(() => _kind = k);
                          _regenerateBody();
                        },
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            label: 'Letter date',
            child: OutlinedButton.icon(
              onPressed: () => _pickDate(
                current: _letterDate,
                onPicked: (d) => _letterDate = d,
              ),
              icon: const Icon(Icons.event_rounded, size: 16),
              label: Text(DateFormat('d MMMM, yyyy').format(_letterDate)),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // ── Kind-specific fields ────────────────────────────────────────
          ..._fieldsForKind(keys),
          const SizedBox(height: 12),
          _Section(
            label: 'HR title (signature)',
            child: TextField(
              controller: _hrTitleCtrl,
              decoration: const InputDecoration(
                hintText: 'e.g. HR Manager',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            label: 'Body (editable — tweak before sending)',
            child: TextField(
              controller: _bodyCtrl,
              maxLines: 12,
              minLines: 6,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                helperText:
                    'Use blank lines (Enter twice) to separate paragraphs.',
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _onPreviewOnly,
                  icon: const Icon(Icons.visibility_rounded),
                  label: const Text('Preview PDF'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _onSaveAndSend,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: const Text('Save & Send'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _fieldsForKind(List<String> keys) {
    final widgets = <Widget>[];
    void addText(String key, TextEditingController ctrl, String label,
        {String? hint, TextInputType? type}) {
      widgets.add(_Section(
        label: label,
        child: TextField(
          controller: ctrl,
          keyboardType: type,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: hint,
          ),
          onChanged: (_) => _regenerateBody(),
        ),
      ));
      widgets.add(const SizedBox(height: 12));
    }

    void addDate(String key, DateTime? value, String label,
        ValueChanged<DateTime> setter) {
      widgets.add(_Section(
        label: label,
        child: OutlinedButton.icon(
          onPressed: () => _pickDate(current: value, onPicked: setter),
          icon: const Icon(Icons.event_rounded, size: 16),
          label: Text(value == null
              ? 'Pick date'
              : DateFormat('d MMMM, yyyy').format(value)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ));
      widgets.add(const SizedBox(height: 12));
    }

    for (final k in keys) {
      switch (k) {
        case 'position':
          addText(k, _positionCtrl, 'Position', hint: 'e.g. Software Engineer');
          break;
        case 'oldPosition':
          addText(k, _oldPositionCtrl, 'Current position');
          break;
        case 'newPosition':
          addText(k, _newPositionCtrl, 'New position');
          break;
        case 'salary':
          addText(k, _salaryCtrl, 'Salary (PKR)',
              type: TextInputType.number, hint: 'e.g. 50000');
          break;
        case 'newSalary':
          addText(k, _newSalaryCtrl, 'New salary (PKR)',
              type: TextInputType.number);
          break;
        case 'stipend':
          addText(k, _stipendCtrl, 'Stipend (PKR)',
              type: TextInputType.number, hint: 'e.g. 35000');
          break;
        case 'workingDays':
          addText(k, _workingDaysCtrl, 'Working days',
              hint: 'e.g. Monday to Friday');
          break;
        case 'durationMonths':
          addText(k, _durationMonthsCtrl, 'Internship duration (months)',
              type: TextInputType.number);
          break;
        case 'probationMonths':
          addText(k, _probationMonthsCtrl, 'Probation period (months)',
              type: TextInputType.number);
          break;
        case 'reason':
          addText(k, _reasonCtrl, 'Reason / Basis');
          break;
        case 'expectedAction':
          addText(k, _expectedActionCtrl, 'Expected corrective action');
          break;
        case 'performanceNote':
          addText(k, _performanceNoteCtrl, 'Performance note');
          break;
        case 'startDate':
          addDate(k, _startDate, 'Start date', (d) => _startDate = d);
          break;
        case 'endDate':
          addDate(k, _endDate, 'End date', (d) => _endDate = d);
          break;
        case 'effectiveDate':
          addDate(k, _effectiveDate, 'Effective date',
              (d) => _effectiveDate = d);
          break;
        case 'incidentDate':
          addDate(k, _incidentDate, 'Incident date', (d) => _incidentDate = d);
          break;
        case 'lastWorkingDay':
          addDate(k, _lastWorkingDay, 'Last working day',
              (d) => _lastWorkingDay = d);
          break;
      }
    }
    return widgets;
  }
}

// ─── Sent list tab ───────────────────────────────────────────────────────────
class _SentListTab extends StatelessWidget {
  final CompanyLetterService service;
  const _SentListTab({required this.service});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CompanyLetter>>(
      stream: service.streamAll(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final letters = snap.data ?? const [];
        if (letters.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No letters sent yet.',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: letters.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final l = letters[i];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.kind.label,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Text(
                        DateFormat('d MMM yyyy').format(l.letterDate),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'To: ${l.employeeName}  ·  Issued by: ${l.hrName}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => previewLetterPdf(l),
                        icon: const Icon(Icons.visibility_rounded, size: 14),
                        label: const Text('Preview'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => shareLetterPdf(l),
                        icon: const Icon(Icons.share_rounded, size: 14),
                        label: const Text('Share'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  final Widget child;
  const _Section({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
        ),
        child,
      ],
    );
  }
}
