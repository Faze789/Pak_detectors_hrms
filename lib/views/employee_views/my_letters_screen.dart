// lib/views/employee_views/my_letters_screen.dart
//
// Employee inbox of company letters HR has issued to them. Live stream
// on `company_letters` where `employeeUid == currentUser.uid`. Tap a row
// to preview / download the PDF via the same `printing` flow HR uses.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/company_letter.dart';
import '../../services/company_letter_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/letter_pdf.dart';

class MyLettersScreen extends StatelessWidget {
  const MyLettersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final uid = auth.currentUser?.uid ?? '';
    final service = CompanyLetterService();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        title: const Text(
          'My Letters',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: uid.isEmpty
          ? const _Empty(text: 'Sign in to see your letters.')
          : StreamBuilder<List<CompanyLetter>>(
              stream: service.streamForEmployee(uid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return _Empty(text: 'Failed to load: ${snap.error}');
                }
                final letters = snap.data ?? const <CompanyLetter>[];
                if (letters.isEmpty) {
                  return const _Empty(
                    text: 'No letters have been issued to you yet.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: letters.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _LetterTile(letter: letters[i]),
                );
              },
            ),
    );
  }
}

class _LetterTile extends StatelessWidget {
  final CompanyLetter letter;
  const _LetterTile({required this.letter});

  @override
  Widget build(BuildContext context) {
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.description_rounded,
                  color: Color(0xFF2563EB),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      letter.kind.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      letter.subject,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                DateFormat('d MMM yyyy').format(letter.letterDate),
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            letter.body.split('\n').first,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Issued by ${letter.hrName}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                  fontStyle: FontStyle.italic,
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => previewLetterPdf(letter),
                icon: const Icon(Icons.visibility_rounded, size: 14),
                label: const Text('Open'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                onPressed: () => shareLetterPdf(letter),
                icon: const Icon(Icons.download_rounded, size: 14),
                label: const Text('Save'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
      ),
    );
  }
}
