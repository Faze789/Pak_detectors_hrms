// lib/views/employee_tabs/documents_tab.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/document_model.dart';
import '../../models/employee_model.dart';
import '../../viewmodels/document_viewmodel.dart';
import '../../widgets/document_file_icon.dart';
import '../../widgets/stat_card.dart';

class DocumentsTab extends StatefulWidget {
  final Employee employee;
  final DocumentViewModel documentVM;

  /// HR can upload/delete; employees can only view their own files.
  final bool allowManage;
  final DocumentCategory defaultCategory;

  const DocumentsTab({
    super.key,
    required this.employee,
    required this.documentVM,
    this.allowManage = true,
    this.defaultCategory = DocumentCategory.offerLetter,
  });

  @override
  State<DocumentsTab> createState() => _DocumentsTabState();
}

class _DocumentsTabState extends State<DocumentsTab> {
  @override
  void initState() {
    super.initState();
    // Defer until after the first frame so notifyListeners() inside
    // loadDocuments() doesn't fire during the build phase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.documentVM.loadDocuments(employeeId: widget.employee.uid);
    });
  }

  // ── Upload sheet ───────────────────────────────────────────────────────────
  Future<void> _showUploadSheet() async {
    final titleController = TextEditingController();
    DocumentCategory selectedCategory = widget.defaultCategory;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
        ),
        child: StatefulBuilder(
          builder: (ctx, setSheet) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Upload Document',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'PDF, DOCX, JPG, or PNG — e.g. offer letter',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),

              // Title field
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Document Title',
                  hintText: 'e.g. Employment Contract 2024',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Category chips
              const Text(
                'Category',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: DocumentCategory.values.map((cat) {
                  final selected = selectedCategory == cat;
                  return ChoiceChip(
                    label: Text(cat.displayName),
                    selected: selected,
                    selectedColor: const Color(0xFF2563EB),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF475569),
                      fontWeight: FontWeight.w500,
                    ),
                    onSelected: (_) => setSheet(() => selectedCategory = cat),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(ctx, true),
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Pick & Upload'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final success = await widget.documentVM.uploadDocument(
      employeeId: widget.employee.uid,
      employeeName: widget.employee.name,
      title: titleController.text,
      category: selectedCategory,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Document uploaded successfully.'
              : 'Upload failed: ${widget.documentVM.error ?? "Unknown error"}',
        ),
        backgroundColor: success ? Colors.green[700] : Colors.red[700],
      ),
    );
  }

  // ── Delete confirm ─────────────────────────────────────────────────────────
  Future<void> _confirmDelete(OfficialDocument doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Delete "${doc.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final success = await widget.documentVM.deleteDocument(
      doc.id,
      employeeId: widget.employee.uid,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Document deleted.' : 'Delete failed.'),
        backgroundColor: success ? Colors.green[700] : Colors.red[700],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.documentVM,
      child: Consumer<DocumentViewModel>(
        builder: (context, vm, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Stats row ──────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    icon: Icons.file_present,
                    label: 'Total',
                    value: vm.totalDocuments.toString(),
                    color: const Color(0xFF3B82F6),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatCard(
                    icon: Icons.verified,
                    label: 'Verified',
                    value: vm.verifiedCount.toString(),
                    color: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    icon: Icons.schedule,
                    label: 'Pending',
                    value: vm.pendingCount.toString(),
                    color: const Color(0xFFD97706),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatCard(
                    icon: Icons.error,
                    label: 'Expired',
                    value: vm.expiredCount.toString(),
                    color: const Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Upload progress bar ────────────────────────────────────────
            if (vm.isUploading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: vm.uploadProgress,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFE0F2FE),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF0284C7)),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Uploading… ${(vm.uploadProgress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
            ],

            if (widget.allowManage) ...[
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  border: Border.all(color: const Color(0xFF0EA5E9)),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(
                      Icons.cloud_upload,
                      color: Color(0xFF0284C7),
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Add Documents',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Offer letters, contracts, ID — PDF, DOCX, JPG, PNG',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: vm.isUploading ? null : _showUploadSheet,
                      icon: const Icon(Icons.upload_file),
                      label: Text(
                        vm.isUploading ? 'Uploading…' : 'Upload File',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF7DD3FC),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Documents uploaded by HR appear here. Tap Open to view.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Documents list ─────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Text(
                          'Official Documents',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Loading
                  if (vm.isLoading)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    )
                  // Empty
                  else if (vm.documents.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.file_present,
                            color: Color(0xFFCBD5E1),
                            size: 40,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No documents uploaded',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  // Grid
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 300,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.0,
                          ),
                      itemCount: vm.documents.length,
                      itemBuilder: (_, i) => _DocumentCard(
                        document: vm.documents[i],
                        allowDelete: widget.allowManage,
                        onDelete: () => _confirmDelete(vm.documents[i]),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Document Card
// ─────────────────────────────────────────────────────────────────────────────

class _DocumentCard extends StatelessWidget {
  final OfficialDocument document;
  final VoidCallback onDelete;
  final bool allowDelete;

  const _DocumentCard({
    required this.document,
    required this.onDelete,
    this.allowDelete = true,
  });

  Color _statusColor(DocumentStatus s) => switch (s) {
    DocumentStatus.verified => const Color(0xFF10B981),
    DocumentStatus.pending => const Color(0xFFD97706),
    DocumentStatus.expired => const Color(0xFFEF4444),
  };

  // Pass BuildContext so we can show a Snackbar if it fails
  Future<void> _openUrl(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);

      // Force it to open in the OS browser/PDF viewer rather than an in-app webview
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open document link.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Invalid document URL: $url')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(document.status);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF8FAFC), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: icon + menu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  documentFileIcon(document),
                  color: const Color(0xFF2563EB),
                ),
              ),
              PopupMenuButton<String>(
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'open',
                    child: Row(
                      children: [
                        Icon(Icons.open_in_new, size: 18),
                        SizedBox(width: 8),
                        Text('Open'),
                      ],
                    ),
                  ),
                  if (allowDelete)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                ],
                // inside PopupMenuButton onSelected:
                onSelected: (val) {
                  if (val == 'open') _openUrl(context, document.fileUrl);
                  if (val == 'delete' && allowDelete) onDelete();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Title + category
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${document.category.displayName} · ${documentTypeLabel(document)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Size + status badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                document.fileSize,
                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  document.status.displayName,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
