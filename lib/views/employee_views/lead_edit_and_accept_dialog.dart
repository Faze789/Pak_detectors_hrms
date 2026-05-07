import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/storage_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/task_viewmodel.dart';

/// Dialog for the lead's "Edit task, then accept" flow (spec §2 option 2).
///
/// The lead can change the title, description, secondary description, and
/// add more PDF attachments to either group. Save → applies edits + flips
/// `leadAcceptanceState` to `accepted_with_edits` + logs the
/// `lead_edit_and_accept` event in one shot.
Future<bool?> showLeadEditAndAcceptDialog(
  BuildContext context,
  Map<String, dynamic> task,
) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _LeadEditAndAcceptDialog(task: task),
  );
}

class _LeadEditAndAcceptDialog extends StatefulWidget {
  const _LeadEditAndAcceptDialog({required this.task});
  final Map<String, dynamic> task;

  @override
  State<_LeadEditAndAcceptDialog> createState() =>
      _LeadEditAndAcceptDialogState();
}

class _LeadEditAndAcceptDialogState extends State<_LeadEditAndAcceptDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _secondaryCtrl;

  final List<PlatformFile> _newPrimary = [];
  final List<PlatformFile> _newSecondary = [];

  final StorageService _storage = StorageService();
  bool _saving = false;

  bool get _hasSecondary =>
      ((widget.task['secondaryDescription'] ?? '') as String).trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.task['title'] ?? '');
    _descCtrl = TextEditingController(text: widget.task['description'] ?? '');
    _secondaryCtrl = TextEditingController(
      text: widget.task['secondaryDescription'] ?? '',
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _secondaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFiles(List<PlatformFile> bucket) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null) return;
    setState(() => bucket.addAll(result.files));
  }

  Future<void> _saveAndAccept() async {
    final newTitle = _titleCtrl.text.trim();
    final newDesc = _descCtrl.text.trim();
    if (newTitle.isEmpty || newDesc.isEmpty) {
      _snack('Title and description cannot be empty.', error: true);
      return;
    }

    setState(() => _saving = true);
    final taskVm = context.read<TaskViewModel>();
    final user = context.read<AuthViewModel>().currentUser;
    final leadEmpId = (widget.task['lead_id'] ?? user?.uid ?? '').toString();
    final leadName = user?.name ?? 'Lead';
    final taskId = widget.task['id'] as String;

    try {
      // Upload any new attachments first.
      final ts = DateTime.now().millisecondsSinceEpoch;
      List<Map<String, dynamic>>? mergedPrimary;
      List<Map<String, dynamic>>? mergedSecondary;

      final originalPrimary =
          (widget.task['attachments'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          const <Map<String, dynamic>>[];
      final originalSecondary =
          (widget.task['secondaryAttachments'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          const <Map<String, dynamic>>[];

      if (_newPrimary.isNotEmpty) {
        final uploaded = await _storage.uploadManyPdfs(
          pathPrefix: 'task_attachments/$taskId/lead_edit_$ts/primary',
          files: _newPrimary,
          uploadedBy: leadEmpId,
          uploaderRole: 'lead',
        );
        mergedPrimary = [...originalPrimary, ...uploaded];
      }
      if (_newSecondary.isNotEmpty) {
        final uploaded = await _storage.uploadManyPdfs(
          pathPrefix: 'task_attachments/$taskId/lead_edit_$ts/secondary',
          files: _newSecondary,
          uploadedBy: leadEmpId,
          uploaderRole: 'lead',
        );
        mergedSecondary = [...originalSecondary, ...uploaded];
      }

      final newSecondaryText = _hasSecondary
          ? _secondaryCtrl.text.trim()
          : null;

      // Apply edits, then accept.
      final ok1 = await taskVm.leadApplyEdits(
        taskId: taskId,
        title: newTitle,
        description: newDesc,
        secondaryDescription: newSecondaryText,
        attachments: mergedPrimary,
        secondaryAttachments: mergedSecondary,
      );
      if (!ok1) throw Exception(taskVm.errorMessage ?? 'Failed to save edits');

      final ok2 = await taskVm.leadAcceptTask(
        taskId: taskId,
        variant: 'accepted_with_edits',
        leadEmpId: leadEmpId,
        leadName: leadName,
        taskTitle: newTitle,
        editsPayload: {
          'title': newTitle,
          'description': newDesc,
          if (newSecondaryText != null)
            'secondaryDescription': newSecondaryText,
          if (mergedPrimary != null)
            'attachmentCount': mergedPrimary.length,
          if (mergedSecondary != null)
            'secondaryAttachmentCount': mergedSecondary.length,
        },
      );
      if (!ok2) throw Exception(taskVm.errorMessage ?? 'Failed to accept');

      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.of(context).pop(true);
      _snack('Edits saved and task accepted.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(e.toString(), error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error
            ? const Color(0xFFEF4444)
            : const Color(0xFF16A34A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.edit_note_rounded,
                      color: Color(0xFF2563EB),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Edit & Accept',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _label('Title'),
              const SizedBox(height: 6),
              _textField(_titleCtrl, hint: 'Task title'),
              const SizedBox(height: 14),
              _label('Description'),
              const SizedBox(height: 6),
              _textField(_descCtrl, hint: 'Task description', maxLines: 4),
              const SizedBox(height: 14),
              _label('Add Primary Attachments (PDF)'),
              const SizedBox(height: 6),
              _attachmentsRow(_newPrimary),
              if (_hasSecondary) ...[
                const SizedBox(height: 18),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 14),
                _label('Secondary Description'),
                const SizedBox(height: 6),
                _textField(
                  _secondaryCtrl,
                  hint: 'Secondary description',
                  maxLines: 3,
                ),
                const SizedBox(height: 14),
                _label('Add Secondary Attachments (PDF)'),
                const SizedBox(height: 6),
                _attachmentsRow(_newSecondary),
              ],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _saveAndAccept,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(
                    _saving ? 'Saving…' : 'Save & Accept',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    disabledBackgroundColor: const Color(0xFF93C5FD),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: Color(0xFF475569),
      letterSpacing: 0.2,
    ),
  );

  Widget _textField(
    TextEditingController ctrl, {
    required String hint,
    int maxLines = 1,
  }) => TextField(
    controller: ctrl,
    maxLines: maxLines,
    style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
    ),
  );

  Widget _attachmentsRow(List<PlatformFile> bucket) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bucket.isNotEmpty) ...[
            ...bucket.asMap().entries.map((e) {
              final i = e.key;
              final f = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.picture_as_pdf,
                      size: 14,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        f.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => bucket.removeAt(i)),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 4),
          ],
          OutlinedButton.icon(
            onPressed: () => _pickFiles(bucket),
            icon: const Icon(Icons.upload_file_rounded, size: 16),
            label: const Text('Add PDF', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2563EB),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ),
        ],
      ),
    );
  }
}
