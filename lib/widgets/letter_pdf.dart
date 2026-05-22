// lib/widgets/letter_pdf.dart
//
// Builds a printable PDF document from a `CompanyLetter`. Used by both
// the HR creation flow (preview + download) and the employee inbox
// (download / share). Layout mirrors the sample provided by HR: company
// header on the left, date on the top-right, subject centered, salutation,
// body paragraphs, sign-off block with HR signature line on the left and
// employee signature line on the right.

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/company_letter.dart';

Future<pw.Document> buildLetterPdf(CompanyLetter letter) async {
  final doc = pw.Document();
  final base = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  final theme = pw.ThemeData.withFont(base: base, bold: bold);

  final dateLabel = DateFormat('d MMMM, yyyy').format(letter.letterDate);

  doc.addPage(
    pw.MultiPage(
      theme: theme,
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(48, 48, 48, 48),
      build: (ctx) => [
        // ── Header ─────────────────────────────────────────────────────
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(
              width: 60,
              height: 60,
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#FFFFFF'),
                border: pw.Border.all(
                  color: PdfColor.fromHex('#1B5E20'),
                  width: 2,
                ),
              ),
              alignment: pw.Alignment.center,
              child: pw.Text(
                'PDT',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#1B5E20'),
                  fontSize: 14,
                ),
              ),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'PAKISTAN DETECTOR TECHNOLOGIES',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 14,
                      color: PdfColor.fromHex('#1B5E20'),
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'PVT  LTD',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                      color: PdfColor.fromHex('#1B5E20'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 26),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Date: $dateLabel',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
        ),
        pw.SizedBox(height: 14),
        // ── Subject ───────────────────────────────────────────────────
        pw.Center(
          child: pw.Text(
            'Subject: ${letter.subject}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
          ),
        ),
        pw.SizedBox(height: 18),
        // ── Salutation ────────────────────────────────────────────────
        pw.Text(
          'Dear ${letter.employeeName},',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
        ),
        pw.SizedBox(height: 12),
        // ── Body (paragraph-split on blank lines) ─────────────────────
        for (final para in letter.body.split('\n\n')) ...[
          pw.Text(
            para.trim(),
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.4),
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 10),
        ],
        pw.SizedBox(height: 10),
        // ── Sign-off ──────────────────────────────────────────────────
        pw.Text(
          'Thanks & Regards,',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
        ),
        pw.SizedBox(height: 24),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  letter.hrName,
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 11),
                ),
                if (letter.hrTitle != null && letter.hrTitle!.isNotEmpty)
                  pw.Text(
                    letter.hrTitle!,
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                pw.Text(
                  letter.companyName,
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                  width: 180,
                  height: 1,
                  color: PdfColor.fromHex('#0F172A'),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  letter.employeeName,
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );

  return doc;
}

/// Opens the platform print/preview sheet so HR (or the employee) can
/// download to a PDF file, share to email, or send to a printer.
Future<void> previewLetterPdf(CompanyLetter letter) async {
  final doc = await buildLetterPdf(letter);
  await Printing.layoutPdf(onLayout: (_) async => doc.save());
}

/// Shares the PDF directly via the system share sheet (one tap "save to
/// Files / email / WhatsApp / etc.").
Future<void> shareLetterPdf(CompanyLetter letter) async {
  final doc = await buildLetterPdf(letter);
  await Printing.sharePdf(
    bytes: await doc.save(),
    filename: '${letter.kind.label.replaceAll(' ', '_')}'
        '_${letter.employeeName.replaceAll(' ', '_')}.pdf',
  );
}
