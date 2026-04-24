// lib/viewmodels/auth_viewmodel.dart
//
// FCM token is saved here (on login/signup/cold-start).
// main.dart only listens for token *refresh* going forward — no duplication.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthService authService;

  AuthViewModel({required this.authService});

  UserModel? _currentUser;
  bool       _isLoading    = false;
  String     _errorMessage = '';
  bool       _isLoggedIn   = false;

  UserModel? get currentUser   => _currentUser;
  bool       get isLoading     => _isLoading;
  String     get errorMessage  => _errorMessage;
  bool       get isLoggedIn    => _isLoggedIn;

  // ── Initialize (cold start) ───────────────────────────────────────────────
  Future<void> initialize() async {
    await authService.initialize();
    _isLoggedIn  = authService.isLoggedIn();
    _currentUser = authService.getCurrentUser();
    notifyListeners();

    if (_isLoggedIn && _currentUser != null) {
      await _saveFcmToken(_currentUser!.uid);
    }
  }

  // ── Signup ────────────────────────────────────────────────────────────────
  Future<bool> signup({
    required String name,
    required String email,
    required String password,
    required String role,
    String department = '',
  }) async {
    _setLoading(true);
    _clearError();
    try {
      final result = await authService.signup(
          name: name, email: email, password: password, role: role, department: department);
      if (result['success'] as bool) {
        _currentUser = result['user'] as UserModel;
        _isLoggedIn  = true;
        notifyListeners();
        await _saveFcmToken(_currentUser!.uid);
        return true;
      } else {
        _errorMessage = result['message'] as String;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Signup failed: $e';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Login ─────────────────────────────────────────────────────────────────
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      final result = await authService.login(email: email, password: password);
      if (result['success'] as bool) {
        _currentUser = result['user'] as UserModel;
        _isLoggedIn  = true;
        notifyListeners();
        await _saveFcmToken(_currentUser!.uid);
        return true;
      } else {
        _errorMessage = result['message'] as String;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Login failed: $e';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    _setLoading(true);
    try {
      if (_currentUser != null) await _removeFcmToken(_currentUser!.uid);
      await authService.logout();
      _currentUser = null;
      _isLoggedIn  = false;
      _clearError();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Logout failed: $e';
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // ── FCM helpers ───────────────────────────────────────────────────────────

  /// Requests permission (iOS), gets token, writes to users/{uid}.fcmToken.
  /// Called on login, signup, and cold start.
  /// Token *refresh* is handled in main.dart via onTokenRefresh listener.
  Future<void> _saveFcmToken(String uid) async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert:  true,
        badge:  true,
        sound:  true,
      );
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'fcmToken': token});

      debugPrint('[FCM] Token saved for $uid');
    } catch (e) {
      debugPrint('[FCM] Failed to save token: $e');
    }
  }

  /// Removes FCM token on logout so device stops receiving notifications.
  Future<void> _removeFcmToken(String uid) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'fcmToken': FieldValue.delete()});
      debugPrint('[FCM] Token removed for $uid');
    } catch (e) {
      debugPrint('[FCM] Failed to remove token: $e');
    }
  }

  void _setLoading(bool v) => _isLoading = v;
  void _clearError()       => _errorMessage = '';
  void clearError() { _clearError(); notifyListeners(); }
}