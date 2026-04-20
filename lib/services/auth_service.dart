import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _currentUser;

  UserModel? getCurrentUser() => _currentUser;

  bool isLoggedIn() => _currentUser != null;

  // ── Static getter — used by main.dart for FCM token refresh ──────────────
  // Does NOT need context or an AuthService instance.
  static String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> initialize() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        _currentUser = UserModel.fromMap(
          user.uid,
          doc.data() as Map<String, dynamic>,
        );
        await _saveToPrefs(_currentUser!);
      }
    } else {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('name')) {
        _currentUser = UserModel(
          uid: '',
          name: prefs.getString('name')!,
          email: prefs.getString('email')!,
          role: prefs.getString('role')!,
        );
      }
    }
  }

  Future<Map<String, dynamic>> signup({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _firestore.collection('users').doc(cred.user!.uid).set({
        'name': name,
        'employee_id'
                'email':
            email,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _currentUser = UserModel(
        uid: cred.user!.uid,
        name: name,
        email: email,
        role: role,
      );

      await _saveToPrefs(_currentUser!);
      return {'success': true, 'user': _currentUser!};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': e.message ?? 'Signup failed'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(cred.user!.uid)
          .get();

      if (!doc.exists) {
        return {'success': false, 'message': 'User not found'};
      }

      _currentUser = UserModel.fromMap(
        cred.user!.uid,
        doc.data() as Map<String, dynamic>,
      );

      await _saveToPrefs(_currentUser!);
      return {'success': true, 'user': _currentUser!};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': e.message ?? 'Login failed'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    _currentUser = null;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<void> _saveToPrefs(UserModel user) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', user.name);
    await prefs.setString('email', user.email);
    await prefs.setString('role', user.role);
  }
}
