import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/recruitment_viewmodel.dart';

/// Public apply screen shown to candidates via deep link:
///   https://hrms-1bc9a.web.app/apply/{jobId}
class ApplyScreen extends StatefulWidget {
  final String jobId;
  const ApplyScreen({super.key, required this.jobId});

  @override
  State<ApplyScreen> createState() => _ApplyScreenState();
}

class _ApplyScreenState extends State<ApplyScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ApplyViewModel>().loadJob(widget.jobId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Consumer<ApplyViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoadingJob) {
            return const Center(child: CircularProgressIndicator());
          }
          if (vm.error != null && vm.job == null) {
            return Center(
              child: Text(vm.error!,
                  style: const TextStyle(color: Colors.red)),
            );
          }
          if (vm.submitted) {
            return _SuccessView(jobTitle: vm.job!.title);
          }
          return _ApplyForm(vm: vm);
        },
      ),
    );
  }
}

// ─────────────────── SUCCESS VIEW ───────────────────────────────────────────
class _SuccessView extends StatelessWidget {
  final String jobTitle;
  const _SuccessView({required this.jobTitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                  color: Color(0xFFECFDF5), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_outline,
                  color: Color(0xFF059669), size: 48),
            ),
            const SizedBox(height: 24),
            const Text('Application Submitted!',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text(
              'Thank you for applying for $jobTitle.\nWe\'ll review your application and get back to you.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF64748B), fontSize: 15, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────── APPLY FORM ─────────────────────────────────────────────
class _ApplyForm extends StatefulWidget {
  final ApplyViewModel vm;
  const _ApplyForm({required this.vm});

  @override
  State<_ApplyForm> createState() => _ApplyFormState();
}

class _ApplyFormState extends State<_ApplyForm> {
  final _formKey  = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _expCtrl   = TextEditingController();
  final _coverCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _expCtrl.dispose();
    _coverCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm  = widget.vm;
    final job = vm.job!;

    return CustomScrollView(
      slivers: [
        // ── Hero Header ──────────────────────────────────────
        SliverAppBar(
          expandedHeight: 180,
          pinned: true,
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFF1E3A5F),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E3A5F), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 70, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(job.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Row(children: [
                    _pill(Icons.business_outlined, job.department),
                    const SizedBox(width: 12),
                    _pill(Icons.people_outline, '${job.openings} Openings'),
                  ]),
                ],
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Job Info ──────────────────────────────────
                _sectionCard(
                  title: 'About the Role',
                  child: Text(job.description,
                      style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF475569),
                          height: 1.6)),
                ),
                if (job.requirements.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _sectionCard(
                    title: 'Requirements',
                    child: Text(job.requirements,
                        style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF475569),
                            height: 1.6)),
                  ),
                ],
                const SizedBox(height: 24),
                const Text('Your Application',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B))),
                const SizedBox(height: 16),

                // ── Form ──────────────────────────────────────
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _row([
                        _field(_nameCtrl, 'Full Name',
                            Icons.person_outline, required: true),
                        _field(_emailCtrl, 'Email Address',
                            Icons.email_outlined,
                            required: true,
                            keyboard: TextInputType.emailAddress),
                      ]),
                      const SizedBox(height: 14),
                      _row([
                        _field(_phoneCtrl, 'Phone Number',
                            Icons.phone_outlined,
                            keyboard: TextInputType.phone),
                        _field(_expCtrl, 'Years of Experience',
                            Icons.work_outline, required: true),
                      ]),
                      const SizedBox(height: 14),
                      _field(_coverCtrl,
                          'Cover Letter (optional)',
                          Icons.description_outlined,
                          maxLines: 5),
                      const SizedBox(height: 14),

                      // ── Resume Upload ──────────────────────
                      _ResumeUploadTile(vm: vm),
                      const SizedBox(height: 24),

                      if (vm.error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(vm.error!,
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 13)),
                        ),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: vm.isSubmitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A5F),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: vm.isSubmitting
                              ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                              : const Text('Submit Application',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!widget.vm.hasResume) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please upload your resume.'),
            backgroundColor: Colors.red),
      );
      return;
    }
    await widget.vm.submitApplication(
      name:        _nameCtrl.text.trim(),
      email:       _emailCtrl.text.trim(),
      phone:       _phoneCtrl.text.trim(),
      experience:  _expCtrl.text.trim(),
      coverLetter: _coverCtrl.text.trim(),
    );
  }

  Widget _row(List<Widget> children) => Row(
    children: children
        .map((w) => Expanded(child: w))
        .toList()
        .fold<List<Widget>>(
      [],
          (acc, w) =>
      acc.isEmpty ? [w] : [...acc, const SizedBox(width: 12), w],
    ),
  );

  Widget _field(
      TextEditingController ctrl,
      String label,
      IconData icon, {
        int maxLines = 1,
        TextInputType keyboard = TextInputType.text,
        bool required = false,
      }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboard,
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon:
        Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
            const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
            const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
            const BorderSide(color: Color(0xFF1E3A5F))),
      ),
    );
  }

  Widget _sectionCard(
      {required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Color(0xFF1E293B))),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: Colors.white70),
      const SizedBox(width: 4),
      Text(text,
          style: const TextStyle(
              color: Colors.white70, fontSize: 13)),
    ],
  );
}

// ─────────────────── RESUME UPLOAD TILE ─────────────────────────────────────
class _ResumeUploadTile extends StatelessWidget {
  final ApplyViewModel vm;
  const _ResumeUploadTile({required this.vm});

  Future<void> _pickFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
      // withData: true is required on Web to get bytes
      withData: kIsWeb,
    );

    if (result == null) return;
    final file = result.files.single;

    if (kIsWeb) {
      // ── Web: use bytes ──────────────────────────────────────
      if (file.bytes != null) {
        vm.setResumeBytes(file.bytes!, file.name);
      }
    } else {
      // ── Mobile/Desktop: use file path ───────────────────────
      if (file.path != null) {
        vm.setResumeFile(file.path!, file.name);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFile = vm.hasResume;
    return GestureDetector(
      onTap: () => _pickFile(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hasFile
              ? const Color(0xFFEFF6FF)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasFile
                ? const Color(0xFF93C5FD)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: hasFile
                    ? const Color(0xFFDBEAFE)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                hasFile
                    ? Icons.description
                    : Icons.upload_file,
                color: hasFile
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasFile
                        ? vm.resumeFileName!
                        : 'Upload Resume *',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: hasFile
                          ? const Color(0xFF1D4ED8)
                          : const Color(0xFF374151),
                    ),
                  ),
                  Text(
                    hasFile
                        ? 'Tap to change file'
                        : 'PDF, DOC, DOCX — Max 10MB',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            Icon(
              hasFile
                  ? Icons.check_circle
                  : Icons.arrow_forward_ios,
              color: hasFile
                  ? const Color(0xFF059669)
                  : const Color(0xFF94A3B8),
              size: hasFile ? 22 : 16,
            ),
          ],
        ),
      ),
    );
  }
}