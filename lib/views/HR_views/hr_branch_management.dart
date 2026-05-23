// lib/views/hr_settings/hr_branch_management.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/branch_model.dart';
import '../../models/employee_model.dart';
import '../../models/office_settings_model.dart';
import '../../services/office_settings_service.dart';
import '../../viewmodels/branch_viewmodel.dart';
import '../../viewmodels/employee_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Top-level entry widget
// ══════════════════════════════════════════════════════════════════════════════

class HRBranchManagement extends StatefulWidget {
  const HRBranchManagement({super.key});

  @override
  State<HRBranchManagement> createState() => _HRBranchManagementState();
}

class _HRBranchManagementState extends State<HRBranchManagement>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BranchViewModel>().init();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Consumer<BranchViewModel>(
    builder: (context, vm, _) => Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.location_city,
                    color: Color(0xFF2563EB),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Branch Management',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Manage branches, assignments and office timings',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Tabs ────────────────────────────────────────────────────
          TabBar(
            controller: _tabs,
            labelColor: const Color(0xFF2563EB),
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: const Color(0xFF2563EB),
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(icon: Icon(Icons.business, size: 16), text: 'Branches'),
              Tab(
                icon: Icon(Icons.people_alt_outlined, size: 16),
                text: 'Assignments',
              ),
              Tab(
                icon: Icon(Icons.schedule_rounded, size: 16),
                text: 'Timings',
              ),
            ],
          ),

          SizedBox(
            height: 600, // slightly taller to fit half-day sliders
            child: TabBarView(
              controller: _tabs,
              children: [
                _BranchesTab(vm: vm),
                _AssignmentsTab(vm: vm),
                const _OfficeSettingsTab(),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — Branches — UNCHANGED
// ══════════════════════════════════════════════════════════════════════════════

class _BranchesTab extends StatefulWidget {
  final BranchViewModel vm;
  const _BranchesTab({required this.vm});
  @override
  State<_BranchesTab> createState() => _BranchesTabState();
}

class _BranchesTabState extends State<_BranchesTab> {
  bool _showForm = false;
  BranchModel? _editing;

  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _altCtrl = TextEditingController();
  final _radiusCtrl = TextEditingController(text: '40');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _altCtrl.dispose();
    _radiusCtrl.dispose();
    super.dispose();
  }

  void _startEdit(BranchModel b) {
    _editing = b;
    _nameCtrl.text = b.name;
    _addressCtrl.text = b.address;
    _latCtrl.text = b.latitude.toString();
    _lngCtrl.text = b.longitude.toString();
    _altCtrl.text = b.altitude.toString();
    _radiusCtrl.text = b.radius.toString();
    setState(() => _showForm = true);
  }

  void _clearForm() {
    _editing = null;
    _nameCtrl.clear();
    _addressCtrl.clear();
    _latCtrl.clear();
    _lngCtrl.clear();
    _altCtrl.clear();
    _radiusCtrl.text = '40';
    setState(() => _showForm = false);
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.isEmpty ||
        _latCtrl.text.isEmpty ||
        _lngCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name, Latitude and Longitude are required'),
        ),
      );
      return;
    }
    final branch = BranchModel(
      id: _editing?.id ?? '',
      name: _nameCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      latitude: double.tryParse(_latCtrl.text) ?? 0,
      longitude: double.tryParse(_lngCtrl.text) ?? 0,
      altitude: double.tryParse(_altCtrl.text) ?? 0,
      radius: double.tryParse(_radiusCtrl.text) ?? 40,
      createdAt: _editing?.createdAt ?? DateTime.now(),
    );
    try {
      if (_editing == null) {
        await widget.vm.addBranch(branch);
      } else {
        await widget.vm.updateBranch(branch);
      }
      _clearForm();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _editing == null ? 'Branch added!' : 'Branch updated!',
            ),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${widget.vm.branches.length} '
              'Branch${widget.vm.branches.length == 1 ? '' : 'es'}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF475569),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => setState(() {
                _clearForm();
                _showForm = true;
              }),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Branch'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        if (_showForm) ...[const SizedBox(height: 14), _buildForm()],
        const SizedBox(height: 12),
        ...widget.vm.branches.map(
          (b) => _BranchCard(
            branch: b,
            onEdit: () => _startEdit(b),
            onDelete: () async {
              final ok = await _confirmDelete(context, b.name);
              if (ok) widget.vm.deleteBranch(b.id);
            },
          ),
        ),
        if (widget.vm.branches.isEmpty)
          _emptyState('No branches yet', 'Add your first branch above'),
      ],
    ),
  );

  Widget _buildForm() => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFBFDBFE)),
    ),
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _editing == null ? 'New Branch' : 'Edit Branch',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Color(0xFF1E40AF),
          ),
        ),
        const SizedBox(height: 12),
        _field('Branch Name *', _nameCtrl, hint: 'e.g. Main Office'),
        const SizedBox(height: 8),
        _field('Address', _addressCtrl, hint: 'Full address'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _field(
                'Latitude *',
                _latCtrl,
                hint: 'e.g. 33.5992',
                isNumber: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _field(
                'Longitude *',
                _lngCtrl,
                hint: 'e.g. 73.1546',
                isNumber: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _field(
                'Altitude (m)',
                _altCtrl,
                hint: 'e.g. 508',
                isNumber: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _field(
                'Radius (m) *',
                _radiusCtrl,
                hint: 'e.g. 40',
                isNumber: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Radius = how many metres from centre an employee '
          'can be to check in.',
          style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: _clearForm, child: const Text('Cancel')),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(_editing == null ? 'Save Branch' : 'Update Branch'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _field(
    String label,
    TextEditingController ctrl, {
    String? hint,
    bool isNumber = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF475569),
        ),
      ),
      const SizedBox(height: 4),
      TextFormField(
        controller: ctrl,
        keyboardType: isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF2563EB)),
          ),
        ),
      ),
    ],
  );

  Future<bool> _confirmDelete(BuildContext ctx, String name) async {
    return await showDialog<bool>(
          context: ctx,
          builder: (_) => AlertDialog(
            title: const Text('Delete Branch?'),
            content: Text('Are you sure you want to delete "$name"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _BranchCard extends StatelessWidget {
  final BranchModel branch;
  final VoidCallback onEdit, onDelete;
  const _BranchCard({
    required this.branch,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4),
      ],
    ),
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFDBEAFE),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.business, color: Color(0xFF2563EB), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                branch.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (branch.address.isNotEmpty)
                Text(
                  branch.address,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 12,
                children: [
                  _chip(
                    Icons.my_location,
                    '${branch.latitude.toStringAsFixed(5)}, '
                    '${branch.longitude.toStringAsFixed(5)}',
                  ),
                  _chip(
                    Icons.radio_button_checked,
                    'Radius: ${branch.radius.toStringAsFixed(0)}m',
                  ),
                  if (branch.altitude > 0)
                    _chip(
                      Icons.terrain,
                      'Alt: ${branch.altitude.toStringAsFixed(0)}m',
                    ),
                ],
              ),
            ],
          ),
        ),
        Column(
          children: [
            GestureDetector(
              onTap: onEdit,
              child: const Icon(
                Icons.edit_outlined,
                size: 18,
                color: Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onDelete,
              child: const Icon(
                Icons.delete_outline,
                size: 18,
                color: Color(0xFFDC2626),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _chip(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 11, color: const Color(0xFF94A3B8)),
      const SizedBox(width: 3),
      Text(
        text,
        style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
      ),
    ],
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — Employee Assignments — UNCHANGED
// ══════════════════════════════════════════════════════════════════════════════

class _AssignmentsTab extends StatefulWidget {
  final BranchViewModel vm;
  const _AssignmentsTab({required this.vm});
  @override
  State<_AssignmentsTab> createState() => _AssignmentsTabState();
}

class _AssignmentsTabState extends State<_AssignmentsTab> {
  String? _selectedEmpId;
  bool _showForm = false;

  String _targetBranchId = '';
  AssignmentDuration _duration = AssignmentDuration.permanent;
  DateTime? _startDate;
  DateTime? _endDate;
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emps = context.watch<EmployeeViewModel>().employees;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select an employee to manage their branch assignment.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          ...emps.map(
            (emp) => _EmpAssignRow(
              emp: emp,
              vm: widget.vm,
              isSelected: _selectedEmpId == emp.uid,
              onTap: () => setState(() {
                _selectedEmpId = _selectedEmpId == emp.uid ? null : emp.uid;
                _showForm = false;
                _reasonCtrl.clear();
              }),
              onAssign: () => setState(() {
                _selectedEmpId = emp.uid;
                _showForm = true;
                _targetBranchId = '';
                _duration = AssignmentDuration.permanent;
                _startDate = DateTime.now();
                _endDate = null;
                _reasonCtrl.clear();
              }),
              onRevert: () => _revert(emp),
              onFieldDuty: (v) => widget.vm.setFieldDuty(emp.uid, v),
              onSetDefault: (bId, bName) =>
                  widget.vm.setDefaultBranch(emp.uid, bId, bName),
            ),
          ),
          if (emps.isEmpty)
            _emptyState(
              'No employees found',
              'Employees will appear here once added',
            ),
          if (_showForm && _selectedEmpId != null) ...[
            const SizedBox(height: 16),
            _assignmentForm(emps.firstWhere((e) => e.uid == _selectedEmpId)),
          ],
        ],
      ),
    );
  }

  Widget _assignmentForm(Employee emp) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFF0FDF4),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF86EFAC)),
    ),
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.swap_horiz, color: Color(0xFF059669), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Assign ${emp.name} to Branch',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF14532D),
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _showForm = false),
              child: const Icon(
                Icons.close,
                size: 18,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _label('Target Branch *'),
        DropdownButtonFormField<String>(
          initialValue: _targetBranchId.isEmpty ? null : _targetBranchId,
          hint: const Text('Select branch', style: TextStyle(fontSize: 13)),
          items: widget.vm.branches
              .map((b) => DropdownMenuItem(value: b.id, child: Text(b.name)))
              .toList(),
          onChanged: (v) => setState(() => _targetBranchId = v ?? ''),
          decoration: _inputDeco(),
        ),
        const SizedBox(height: 10),
        _label('Duration'),
        DropdownButtonFormField<AssignmentDuration>(
          initialValue: _duration,
          items: AssignmentDuration.values
              .map((d) => DropdownMenuItem(value: d, child: Text(d.label)))
              .toList(),
          onChanged: (v) => setState(() {
            _duration = v ?? AssignmentDuration.permanent;
            _endDate = null;
          }),
          decoration: _inputDeco(),
        ),
        if (_duration == AssignmentDuration.temporary) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Start Date'),
                    _datePicker(
                      _startDate,
                      'Start',
                      (d) => setState(() => _startDate = d),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('End Date'),
                    _datePicker(
                      _endDate,
                      'End',
                      (d) => setState(() => _endDate = d),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        _label('Reason (optional)'),
        TextFormField(
          controller: _reasonCtrl,
          maxLines: 2,
          style: const TextStyle(fontSize: 13),
          decoration: _inputDeco(hint: 'e.g. Project support at Branch 2'),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _submitAssignment,
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Confirm Assignment'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Future<void> _submitAssignment() async {
    if (_targetBranchId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a target branch')),
      );
      return;
    }
    if (_duration == AssignmentDuration.temporary && _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an end date for temporary assignment'),
        ),
      );
      return;
    }

    final emps = context.read<EmployeeViewModel>().employees;
    final emp = emps.firstWhere((e) => e.uid == _selectedEmpId);
    final hrUid = context.read<AuthViewModel>().currentUser?.uid ?? '';
    final branch = widget.vm.branchById(_targetBranchId)!;

    DateTime? endDate;
    if (_duration == AssignmentDuration.todayOnly) {
      final now = DateTime.now();
      endDate = DateTime(now.year, now.month, now.day, 23, 59);
    } else if (_duration == AssignmentDuration.temporary) {
      endDate = _endDate;
    }

    final assignment = BranchAssignment(
      id: '',
      employeeId: emp.uid,
      employeeName: emp.name,
      fromBranchId: emp.defaultBranchId ?? '',
      fromBranchName: emp.defaultBranchName ?? 'Default',
      toBranchId: _targetBranchId,
      toBranchName: branch.name,
      assignedBy: hrUid,
      duration: _duration,
      startDate: _startDate ?? DateTime.now(),
      endDate: endDate,
      reason: _reasonCtrl.text.trim(),
    );

    try {
      await widget.vm.assignBranch(assignment);
      setState(() => _showForm = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${emp.name} assigned to ${branch.name}'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _revert(Employee emp) async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Revert to Default Branch?'),
            content: Text(
              'This will remove the temporary assignment for '
              '${emp.name} and revert them to their default branch.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Revert'),
              ),
            ],
          ),
        ) ??
        false;
    if (ok) {
      await widget.vm.revertToDefault(emp.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${emp.name} reverted to default branch'),
            backgroundColor: const Color(0xFF2563EB),
          ),
        );
      }
    }
  }

  Widget _datePicker(
    DateTime? value,
    String hint,
    ValueChanged<DateTime> onPicked,
  ) => GestureDetector(
    onTap: () async {
      final d = await showDatePicker(
        context: context,
        initialDate: value ?? DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime(2030),
      );
      if (d != null) onPicked(d);
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 13,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(width: 6),
          Text(
            value != null ? DateFormat('dd MMM yy').format(value) : hint,
            style: TextStyle(
              fontSize: 13,
              color: value != null
                  ? const Color(0xFF0F172A)
                  : const Color(0xFFCBD5E1),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      t,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Color(0xFF475569),
      ),
    ),
  );

  InputDecoration _inputDeco({String? hint}) => InputDecoration(
    hintText: hint,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFF2563EB)),
    ),
  );
}

// ── Employee assignment row — UNCHANGED ───────────────────────────────────────

class _EmpAssignRow extends StatelessWidget {
  final Employee emp;
  final BranchViewModel vm;
  final bool isSelected;
  final VoidCallback onTap, onAssign, onRevert;
  final ValueChanged<bool> onFieldDuty;
  final void Function(String branchId, String branchName) onSetDefault;

  const _EmpAssignRow({
    required this.emp,
    required this.vm,
    required this.isSelected,
    required this.onTap,
    required this.onAssign,
    required this.onRevert,
    required this.onFieldDuty,
    required this.onSetDefault,
  });

  @override
  Widget build(BuildContext context) {
    final initials = emp.name
        .trim()
        .split(' ')
        .map((p) => p.isEmpty ? '' : p[0])
        .take(2)
        .join()
        .toUpperCase();
    final hasTempAssignment = emp.hasTemporaryAssignment;
    final branchName = emp.effectiveBranchName;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFFA855F7)],
                      ),
                      borderRadius: BorderRadius.circular(19),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          emp.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(
                              emp.fieldDuty
                                  ? Icons.directions_car_outlined
                                  : Icons.location_on_outlined,
                              size: 12,
                              color: emp.fieldDuty
                                  ? const Color(0xFFF97316)
                                  : hasTempAssignment
                                  ? const Color(0xFF7C3AED)
                                  : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              branchName,
                              style: TextStyle(
                                fontSize: 11,
                                color: emp.fieldDuty
                                    ? const Color(0xFFF97316)
                                    : hasTempAssignment
                                    ? const Color(0xFF7C3AED)
                                    : const Color(0xFF64748B),
                                fontWeight: hasTempAssignment || emp.fieldDuty
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                            if (hasTempAssignment) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3E8FF),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'TEMP',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: Color(0xFF7C3AED),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                            if (emp.fieldDuty) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7ED),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'FIELD',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: Color(0xFFF97316),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: onAssign,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text('Assign', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          ),
          if (isSelected) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFED7AA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.directions_car_outlined,
                          color: Color(0xFFF97316),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Field Duty Mode',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: Color(0xFF7C2D12),
                                ),
                              ),
                              Text(
                                'Employee can check in from any location',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFFC2410C),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: emp.fieldDuty,
                          onChanged: onFieldDuty,
                          activeThumbColor: const Color(0xFFF97316),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (vm.branches.isNotEmpty) ...[
                    Row(
                      children: [
                        const Text(
                          'Set Default Branch:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButton<String>(
                            value:
                                vm.branches.any(
                                  (b) => b.id == emp.defaultBranchId,
                                )
                                ? emp.defaultBranchId
                                : null,
                            hint: const Text(
                              'Pick default',
                              style: TextStyle(fontSize: 12),
                            ),
                            isExpanded: true,
                            items: vm.branches
                                .map(
                                  (b) => DropdownMenuItem(
                                    value: b.id,
                                    child: Text(
                                      b.name,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              final b = vm.branchById(v);
                              if (b != null) {
                                onSetDefault(b.id, b.name);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (hasTempAssignment)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onRevert,
                        icon: const Icon(Icons.undo, size: 14),
                        label: const Text(
                          'Revert to Default Branch',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          side: const BorderSide(color: Color(0xFF93C5FD)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — Office Settings (timings) ← UPDATED with half-day fields
// ══════════════════════════════════════════════════════════════════════════════

class _OfficeSettingsTab extends StatefulWidget {
  const _OfficeSettingsTab();

  @override
  State<_OfficeSettingsTab> createState() => _OfficeSettingsTabState();
}

class _OfficeSettingsTabState extends State<_OfficeSettingsTab> {
  final _settingsService = OfficeSettingsService();

  OfficeSettings? _current;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _successMsg;

  // Slider values
  late int _workStartHour;
  late int _cutoffHour;
  late int _halfDayMark; // ← NEW: midday split (default 13 = 1 PM)
  late int
  _halfDayCutoff; // ← NEW: first-half check-in deadline (default 14 = 2 PM)
  late int _workEndHour;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await _settingsService.fetchSettings();
      setState(() {
        _current = s;
        _workStartHour = s.workStartHour;
        _cutoffHour = s.checkInCutoff;
        _halfDayMark = s.halfDayMark;
        _halfDayCutoff = s.halfDayCutoff;
        _workEndHour = s.workEndHour;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load settings: $e';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final hrUid = context.read<AuthViewModel>().currentUser?.uid;
    if (hrUid == null) return;

    // ── Validation ────────────────────────────────────────────────
    if (_cutoffHour <= _workStartHour) {
      setState(() => _error = 'Check-in cutoff must be after work start time.');
      return;
    }
    if (_halfDayMark <= _workStartHour) {
      setState(() => _error = 'Half-day mark must be after work start time.');
      return;
    }
    if (_halfDayMark >= _workEndHour) {
      setState(() => _error = 'Half-day mark must be before work end time.');
      return;
    }
    if (_halfDayCutoff <= _halfDayMark) {
      setState(
        () => _error =
            'Half-day check-in cutoff must be after the half-day mark.',
      );
      return;
    }
    if (_halfDayCutoff >= _workEndHour) {
      setState(
        () => _error = 'Half-day check-in cutoff must be before work end time.',
      );
      return;
    }
    if (_workEndHour <= _cutoffHour) {
      setState(() => _error = 'Work end time must be after check-in cutoff.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _successMsg = null;
    });

    try {
      await _settingsService.updateSettings(
        settings: OfficeSettings(
          workStartHour: _workStartHour,
          checkInCutoff: _cutoffHour,
          halfDayMark: _halfDayMark,
          halfDayCutoff: _halfDayCutoff,
          workEndHour: _workEndHour,
          timezone: _current?.timezone ?? 'Asia/Karachi',
        ),
        hrUid: hrUid,
      );
      final updated = await _settingsService.fetchSettings();
      setState(() {
        _current = updated;
        _successMsg = 'Office timings updated successfully.';
        _saving = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to save: $e';
        _saving = false;
      });
    }
  }

  static String _fmtHour(int h) {
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$hour:00 $period';
  }

  static String _fmtDateTime(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final p = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at $h:$m $p';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Info banner ──────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: const [
                Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF2563EB),
                  size: 16,
                ),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Changes take effect immediately. '
                    'The Cloud Function uses these values on its '
                    'next scheduled run.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Error / success ──────────────────────────────────────
          if (_error != null) ...[
            _SettingsBanner(
              message: _error!,
              isError: true,
              onDismiss: () => setState(() => _error = null),
            ),
            const SizedBox(height: 10),
          ],
          if (_successMsg != null) ...[
            _SettingsBanner(
              message: _successMsg!,
              isError: false,
              onDismiss: () => setState(() => _successMsg = null),
            ),
            const SizedBox(height: 10),
          ],

          // ── Section: Full Day Timings ────────────────────────────
          _SectionHeader(
            icon: Icons.access_time_rounded,
            color: const Color(0xFF2563EB),
            label: 'Full Day Timings',
          ),
          const SizedBox(height: 10),

          _TimingSlider(
            icon: Icons.login_rounded,
            iconColor: const Color(0xFF2563EB),
            iconBg: const Color(0xFFDBEAFE),
            title: 'Work Start Time',
            subtitle: 'Official start of the workday',
            selectedHour: _workStartHour,
            onChanged: (h) => setState(() => _workStartHour = h),
          ),
          const SizedBox(height: 10),

          _TimingSlider(
            icon: Icons.schedule_rounded,
            iconColor: const Color(0xFFDC2626),
            iconBg: const Color(0xFFFEE2E2),
            title: 'Check-in Cutoff',
            subtitle: 'Absent if not checked in by this hour',
            selectedHour: _cutoffHour,
            onChanged: (h) => setState(() => _cutoffHour = h),
            highlight: true,
          ),
          const SizedBox(height: 10),

          _TimingSlider(
            icon: Icons.logout_rounded,
            iconColor: const Color(0xFF059669),
            iconBg: const Color(0xFFD1FAE5),
            title: 'Work End Time',
            subtitle: 'End of the official workday',
            selectedHour: _workEndHour,
            onChanged: (h) => setState(() => _workEndHour = h),
          ),
          const SizedBox(height: 16),

          // ── Section: Half Day Timings ────────────────────────────
          _SectionHeader(
            icon: Icons.more_time_rounded,
            color: const Color(0xFF7C3AED),
            label: 'Half Day Timings',
          ),
          const SizedBox(height: 6),

          // Half day explanation card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              children: [
                _HalfDayExplainRow(
                  icon: Icons.wb_sunny_outlined,
                  color: const Color(0xFF7C3AED),
                  title: 'First Half Leave (Morning off)',
                  desc:
                      'Employee checks in after the Half-Day Mark. '
                      'If still absent by the Half-Day Cutoff, '
                      'marked absent for the full day.',
                ),
                const SizedBox(height: 8),
                _HalfDayExplainRow(
                  icon: Icons.nights_stay_outlined,
                  color: const Color(0xFF0891B2),
                  title: 'Second Half Leave (Afternoon off)',
                  desc:
                      'Employee checks in normally in the morning '
                      'and can check out at the Half-Day Mark.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          _TimingSlider(
            icon: Icons.splitscreen_rounded,
            iconColor: const Color(0xFF7C3AED),
            iconBg: const Color(0xFFF3E8FF),
            title: 'Half-Day Mark',
            subtitle: 'Midday split — 1 PM recommended',
            selectedHour: _halfDayMark,
            onChanged: (h) => setState(() => _halfDayMark = h),
          ),
          const SizedBox(height: 10),

          _TimingSlider(
            icon: Icons.timer_outlined,
            iconColor: const Color(0xFF0891B2),
            iconBg: const Color(0xFFCFFAFE),
            title: 'Half-Day Check-in Cutoff',
            subtitle: 'First-half leave employees must arrive by this hour',
            selectedHour: _halfDayCutoff,
            onChanged: (h) => setState(() => _halfDayCutoff = h),
            highlight: true,
          ),
          const SizedBox(height: 16),

          // ── Current saved summary ────────────────────────────────
          if (_current != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Saved Settings',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _summaryRow('Work Start', _fmtHour(_current!.workStartHour)),
                  const SizedBox(height: 5),
                  _summaryRow(
                    'Check-in Cutoff',
                    _fmtHour(_current!.checkInCutoff),
                    bold: true,
                    color: const Color(0xFFDC2626),
                  ),
                  const SizedBox(height: 5),
                  _summaryRow('Work End', _fmtHour(_current!.workEndHour)),
                  const Divider(height: 16),
                  _summaryRow(
                    'Half-Day Mark',
                    _fmtHour(_current!.halfDayMark),
                    color: const Color(0xFF7C3AED),
                  ),
                  const SizedBox(height: 5),
                  _summaryRow(
                    'Half-Day Cutoff',
                    _fmtHour(_current!.halfDayCutoff),
                    bold: true,
                    color: const Color(0xFF0891B2),
                  ),
                  const SizedBox(height: 5),
                  _summaryRow('Timezone', _current!.timezone),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Save button ──────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                ),
                borderRadius: BorderRadius.circular(13),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TextButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.save_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                label: Text(
                  _saving ? 'Saving...' : 'Save Changes',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),

          if (_current?.updatedAt != null) ...[
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Last updated: ${_fmtDateTime(_current!.updatedAt!)}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
            ),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool bold = false,
    Color color = const Color(0xFF0F172A),
  }) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: 11,
          fontWeight: bold ? FontWeight.bold : FontWeight.w500,
          color: color,
        ),
      ),
    ],
  );
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _SectionHeader({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 15, color: color),
      const SizedBox(width: 6),
      Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(child: Divider(color: color.withValues(alpha: 0.2))),
    ],
  );
}

// ── Half day explain row ──────────────────────────────────────────────────────

class _HalfDayExplainRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String desc;
  const _HalfDayExplainRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              desc,
              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    ],
  );
}

// ── Timing slider card ────────────────────────────────────────────────────────

class _TimingSlider extends StatelessWidget {
  final IconData icon;
  final Color iconColor, iconBg;
  final String title, subtitle;
  final int selectedHour;
  final ValueChanged<int> onChanged;
  final bool highlight;

  const _TimingSlider({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.selectedHour,
    required this.onChanged,
    this.highlight = false,
  });

  String _fmt(int h) {
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$hour:00 $period';
  }

  @override
  Widget build(BuildContext context) => Card(
    elevation: highlight ? 2 : 1,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: highlight
          ? BorderSide(color: iconColor.withValues(alpha: 0.4), width: 1.5)
          : BorderSide.none,
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _fmt(selectedHour),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: iconColor,
              thumbColor: iconColor,
              inactiveTrackColor: iconBg,
              overlayColor: iconColor.withValues(alpha: 0.15),
              trackHeight: 3,
            ),
            child: Slider(
              value: selectedHour.toDouble(),
              min: 0,
              max: 23,
              divisions: 23,
              label: _fmt(selectedHour),
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ['12AM', '6AM', '12PM', '6PM', '11PM']
                  .map(
                    (l) => Text(
                      l,
                      style: const TextStyle(
                        fontSize: 8,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Settings banner ───────────────────────────────────────────────────────────

class _SettingsBanner extends StatelessWidget {
  final String message;
  final bool isError;
  final VoidCallback onDismiss;

  const _SettingsBanner({
    required this.message,
    required this.isError,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isError ? Colors.red.shade50 : Colors.green.shade50;
    final border = isError ? Colors.red.shade200 : Colors.green.shade200;
    final fg = isError ? Colors.red.shade700 : Colors.green.shade700;
    final icon = isError
        ? Icons.error_outline_rounded
        : Icons.check_circle_outline_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: fg, fontSize: 12)),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(Icons.close_rounded, color: fg, size: 16),
          ),
        ],
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

Widget _emptyState(String title, String sub) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 32),
  child: Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(28),
          ),
          child: const Icon(
            Icons.business_outlined,
            size: 28,
            color: Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          sub,
          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        ),
      ],
    ),
  ),
);
