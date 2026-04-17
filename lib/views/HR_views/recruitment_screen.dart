import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/candidate_model.dart';
import '../../models/job_model.dart';
import '../../viewmodels/recruitment_viewmodel.dart';

class RecruitmentScreen extends StatefulWidget {
  const RecruitmentScreen({super.key});

  @override
  State<RecruitmentScreen> createState() => _RecruitmentScreenState();
}

class _RecruitmentScreenState extends State<RecruitmentScreen> {
  @override
  void initState() {
    super.initState();
    context.read<RecruitmentViewModel>().bindJobsStream();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Job Openings',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () => _showAddJobSheet(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Job'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(),
          Expanded(child: _JobList()),
        ],
      ),
    );
  }

  void _showAddJobSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<RecruitmentViewModel>(),
        child: const _AddJobSheet(),
      ),
    );
  }
}

// ─────────────────── FILTER BAR ─────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RecruitmentViewModel>();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: vm.setSearch,
              decoration: InputDecoration(
                hintText: 'Search job...',
                prefixIcon: const Icon(
                  Icons.search,
                  size: 20,
                  color: Color(0xFF94A3B8),
                ),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _DropdownFilter(
            value: 'All',
            items: vm.departments,
            onChanged: vm.setDepartmentFilter,
            hint: 'Department',
          ),
          const SizedBox(width: 10),
          _DropdownFilter(
            value: 'All',
            items: const ['All', 'Open', 'Closed', 'Draft'],
            onChanged: vm.setStatusFilter,
            hint: 'Status',
          ),
        ],
      ),
    );
  }
}

class _DropdownFilter extends StatefulWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  final String hint;

  const _DropdownFilter({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.hint,
  });

  @override
  State<_DropdownFilter> createState() => _DropdownFilterState();
}

class _DropdownFilterState extends State<_DropdownFilter> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selected,
          hint: Text(widget.hint, style: const TextStyle(fontSize: 13)),
          items: widget.items
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(e, style: const TextStyle(fontSize: 13)),
                ),
              )
              .toList(),
          onChanged: (v) {
            setState(() => _selected = v!);
            widget.onChanged(v!);
          },
        ),
      ),
    );
  }
}

// ─────────────────── JOB LIST ───────────────────────────────────────────────
class _JobList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RecruitmentViewModel>();
    final jobs = vm.filteredJobs;
    if (jobs.isEmpty) {
      return const Center(
        child: Text(
          'No job openings match your filters.',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: jobs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _JobCard(job: jobs[i]),
    );
  }
}

// ─────────────────── JOB CARD ───────────────────────────────────────────────
class _JobCard extends StatefulWidget {
  final JobModel job;
  const _JobCard({required this.job});

  @override
  State<_JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<_JobCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final vm = context.read<RecruitmentViewModel>();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: _expanded
                    ? const BorderRadius.vertical(top: Radius.circular(12))
                    : BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          job.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          job.department,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${job.openings} Openings',
                          style: const TextStyle(
                            color: Color(0xFF475569),
                            fontSize: 13,
                          ),
                        ),
                        _StatusChip(status: job.statusLabel),
                      ],
                    ),
                  ),
                  // Copy link button
                  IconButton(
                    tooltip: 'Copy Application Link',
                    icon: const Icon(Icons.link, color: Color(0xFF1E3A5F)),
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: job.applicationLink),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Application link copied!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  // More menu
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'delete') {
                        await vm.deleteJob(job.id);
                      } else if (v == 'close') {
                        await vm.updateJobStatus(job.id, JobStatus.closed);
                      } else if (v == 'open') {
                        await vm.updateJobStatus(job.id, JobStatus.open);
                      }
                    },
                    itemBuilder: (_) => [
                      if (job.status != JobStatus.closed)
                        const PopupMenuItem(
                          value: 'close',
                          child: Text('Mark Closed'),
                        ),
                      if (job.status != JobStatus.open)
                        const PopupMenuItem(
                          value: 'open',
                          child: Text('Mark Open'),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),
          // ── Candidate Table ──────────────────────────────────
          if (_expanded) _CandidateSection(job: job),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    switch (status) {
      case 'Open':
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF065F46);
        break;
      case 'Closed':
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFF991B1B);
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ─────────────────── CANDIDATE SECTION ──────────────────────────────────────
class _CandidateSection extends StatelessWidget {
  final JobModel job;
  const _CandidateSection({required this.job});

  @override
  Widget build(BuildContext context) {
    final vm = context.read<RecruitmentViewModel>();
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: StreamBuilder<List<CandidateModel>>(
        stream: vm.candidatesStream(job.id),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final candidates = snap.data ?? [];
          if (candidates.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No applications yet.',
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              ),
            );
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              columns: const [
                DataColumn(
                  label: Text(
                    'Candidate',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Email',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Applied',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Experience',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Resume',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Status',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Action',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ),
              ],
              rows: candidates
                  .map((c) => _candidateRow(context, c, vm))
                  .toList(),
            ),
          );
        },
      ),
    );
  }

  DataRow _candidateRow(
    BuildContext context,
    CandidateModel c,
    RecruitmentViewModel vm,
  ) {
    return DataRow(
      cells: [
        DataCell(
          Text(
            c.name,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
        ),
        DataCell(
          Text(
            c.email,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
        ),
        DataCell(
          Text(
            '${c.appliedDate.day}/${c.appliedDate.month}/${c.appliedDate.year}',
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
        ),
        DataCell(
          Text(
            c.experience,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
        ),
        DataCell(
          c.resumeUrl.isNotEmpty
              ? TextButton(
                  onPressed: () {
                    // Open resume URL
                  },
                  child: const Text(
                    'View Resume',
                    style: TextStyle(fontSize: 12),
                  ),
                )
              : const Text('—'),
        ),
        DataCell(_CandidateStatusBadge(status: c.statusLabel)),
        DataCell(
          DropdownButtonHideUnderline(
            child: DropdownButton<CandidateStatus>(
              value: c.status,
              isDense: true,
              style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
              items: CandidateStatus.values
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.name.capitalize()),
                    ),
                  )
                  .toList(),
              onChanged: (s) {
                if (s != null) vm.updateCandidateStatus(c.id, s);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _CandidateStatusBadge extends StatelessWidget {
  final String status;
  const _CandidateStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    switch (status) {
      case 'Shortlisted':
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF065F46);
        break;
      case 'Hired':
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF1D4ED8);
        break;
      case 'Rejected':
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFF991B1B);
        break;
      default:
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFF92400E);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ─────────────────── ADD JOB BOTTOM SHEET ───────────────────────────────────
class _AddJobSheet extends StatefulWidget {
  const _AddJobSheet();

  @override
  State<_AddJobSheet> createState() => _AddJobSheetState();
}

class _AddJobSheetState extends State<_AddJobSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _reqCtrl = TextEditingController();
  final _openingsCtrl = TextEditingController(text: '1');
  String _department = 'IT';
  String? _generatedLink;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RecruitmentViewModel>();
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Add New Job',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),

              // Title
              _label('Job Title *'),
              _textField(_titleCtrl, 'e.g. Software Engineer', required: true),
              const SizedBox(height: 14),

              // Department
              _label('Department *'),
              DropdownButtonFormField<String>(
                initialValue: _department,
                decoration: _inputDecoration('Department'),
                items: ['IT', 'HR', 'Sales', 'Finance', 'Marketing']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _department = v!),
              ),
              const SizedBox(height: 14),

              // Openings
              _label('Number of Openings *'),
              _textField(
                _openingsCtrl,
                '1',
                keyboardType: TextInputType.number,
                required: true,
              ),
              const SizedBox(height: 14),

              // Description
              _label('Job Description *'),
              _textField(
                _descCtrl,
                'Describe the role, responsibilities...',
                maxLines: 4,
                required: true,
              ),
              const SizedBox(height: 14),

              // Requirements
              _label('Requirements'),
              _textField(
                _reqCtrl,
                'Skills, qualifications, experience...',
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Generated link
              if (_generatedLink != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.link,
                        color: Color(0xFF1D4ED8),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _generatedLink!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.copy,
                          size: 16,
                          color: Color(0xFF1D4ED8),
                        ),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: _generatedLink!),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Link copied!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ),
              ] else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: vm.isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A5F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: vm.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Create Job & Generate Link'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final vm = context.read<RecruitmentViewModel>();
    final link = await vm.addJob(
      title: _titleCtrl.text.trim(),
      department: _department,
      description: _descCtrl.text.trim(),
      requirements: _reqCtrl.text.trim(),
      openings: int.tryParse(_openingsCtrl.text) ?? 1,
    );
    if (link != null) setState(() => _generatedLink = link);
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Color(0xFF374151),
      ),
    ),
  );

  Widget _textField(
    TextEditingController ctrl,
    String hint, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    bool required = false,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: _inputDecoration(hint),
      validator: required
          ? (v) => (v == null || v.isEmpty) ? 'Required' : null
          : null,
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
    filled: true,
    fillColor: const Color(0xFFF9FAFB),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFF1E3A5F)),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );
}

extension StringExtension on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
