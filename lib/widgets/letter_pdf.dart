// lib/widgets/letter_pdf.dart
//
// Company letter PDF — matches PDT letterhead:
//   • Logo (left) + centred company name header
//   • Date, subject, body, signatures
//   • Footer: Islamabad office, UAN, email

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/company_letter.dart';

/// Brand colours from official letterhead.
final PdfColor _pdtGreen = PdfColor.fromHex('#1B5E20');
final PdfColor _linkBlue = PdfColor.fromHex('#1155CC');
final PdfColor _bodyBlack = PdfColor.fromHex('#000000');

const String _footerAddress =
    'Office # 5, 4th floor, Gulberg Trade Center, Gulberg Green Islamabad UAN # 03111-444-615';
const String _footerEmail = 'pakistandetectorsonline@gmail.com';

const String _logoAsset = 'assets/app_icon/pak_detectors.jpg';

Future<pw.MemoryImage?> _loadCompanyLogo() async {
  try {
    final data = await rootBundle.load(_logoAsset);
    return pw.MemoryImage(data.buffer.asUint8List());
  } catch (_) {
    return null;
  }
}

Future<pw.Document> buildLetterPdf(CompanyLetter letter) async {
  final doc = pw.Document();
  final regular = await PdfGoogleFonts.notoSerifRegular();
  final bold = await PdfGoogleFonts.notoSerifBold();
  final theme = pw.ThemeData.withFont(base: regular, bold: bold);
  final logo = await _loadCompanyLogo();

  final dateLabel = DateFormat('d MMMM, yyyy').format(letter.letterDate);
  final companyLine1 = 'PAKISTAN DETECTOR TECHNOLOGIES';
  const companyLine2 = '(PRIVATE) LTD.';

  doc.addPage(
    pw.MultiPage(
      theme: theme,
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(48, 36, 48, 72),
      header: (ctx) => _letterheadHeader(logo, companyLine1, companyLine2),
      footer: (ctx) => _letterheadFooter(),
      build: (ctx) => [
        pw.SizedBox(height: 8),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Date: $dateLabel',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 11,
              color: _bodyBlack,
            ),
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Center(
          child: pw.Text(
            'Subject: ${letter.subject}',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 12,
              color: _bodyBlack,
            ),
          ),
        ),
        pw.SizedBox(height: 18),
        pw.Text(
          'Dear ${letter.employeeName},',
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 11,
            color: _bodyBlack,
          ),
        ),
        pw.SizedBox(height: 12),
        for (final para in letter.body.split('\n\n')) ...[
          if (para.trim().isNotEmpty)
            pw.Text(
              para.trim(),
              style: const pw.TextStyle(
                fontSize: 11,
                lineSpacing: 1.45,
                color: PdfColors.black,
              ),
              textAlign: pw.TextAlign.justify,
            ),
          pw.SizedBox(height: 10),
        ],
        pw.SizedBox(height: 8),
        pw.Text(
          'Thanks & Regards,',
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 11,
            color: _bodyBlack,
          ),
        ),
        pw.SizedBox(height: 28),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  letter.hrName,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                    color: _bodyBlack,
                  ),
                ),
                if (letter.hrTitle != null && letter.hrTitle!.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    letter.hrTitle!,
                    style: const pw.TextStyle(fontSize: 11, color: PdfColors.black),
                  ),
                ],
                pw.SizedBox(height: 2),
                pw.Text(
                  letter.companyName,
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.black),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                  width: 200,
                  height: 1,
                  color: _bodyBlack,
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  letter.employeeName,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                    color: _bodyBlack,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Employee',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 24),
      ],
    ),
  );

  return doc;
}

/// Top block: logo left, company name centred in remaining width (letterhead style).
pw.Widget _letterheadHeader(
  pw.MemoryImage? logo,
  String companyLine1,
  String companyLine2,
) {
  return pw.Column(
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (logo != null)
            pw.Container(
              width: 72,
              height: 72,
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            )
          else
            pw.Container(
              width: 72,
              height: 72,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _pdtGreen, width: 1.5),
              ),
              alignment: pw.Alignment.center,
              child: pw.Text(
                'PDT',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 12,
                  color: _pdtGreen,
                ),
              ),
            ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  companyLine1,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 15,
                    color: _pdtGreen,
                    letterSpacing: 0.3,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  companyLine2,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 13,
                    color: _pdtGreen,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 72),
        ],
      ),
      pw.SizedBox(height: 14),
      pw.Container(
        width: double.infinity,
        height: 0.5,
        color: PdfColor.fromHex('#E2E8F0'),
      ),
      pw.SizedBox(height: 10),
    ],
  );
}

pw.Widget _letterheadFooter() {
  return pw.Column(
    children: [
      pw.Container(
        width: double.infinity,
        height: 0.5,
        color: PdfColor.fromHex('#CBD5E1'),
      ),
      pw.SizedBox(height: 8),
      pw.Center(
        child: pw.Text(
          _footerAddress,
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.black),
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Center(
        child: pw.Text(
          _footerEmail,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 9,
            color: _linkBlue,
            decoration: pw.TextDecoration.underline,
          ),
        ),
      ),
      pw.SizedBox(height: 4),
    ],
  );
}

Future<void> previewLetterPdf(CompanyLetter letter) async {
  final doc = await buildLetterPdf(letter);
  await Printing.layoutPdf(onLayout: (_) async => doc.save());
}

Future<void> shareLetterPdf(CompanyLetter letter) async {
  final doc = await buildLetterPdf(letter);
  await Printing.sharePdf(
    bytes: await doc.save(),
    filename: '${letter.kind.label.replaceAll(' ', '_')}'
        '_${letter.employeeName.replaceAll(' ', '_')}.pdf',
  );
}
