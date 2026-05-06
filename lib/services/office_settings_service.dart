// lib/services/office_settings_service.dart
//
// Handles reading and writing the office_settings/timings document.
// HR uses updateSettings() from their dashboard.
// The attendance service uses fetchSettings() to get the current cutoff.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/office_settings_model.dart';

class OfficeSettingsService {
  final FirebaseFirestore _db;

  OfficeSettingsService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  static const String _collection = 'office_settings';
  static const String _docId = 'timings';

  DocumentReference<Map<String, dynamic>> get _ref =>
      _db.collection(_collection).doc(_docId);

  // ── READ ──────────────────────────────────────────────────────────────────

  /// Fetches the current office settings.
  /// Falls back to [OfficeSettings.defaults()] if the document doesn't exist
  /// or if the read fails — so attendance marking never breaks due to a
  /// missing config document.
  Future<OfficeSettings> fetchSettings() async {
    try {
      final snap = await _ref.get();
      if (!snap.exists || snap.data() == null) {
        debugPrint('[OfficeSettings] Document not found — using defaults.');
        return OfficeSettings.defaults();
      }
      return OfficeSettings.fromMap(snap.data()!);
    } catch (e) {
      debugPrint('[OfficeSettings] Read failed ($e) — using defaults.');
      return OfficeSettings.defaults();
    }
  }

  /// Streams real-time updates — useful for the HR settings screen so it
  /// reflects changes immediately without a page refresh.
  Stream<OfficeSettings> streamSettings() {
    return _ref.snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return OfficeSettings.defaults();
      return OfficeSettings.fromMap(snap.data()!);
    });
  }

  // ── WRITE (HR only) ───────────────────────────────────────────────────────

  /// HR calls this to update office timings.
  /// Pass [hrUid] for the audit trail.
  Future<void> updateSettings({
    required OfficeSettings settings,
    required String hrUid,
  }) async {
    final updated = settings.copyWith(
      updatedAt: DateTime.now(),
      updatedBy: hrUid,
    );
    await _ref.set(updated.toMap(), SetOptions(merge: true));
    debugPrint('[OfficeSettings] Updated by $hrUid: $updated');
  }

  /// Convenience method — update only the check-in cutoff hour.
  Future<void> updateCutoffHour({
    required int hour,
    required String hrUid,
  }) async {
    assert(hour >= 0 && hour <= 23, 'Hour must be 0–23');
    await _ref.set({
      'checkInCutoff': hour,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': hrUid,
    }, SetOptions(merge: true));
  }

  Future<void> updateHalfDaySettings({
    required int halfDayMark,
    required int halfDayCutoff,
    required String hrUid,
  }) async {
    assert(halfDayMark >= 0 && halfDayMark <= 23);
    assert(halfDayCutoff >= 0 && halfDayCutoff <= 23);
    assert(
      halfDayCutoff > halfDayMark,
      'Cutoff must be after the half-day mark',
    );
    await _ref.set({
      'halfDayMark': halfDayMark,
      'halfDayCutoff': halfDayCutoff,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': hrUid,
    }, SetOptions(merge: true));
  }
}
