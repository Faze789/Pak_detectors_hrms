import 'package:flutter/material.dart';

import '../models/document_model.dart';

IconData documentFileIcon(OfficialDocument doc) {
  final e = doc.fileExtension.toLowerCase();
  return switch (e) {
    'pdf' => Icons.picture_as_pdf_rounded,
    'doc' || 'docx' => Icons.description_rounded,
    'jpg' || 'jpeg' || 'png' => Icons.image_rounded,
    _ => Icons.insert_drive_file_rounded,
  };
}

String documentTypeLabel(OfficialDocument doc) {
  if (doc.fileExtension.isNotEmpty) {
    return doc.fileExtension.toUpperCase();
  }
  return doc.category.displayName;
}
