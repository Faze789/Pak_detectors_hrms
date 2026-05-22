// HR upload block for add/edit employee — offer letters & attachments.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/document_model.dart';
import '../models/employee_model.dart';
import '../viewmodels/document_viewmodel.dart';
import 'document_file_icon.dart';

class EmployeeAttachmentSection extends StatelessWidget {
  final Employee employee;

  const EmployeeAttachmentSection({super.key, required this.employee});

  Future<void> _upload(BuildContext context) async {
    final titleCtrl = TextEditingController(text: 'Offer Letter');
    var category = DocumentCategory.offerLetter;

    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Upload attachment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Allowed: PDF, DOCX, JPG, PNG',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<DocumentCategory>(
              value: category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: DocumentCategory.values
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(c.displayName),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) category = v;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Pick file'),
          ),
        ],
      ),
    );

    if (go != true || !context.mounted) return;

    final vm = context.read<DocumentViewModel>();
    vm.loadDocuments(employeeId: employee.uid);
    final ok = await vm.uploadDocument(
      employeeId: employee.uid,
      employeeName: employee.name,
      title: titleCtrl.text,
      category: category,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'File uploaded' : 'Upload failed: ${vm.error ?? "cancelled"}',
        ),
        backgroundColor: ok ? const Color(0xFF16A34A) : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DocumentViewModel>();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.attach_file_rounded, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text(
                'Attachments & offer letters',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Upload offer letters or HR documents for this employee.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          if (vm.isUploading) ...[
            LinearProgressIndicator(value: vm.uploadProgress),
            const SizedBox(height: 8),
            Text(
              'Uploading ${(vm.uploadProgress * 100).toStringAsFixed(0)}%…',
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: vm.isUploading ? null : () => _upload(context),
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: const Text('Upload file'),
          ),
          if (vm.documents.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Recent uploads',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 8),
            ...vm.documents.take(3).map(
                  (d) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      documentFileIcon(d),
                      color: const Color(0xFF2563EB),
                      size: 22,
                    ),
                    title: Text(
                      d.title,
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      '${d.category.displayName} · ${documentTypeLabel(d)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}
