// HR — all employee documents with filter by name.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/document_model.dart';
import '../../viewmodels/document_viewmodel.dart';
import '../../widgets/document_file_icon.dart';

class HRDocumentsScreen extends StatefulWidget {
  const HRDocumentsScreen({super.key});

  @override
  State<HRDocumentsScreen> createState() => _HRDocumentsScreenState();
}

class _HRDocumentsScreenState extends State<HRDocumentsScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DocumentViewModel>().loadAllDocumentsForHR();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DocumentViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        title: const Text(
          'Employee Documents',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: vm.setEmployeeNameFilter,
                  decoration: InputDecoration(
                    hintText: 'Filter by employee name…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              vm.setEmployeeNameFilter('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _ChipStat(
                      label: 'Total',
                      value: '${vm.allDocumentsTotal}',
                      color: const Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 8),
                    _ChipStat(
                      label: 'Showing',
                      value: '${vm.allDocuments.length}',
                      color: const Color(0xFF64748B),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: vm.isLoading
                ? const Center(child: CircularProgressIndicator())
                : vm.allDocuments.isEmpty
                    ? const _EmptyDocs()
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: vm.allDocuments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final doc = vm.allDocuments[i];
                          return _HRDocTile(
                            doc: doc,
                            onOpen: () => _openUrl(doc.fileUrl),
                            onDelete: () => _confirmDelete(context, vm, doc),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    DocumentViewModel vm,
    OfficialDocument doc,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete document'),
        content: Text('Delete "${doc.title}" for ${doc.employeeName}?'),
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
    if (ok != true || !context.mounted) return;
    final success =
        await vm.deleteDocument(doc.id, employeeId: doc.employeeId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Document deleted' : 'Delete failed'),
        backgroundColor: success ? const Color(0xFF16A34A) : Colors.red,
      ),
    );
  }
}

class _HRDocTile extends StatelessWidget {
  final OfficialDocument doc;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _HRDocTile({
    required this.doc,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  documentFileIcon(doc),
                  color: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      doc.employeeName.isNotEmpty
                          ? doc.employeeName
                          : 'Unknown employee',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${doc.category.displayName} · ${documentTypeLabel(doc)} · ${doc.fileSize}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      DateFormat('d MMM yyyy').format(doc.uploadedAt),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new_rounded, size: 20),
                color: const Color(0xFF2563EB),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: const Color(0xFFDC2626),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _ChipStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: ',
              style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      );
}

class _EmptyDocs extends StatelessWidget {
  const _EmptyDocs();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_open_rounded, size: 48, color: Color(0xFFCBD5E1)),
              SizedBox(height: 12),
              Text(
                'No documents yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Upload offer letters and files when editing an employee.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      );
}
