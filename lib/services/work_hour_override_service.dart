// lib/services/work_hour_override_service.dart
//
// CRUD + hot-path lookup for per-employee work-hour overrides.
//
// The hot path is `activeFor(uid, date)` — called from every check-in,
// check-out, and policy-deduction computation. To avoid hammering
// Firestore on every UI tick, results are cached in-memory per
// (uid, dateKey). The cache is invalidated on create/delete and lives
// only for the current process.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/work_hour_override_model.dart';

class WorkHourOverrideService {
  final FirebaseFirestore _db;
  WorkHourOverrideService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('work_hour_overrides');

  // ── In-memory cache keyed by "$uid|$dateKey" ──────────────────────────────
  // Value is the active override or null (cached miss). Cleared on any
  // create/delete so HR's edits are visible immediately.
  final Map<String, WorkHourOverride?> _activeCache = {};

  String _cacheKey(String uid, DateTime d) =>
      '$uid|${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _invalidateUser(String uid) {
    _activeCache.removeWhere((k, _) => k.startsWith('$uid|'));
  }

  // ── Create / list / delete ────────────────────────────────────────────────

  Future<String> create(WorkHourOverride o) async {
    final ref = await _col.add(o.toMap());
    _invalidateUser(o.userId);
    return ref.id;
  }

  Future<List<WorkHourOverride>> listForUser(String uid) async {
    final snap = await _col
        .where('userId', isEqualTo: uid)
        .orderBy('startDate', descending: true)
        .get();
    return snap.docs
        .map((d) => WorkHourOverride.fromMap(d.data(), id: d.id))
        .toList();
  }

  Future<void> delete(String overrideId) async {
    final snap = await _col.doc(overrideId).get();
    final uid = (snap.data()?['userId'] ?? '').toString();
    await _col.doc(overrideId).delete();
    if (uid.isNotEmpty) _invalidateUser(uid);
  }

  // ── Hot path: latest override that covers (uid, date) ─────────────────────

  /// Returns the most recently created [WorkHourOverride] that covers
  /// [date] for [uid], or `null` if none exists.
  ///
  /// Query strategy: pull all overrides for the user where
  /// `startDateKey <= dateKey` (single inequality → no composite index),
  /// then filter `endDateKey >= dateKey` and weekday-coverage in Dart.
  /// Cached after the first lookup for the process.
  Future<WorkHourOverride?> activeFor(String uid, DateTime date) async {
    if (uid.trim().isEmpty) return null;
    final key = _cacheKey(uid, date);
    if (_activeCache.containsKey(key)) return _activeCache[key];

    final dateKey =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    try {
      // ── Single equality filter only → no composite index required.
      // We filter startDateKey / endDateKey in Dart below.
      final snap = await _col.where('userId', isEqualTo: uid).get();

      WorkHourOverride? winner;
      for (final d in snap.docs) {
        final o = WorkHourOverride.fromMap(d.data(), id: d.id);
        if (o.startDateKey.compareTo(dateKey) > 0) {
          continue; // starts after today
        }
        if (o.endDateKey.compareTo(dateKey) < 0) continue; // ended before today
        if (!o.coversDate(date)) continue;
        if (winner == null || o.createdAt.isAfter(winner.createdAt)) {
          winner = o;
        }
      }
      _activeCache[key] = winner;
      return winner;
    } catch (e) {
      // Surface to logs so missing indexes / permission errors are visible.
      debugPrint('[WorkHourOverrideService] activeFor($uid) failed: $e');
      return null; // don't poison cache on failure
    }
  }

  /// Synchronous picker for a date inside a pre-fetched list of overrides
  /// (used by the HR Monthly screen where we fetch once and look up per-day).
  /// Returns the latest-created override that covers [date].
  static WorkHourOverride? pickActive(
    List<WorkHourOverride> all,
    DateTime date,
  ) {
    WorkHourOverride? winner;
    for (final o in all) {
      if (!o.coversDate(date)) continue;
      if (winner == null || o.createdAt.isAfter(winner.createdAt)) {
        winner = o;
      }
    }
    return winner;
  }
}
